const SupportedObjFunc = Union{MOI.ScalarAffineFunction{Float64}}

const SupportedVarSets = Union{MOI.ZeroOne,
                               MOI.Integer,
                               MOI.LessThan{Float64},
                               MOI.EqualTo{Float64},
                               MOI.GreaterThan{Float64},
                               MOI.Interval{Float64}}

const SupportedConstrFunc = Union{MOI.ScalarAffineFunction{Float64}}

const SupportedConstrSets = Union{MOI.EqualTo{Float64},
                                  MOI.GreaterThan{Float64},
                                  MOI.LessThan{Float64}}

mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::Problem
    moi_index_to_coluna_uid::MOIU.IndexMap
    # varmap::Dict{MOI.VariableIndex,Variable} ## Keys and values are created in this file
    # # add conmap here
    # constr_probidx_map::Dict{Constraint,Int}
    # var_probidx_map::Dict{Variable,Int}
    # nb_subproblems::Int
    # master_factory::JuMP.OptimizerFactory
    # pricing_factory::JuMP.OptimizerFactory
end

setinnerprob!(o::Optimizer, prob::Problem) = o.inner = prob

function Optimizer(;master_factory =
        JuMP.with_optimizer(GLPK.Optimizer), pricing_factory =
        JuMP.with_optimizer(GLPK.Optimizer), params = Params())
    prob = Problem(params, master_factory, pricing_factory)
    return Optimizer(prob, MOIU.IndexMap())
end

function MOI.optimize!(optimizer::Optimizer)
    optimize!(optimizer.inner)
end

function MOI.get(dest::MOIU.UniversalFallback,
                 attribute::BD.ConstraintDecomposition,
                 ci::MOI.ConstraintIndex)
    if haskey(dest.conattr, attribute)
        if haskey(dest.conattr[attribute], ci)
            return dest.conattr[attribute][ci]
        end
    end
    return ()
end

function MOI.get(dest::MOIU.UniversalFallback,
                 attribute::BD.VariableDecomposition,
                 vi::MOI.VariableIndex)
    if haskey(dest.varattr, attribute)
        if haskey(dest.varattr[attribute], vi)
            return dest.varattr[attribute][vi]
        end
    end
    return ()
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

function get_id_var(f::Formulation, uid::Int)
    id = get_varid_from_uid(f, uid)
    var = get(f, id)
    return id, var
end

function load_obj!(f::Formulation, src::MOI.ModelLike,
                   moi_index_to_coluna_uid::MOIU.IndexMap)
    # We need to increment values of cost_rhs with += to handle cases like $x_1 + x_2 + x_1$
    # This is safe becasue the variables are initialized with a 0.0 cost_rhs
    obj = MOI.get(src, MoiObjective())
    for term in obj.terms
        id, var = get_id_var(f, moi_index_to_coluna_uid[term.variable_index].value)
        setcost!(getstate(id), term.coefficient)
        setcost!(var, term.coefficient)
    end
    return
end

function create_origvars!(f::Formulation,
                          src::MOI.ModelLike,
                          copy_names::Bool,
                          moi_index_to_coluna_uid::MOIU.IndexMap,
                          vars_per_block::Dict{Int, VarDict},
                          annotation_set::Set{BD.Annotation})
    
    for moi_index in MOI.get(src, MOI.ListOfVariableIndices())
        if copy_names
            name = MOI.get(src, MOI.VariableName(), moi_index)
        else
            name = string("var_", moi_index.value)
        end
        var = Variable(name)
        coluna_id = add!(f, var, OriginalVar)
        moi_index_to_coluna_uid[moi_index] = MOI.VariableIndex(getuid(coluna_id))
        annotation = MOI.get(src, BD.VariableDecomposition(), moi_index)
        push!(annotation_set,annotation)
        if haskey(vars_per_block, annotation.unique_id)
            set!(vars_per_block[annotation.unique_id], coluna_id, var)
        else
            vars_per_block[annotation.unique_id] = VarDict()
            set!(vars_per_block[annotation.unique_id], coluna_id, var)
        end
    end
    return
end

function create_origconstr!(f::Formulation,
                            func::MOI.SingleVariable,
                            set::SupportedVarSets,
                            moi_index_to_coluna_uid::MOIU.IndexMap)
    
    id, var = get_id_var(f, moi_index_to_coluna_uid[func.variable].value)
    set!(var, set)
    sync!(getstate(id), var)
    
   return
end

