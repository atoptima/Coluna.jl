const SupportedObjFunc = Union{MOI.ScalarAffineFunction{Float64}}

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

function Optimizer(;master_factory =
        JuMP.with_optimizer(GLPK.Optimizer), pricing_factory =
        JuMP.with_optimizer(GLPK.Optimizer), benders_sep_factory =
        JuMP.with_optimizer(GLPK.Optimizer), params = Params())
    prob = Problem(master_factory, pricing_factory, benders_sep_factory)
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

function update_annotations(srs::MOI.ModelLike,
                            annotation_set::Set{BD.Annotation},
                            vc_per_block::Dict{Int,C},
                            annotation::A,
                            vc::AbstractVarConstr
                            ) where {C<:VarConstrDict,A}
    push!(annotation_set, annotation)
    if !haskey(vc_per_block, annotation.unique_id)
        vc_per_block[annotation.unique_id] = C()
    end
    vc_per_block[annotation.unique_id][getid(vc)] = vc
    return
end

function load_obj!(f::Formulation, src::MOI.ModelLike,
                   moi_index_to_coluna_uid::MOIU.IndexMap,
                   moi_uid_to_coluna_id::Dict{Int,VarId})
    # We need to increment values of cost_rhs with += to handle cases like $x_1 + x_2 + x_1$
    # This is safe becasue the variables are initialized with a 0.0 cost_rhs
    obj = MOI.get(src, MoiObjective())
    for term in obj.terms
        var = getvar(f, moi_uid_to_coluna_id[term.variable_index.value])
        perene_data = getrecordeddata(var)
        setcost!(perene_data, term.coefficient)
        setcost!(f, var, term.coefficient)
    end
    return
end

function create_origvars!(f::Formulation,
                          dest::Optimizer,
                          src::MOI.ModelLike,
                          copy_names::Bool,
                          moi_uid_to_coluna_id::Dict{Int,VarId})

    for moi_index in MOI.get(src, MOI.ListOfVariableIndices())
        if copy_names
            name = MOI.get(src, MOI.VariableName(), moi_index)
        else
            name = string("var_", moi_index.value)
        end
        v = setvar!(f, name, OriginalVar)
        var_id = getid(v)
        moi_index_in_coluna = deepcopy(moi_index) # MOI.VariableIndex(getuid(var_id))
        dest.moi_index_to_coluna_uid[moi_index] = moi_index_in_coluna
        moi_uid_to_coluna_id[moi_index.value] = var_id
        annotation = MOI.get(src, BD.VariableDecomposition(), moi_index)
        dest.varmap[moi_index_in_coluna] = var_id
        update_annotations(
            src, dest.annotations.annotation_set,
            dest.annotations.vars_per_block, annotation, v
        )
    end
end

function create_origconstr!(f::Formulation,
                            func::MOI.SingleVariable,
                            set::SupportedVarSets,
                            moi_index_to_coluna_uid::MOIU.IndexMap,
                            moi_uid_to_coluna_id::Dict{Int,VarId})

    var = getvar(f, moi_uid_to_coluna_id[func.variable.value])
    perene_data = getrecordeddata(var)
    if typeof(set) in [MOI.ZeroOne, MOI.Integer]
        setkind!(perene_data, getkind(set))
        setkind!(f, var, getkind(set))
    else
        bound = getrhs(set)
        if getsense(set) in [Equal, Less]
            set_ub!(perene_data, bound)
            setub!(f, var, getub(perene_data))
        elseif getsense(set) == [Equal, Greater]
            set_lb!(perene_data, bound)
            setlb!(f, var, getlb(perene_data))
        end
    end
    return
end

function create_origconstr!(f::Formulation,
                            dest::Optimizer,
                            src::MOI.ModelLike,
                            name::String,
                            func::MOI.ScalarAffineFunction,
                            set::SupportedConstrSets,
                            moi_index::MOI.ConstraintIndex,
                            moi_uid_to_coluna_id::Dict{Int,VarId})

    c = setconstr!(f, name, OriginalConstr;
                    rhs = getrhs(set),
                    kind = Core,
                    sense = getsense(set),
                    inc_val = 10.0) #TODO set inc_val in model
    constr_id = getid(c)
    dest.moi_index_to_coluna_uid[moi_index] =
        MOI.ConstraintIndex{typeof(func),typeof(set)}(getuid(constr_id))
    matrix = getcoefmatrix(f)
    for term in func.terms
        var_id = moi_uid_to_coluna_id[term.variable_index.value]
        matrix[constr_id, var_id] = term.coefficient
    end
    annotation = MOI.get(src, BD.ConstraintDecomposition(), moi_index)
    update_annotations(
        src, dest.annotations.annotation_set,
        dest.annotations.constrs_per_block, annotation, c
    )
    return
end

function create_origconstrs!(f::Formulation,
                             dest::Optimizer,
                             src::MOI.ModelLike,
                             copy_names::Bool,
                             moi_uid_to_coluna_id::Dict{Int,VarId})

    for (F, S) in MOI.get(src, MOI.ListOfConstraints())
        for moi_index in MOI.get(src, MOI.ListOfConstraintIndices{F, S}())
            func = MOI.get(src, MOI.ConstraintFunction(), moi_index)
            set = MOI.get(src, MOI.ConstraintSet(), moi_index)
            if func isa MOI.SingleVariable
                create_origconstr!(
                    f, func, set, dest.moi_index_to_coluna_uid,
                    moi_uid_to_coluna_id
                )
            else
                if copy_names
                    name = MOI.get(src, MOI.ConstraintName(), moi_index)
                else
                    name = string("constr_", moi_index.value)
                end
                create_origconstr!(
                    f, dest, src, name, func, set, moi_index,
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
    moi_uid_to_coluna_id = Dict{Int,VarId}()

    create_origvars!(orig_form, dest, src, copy_names, moi_uid_to_coluna_id)
    create_origconstrs!(orig_form, dest, src, copy_names, moi_uid_to_coluna_id)

    load_obj!(orig_form, src, dest.moi_index_to_coluna_uid, moi_uid_to_coluna_id)
    sense = MOI.get(src, MOI.ObjectiveSense())
    min_sense = (sense == MOI.MIN_SENSE)
    register_objective_sense!(orig_form, min_sense)
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
    var_val_dict = getsol(getbestprimalsol(optimizer.result))
    return get(var_val_dict, id, 0.0)
end

function MOI.get(optimizer::Optimizer, object::MOI.VariablePrimal,
                 refs::Vector{MOI.VariableIndex})
    var_val_dict = getsol(getbestprimalsol(optimizer.result))
    return [get(var_val_dict, optimizer.varmap[ref], 0.0) for ref in refs]
end

function MOI.get(optimizer::Optimizer, object::MOI.TerminationStatus)
    result = optimizer.result
    isfeasible(result) && return MOI.OPTIMAL
    !isfeasible(result) && return MOI.INFEASIBLE
end