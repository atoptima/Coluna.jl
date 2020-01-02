const SupportedObjFunc = Union{MOI.ScalarAffineFunction{Float64},
                               MOI.SingleVariable}

const SupportedVarSets = Union{MOI.ZeroOne,
                               MOI.Integer,
                               MOI.LessThan{Float64},
                               MOI.EqualTo{Float64},
                               MOI.GreaterThan{Float64}}

const SupportedConstrFunc = Union{MOI.ScalarAffineFunction{Float64}}

const SupportedConstrSets = Union{MOI.EqualTo{Float64},
                                  MOI.GreaterThan{Float64},
                                  MOI.LessThan{Float64}}

mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::Problem
    moi_index_to_coluna_uid::MOIU.IndexMap
    params::Params
    annotations::Annotations
    varmap::Dict{MOI.VariableIndex,Id{Variable}} # For the user to get VariablePrimal
    result::OptimizationResult
end

setinnerprob!(o::Optimizer, prob::Problem) = o.inner = prob

function Optimizer(;default_optimizer = nothing,
                   params = Params())
    b = no_optimizer_builder
    if default_optimizer != nothing
        b = ()->MoiOptimizer(default_optimizer())
    end
    prob = Problem(b)
    return Optimizer(
        prob, MOIU.IndexMap(), params, Annotations(),
        Dict{MOI.VariableIndex,Id{Variable}}(), OptimizationResult{MinSense}()
    )
end

function MOI.optimize!(optimizer::Optimizer)
    optimizer.result = optimize!(
        optimizer.inner, optimizer.annotations, optimizer.params
    )
    return
end

function MOI.supports_constraint(optimizer::Optimizer, 
        ::Type{<: SupportedConstrFunc}, ::Type{<: SupportedConstrSets})
    return true
end

function MOI.supports_constraint(optimizer::Optimizer,
        ::Type{MOI.SingleVariable}, ::Type{<: SupportedVarSets})
    return true
end

function MOI.supports(optimizer::Optimizer, 
        ::MOI.ObjectiveFunction{<: SupportedObjFunc})
    return true
end

function getvarcosts(src::MOI.ModelLike)
    # We need to increment values of cost_rhs with += to handle cases like $x_1 + x_2 + x_1$
    # This is safe becasue the variables are initialized with a 0.0 cost_rhs
    costs = Dict{Int,Float64}()
    obj = MOI.get(src, MoiObjective())
    for term in obj.terms
        id = term.variable_index.value
        costs[id] = get(costs, id, 0.0) + term.coefficient
    end
    return costs
end

function get_var_kinds_and_bounds(src::MOI.ModelLike)
    kinds = Dict{Int,VarKind}()
    lbs = Dict{Int,Float64}()
    ubs = Dict{Int,Float64}()
    for (F, S) in MOI.get(src, MOI.ListOfConstraints())
        if F == MOI.SingleVariable
            for moi_index in MOI.get(src, MOI.ListOfConstraintIndices{F,S}())
                func = MOI.get(src, MOI.ConstraintFunction(), moi_index)
                set = MOI.get(src, MOI.ConstraintSet(), moi_index)
                id = func.variable.value
                if S in [MOI.ZeroOne, MOI.Integer]
                    kinds[id] = getkind(set)
                else
                    bound = getrhs(set)
                    if getsense(set) in [Equal, Less]
                        cur_ub = get(ubs, id, Inf)
                        if bound < cur_ub
                            ubs[id] = bound
                        end
                    elseif getsense(set) in [Equal, Greater]
                        cur_lb = get(lbs, id, -Inf)
                        if bound > cur_lb
                            lbs[id] = bound
                        end
                    end
                end
            end
        end
    end
    return kinds, lbs, ubs
end

function create_origvars!(
    form::Formulation, dest::Optimizer, src::MOI.ModelLike, 
    costs::Dict{Int,Float64}, kinds::Dict{Int, VarKind},
    lbs::Dict{Int, Float64}, ubs::Dict{Int, Float64}, copy_names::Bool,
    moi_uid_to_coluna_id::Dict{Int,VarId}
)
    for moi_index in MOI.get(src, MOI.ListOfVariableIndices())
        if copy_names
            name = MOI.get(src, MOI.VariableName(), moi_index)
        else
            name = string("var_", moi_index.value)
        end
        var = setvar!(
            form, name, OriginalVar; 
            cost = get(costs, moi_index.value, 0.0),
            kind = get(kinds, moi_index.value, Continuous),
            lb = get(lbs, moi_index.value, -Inf),
            ub = get(ubs, moi_index.value, Inf)
        )
        var_id = getid(var)
        moi_index_in_coluna = deepcopy(moi_index) 
        dest.moi_index_to_coluna_uid[moi_index] = moi_index_in_coluna
        moi_uid_to_coluna_id[moi_index.value] = var_id
        annotation = MOI.get(src, BD.VariableDecomposition(), moi_index)
        dest.varmap[moi_index_in_coluna] = var_id
        store!(dest.annotations, annotation, var)
    end