function create_origconstr!(src::MOI.ModelLike,
                            f::Formulation,
                            name::String,
                            func::MOI.ScalarAffineFunction,
                            set::SupportedConstrSets,
                            moi_index::MOI.ConstraintIndex,
                            moi_index_to_coluna_uid::MOIU.IndexMap,
                            constrs_per_block::Dict{Int, ConstrDict},
                            annotation_set::Set{BD.Annotation})
    constr = Constraint(name)
    set!(constr, set)
    membership = VarMemberDict()
    for term in func.terms
        var_id = get_varid_from_uid(f, moi_index_to_coluna_uid[term.variable_index].value)
        add!(membership, var_id, term.coefficient)
    end
    id = add!(f, constr, OriginalConstr, membership)
    moi_index_to_coluna_uid[moi_index] = MOI.ConstraintIndex{typeof(func),typeof(set)}(
        getuid(id)
    )
    annotation = MOI.get(src, BD.ConstraintDecomposition(), moi_index)
    push!(annotation_set,annotation)
    if haskey(constrs_per_block, annotation.unique_id)
        set!(constrs_per_block[annotation.unique_id], id, constr)
    else
        constrs_per_block[annotation.unique_id] = ConstrDict()
        set!(constrs_per_block[annotation.unique_id], id, constr)
    end
    return
end

function create_origconstrs!(f::Formulation,
                             src::MOI.ModelLike,
                             copy_names::Bool,
                             moi_index_to_coluna_uid::MOIU.IndexMap,
                             constrs_per_block::Dict{Int, ConstrDict},
                             annotation_set::Set{BD.Annotation})

    for (F, S) in MOI.get(src, MOI.ListOfConstraints())
        for moi_index in MOI.get(src, MOI.ListOfConstraintIndices{F, S}())
            if copy_names
                name = MOI.get(src, MOI.ConstraintName(), moi_index)
            else
                name = string("constr_", moi_index.value)
            end
            func = MOI.get(src, MOI.ConstraintFunction(), moi_index)
            set = MOI.get(src, MOI.ConstraintSet(), moi_index)

            if func isa MOI.SingleVariable
                create_origconstr!(f, func, set, moi_index_to_coluna_uid)
            else
                create_origconstr!(src, f, name, func, set, moi_index,
                                   moi_index_to_coluna_uid,
                                   constrs_per_block,
                                   annotation_set)
            end
        end
    end
    return 
end

function register_original_formulation!(dest::Optimizer,
                                        src::MOI.ModelLike,
                                        copy_names)
    problem = dest.inner
    
    copy_names = true
    
    orig_form = Formulation(Original, problem)
    set_original_formulation!(problem, orig_form)

    create_origvars!(orig_form, src, copy_names,
                     dest.moi_index_to_coluna_uid,
                     problem.vars_per_block,
                     problem.annotation_set)
    
    create_origconstrs!(orig_form, src, copy_names,
                        dest.moi_index_to_coluna_uid,
                        problem.constrs_per_block,
                        problem.annotation_set)

    load_obj!(orig_form, src, dest.moi_index_to_coluna_uid)

    sense = MOI.get(src, MOI.ObjectiveSense())
    min_sense = (sense == MOI.MIN_SENSE)
    register_objective_sense!(orig_form, min_sense)
    return
end

function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike; copy_names=true)
    prob = dest.inner

    register_original_formulation!(dest, src, copy_names)

    println(" \e[34m ORIGINAL FORMULATION \e[00m")
    @show prob.original_formulation
    println("\e[34m END ORIGINAL FORMULATION \e[00m")
    return dest.moi_index_to_coluna_uid
end

function MOI.empty!(optimizer::Optimizer)
    optimizer.inner.re_formulation = nothing
end

# ######################
# ### Get functions ####
# ######################

MOI.is_empty(optimizer::Optimizer) = (optimizer.inner.re_formulation == nothing)

# function MOI.get(coluna_optimizer::Optimizer, object::MOI.ObjectiveBound)
#     return coluna_optimizer.inner.extended_problem.dual_inc_bound
# end

# function MOI.get(coluna_optimizer::Optimizer, object::MOI.ObjectiveValue)
#     return coluna_optimizer.inner.extended_problem.primal_inc_bound
# end

# function get_coluna_var_val(coluna_optimizer::Optimizer, sp_var::SubprobVar)
#     solution = coluna_optimizer.inner.extended_problem.solution.var_val_map
#     sp_var_val = 0.0
#     for (var,val) in solution
#         if isa(var, MasterVar)
#             continue
#         end
#         if haskey(var.solution.var_val_map, sp_var)
#             sp_var_val += val*var.solution.var_val_map[sp_var]
#         end
#     end
#     return sp_var_val
# end

# function get_coluna_var_val(coluna_optimizer::Optimizer, var::MasterVar)
#     solution = coluna_optimizer.inner.extended_problem.solution
#     if haskey(solution.var_val_map, var)
#         return solution.var_val_map[var]
#     else
#         return 0.0
#     end
# end

# function MOI.get(coluna_optimizer::Optimizer,
#                  object::MOI.VariablePrimal, ref::MOI.VariableIndex)
#     var = coluna_optimizer.varmap[ref] # This gets a coluna variable
#     return get_coluna_var_val(coluna_optimizer, var)
# end

# function MOI.get(coluna_optimizer::Optimizer,
#                  object::MOI.VariablePrimal, ref::Vector{MOI.VariableIndex})
#     return [MOI.get(coluna_optimizer, object, ref[i]) for i in 1:length(ref)]
# end