end

function create_origconstr!(form::Formulation,
                            dest::Optimizer,
                            src::MOI.ModelLike,
                            name::String,
                            func::MOI.ScalarAffineFunction,
                            set::SupportedConstrSets,
                            moi_index::MOI.ConstraintIndex,
                            moi_uid_to_coluna_id::Dict{Int,VarId})

    constr = setconstr!(form, name, OriginalConstr;
                    rhs = getrhs(set),
                    kind = MathProg.Core,
                    sense = getsense(set),
                    inc_val = 10.0) #TODO set inc_val in model
    constr_id = getid(constr)
    dest.moi_index_to_coluna_uid[moi_index] =
        MOI.ConstraintIndex{typeof(func),typeof(set)}(getuid(constr_id))
    matrix = getcoefmatrix(form)
    for term in func.terms
        var_id = moi_uid_to_coluna_id[term.variable_index.value]
        matrix[constr_id, var_id] = term.coefficient
    end
    annotation = MOI.get(src, BD.ConstraintDecomposition(), moi_index)
    store!(dest.annotations, annotation, constr)
    return
end

function create_origconstrs!(form::Formulation,
                             dest::Optimizer,
                             src::MOI.ModelLike,
                             copy_names::Bool,
                             moi_uid_to_coluna_id::Dict{Int,VarId})

    for (F, S) in MOI.get(src, MOI.ListOfConstraints())
        if F != MOI.SingleVariable
            for moi_index in MOI.get(src, MOI.ListOfConstraintIndices{F, S}())
                func = MOI.get(src, MOI.ConstraintFunction(), moi_index)
                set = MOI.get(src, MOI.ConstraintSet(), moi_index)
                if copy_names
                    name = MOI.get(src, MOI.ConstraintName(), moi_index)
                else
                    name = string("constr_", moi_index.value)
                end
                create_origconstr!(
                    form, dest, src, name, func, set, moi_index,
                    moi_uid_to_coluna_id
                )
            end
        end
    end
    return 
end

function register_original_formulation!(dest::Optimizer,
                                        src::MOI.ModelLike,
                                        copy_names::Bool)
    copy_names = true
    problem = dest.inner
    orig_form = Formulation{Original}(problem.form_counter)
    set_original_formulation!(problem, orig_form)

    costs = getvarcosts(src)
    kinds, lbs, ubs = get_var_kinds_and_bounds(src)

    moi_uid_to_coluna_id = Dict{Int,VarId}()
    create_origvars!(orig_form, dest, src, costs, kinds, lbs, ubs, copy_names, moi_uid_to_coluna_id)
    create_origconstrs!(orig_form, dest, src, copy_names, moi_uid_to_coluna_id)

    sense = MOI.get(src, MOI.ObjectiveSense())
    min_sense = (sense == MOI.MIN_SENSE)
    register_objective_sense!(orig_form, min_sense)

    dest.annotations.tree = MOI.get(src, BD.DecompositionTree())
    return
end

function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike; copy_names=true)
    register_original_formulation!(dest, src, copy_names)
    @debug "\e[1;34m Original formulation \e[00m" dest.inner.original_formulation
    return dest.moi_index_to_coluna_uid
end

function MOI.empty!(optimizer::Optimizer)
    optimizer.inner.re_formulation = nothing
end

# ######################
# ### Get functions ####
# ######################

MOI.is_empty(optimizer::Optimizer) = (optimizer.inner.re_formulation == nothing)

function MOI.get(optimizer::Optimizer, object::MOI.ObjectiveBound)
    return getvalue(getprimalbound(optimizer.result))
end

function MOI.get(optimizer::Optimizer, object::MOI.ObjectiveValue)
    return getvalue(getprimalbound(optimizer.result))
end

function MOI.get(optimizer::Optimizer, object::MOI.VariablePrimal,
                 ref::MOI.VariableIndex)
    id = optimizer.varmap[ref] # This gets a coluna Id{Variable}
    var_val_dict = getsol(unsafe_getbestprimalsol(optimizer.result))
    return get(var_val_dict, id, 0.0)
end

function MOI.get(optimizer::Optimizer, object::MOI.VariablePrimal,
                 refs::Vector{MOI.VariableIndex})
    var_val_dict = getsol(unsafe_getbestprimalsol(optimizer.result))
    return [get(var_val_dict, optimizer.varmap[ref], 0.0) for ref in refs]
end

function MOI.get(optimizer::Optimizer, object::MOI.TerminationStatus)
    result = optimizer.result
    isfeasible(result) && return convert_status(getterminationstatus(result))
    getfeasibilitystatus(result) == INFEASIBLE && return MOI.INFEASIBLE
    getfeasibilitystatus(result) == UNKNOWN_FEASIBILITY && return MOI.OTHER_LIMIT
    error(string(
        "Could not determine MOI status. Coluna termination : ", 
        getterminationstatus(result), ". Coluna feasibility : ", 
        getfeasibilitystatus(result)
    ))
    return
end
