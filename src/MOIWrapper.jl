const SupportedObjFunc = Union{MOI.ScalarAffineFunction{Float64},
                               MOI.SingleVariable}

const SupportedVarSets = Union{MOI.Nonnegatives, 
                                MOI.Zeros,
                                MOI.Nonpositives,
                                MOI.ZeroOne,
                                MOI.Integer,
                                MOI.LessThan{Float64},
                                MOI.EqualTo{Float64},
                                MOI.GreaterThan{Float64},
                                MOI.Interval{Float64}}

const SupportedConstrFunc = Union{MOI.ScalarAffineFunction{Float64}}

const SupportedConstrSets = Union{MOI.EqualTo{Float64},
                                  MOI.GreaterThan{Float64},
                                  MOI.LessThan{Float64},
                                  MOI.Zeros}

mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::Problem
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
    return Optimizer(prob)
end

function MOI.optimize!(optimizer::Optimizer)
    optimize!(optimizer.inner)
end

function MOI.get(dest::MOIU.UniversalFallback,
        attribute::BD.ConstraintDecomposition, ci::MOI.ConstraintIndex)
    if haskey(dest.conattr, attribute)
        if haskey(dest.conattr[attribute], ci)
            return dest.conattr[attribute][ci]
        end
    end
    return ()
end

function MOI.get(dest::MOIU.UniversalFallback,
        attribute::BD.VariableDecomposition, vi::MOI.VariableIndex)
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

function load_obj!(vars::Vector{Variable}, prob::Problem,
        f::MOI.ScalarAffineFunction)
    # We need to increment values of cost_rhs with += to handle cases like $x_1 + x_2 + x_1$
    # This is safe becasue the variables are initialized with a 0.0 cost_rhs
    for term in f.terms
        coluna_var_id = prob.mid2uid_map[term.variable_index].value
        setcost!(vars[coluna_var_id], term.coefficient)
    end
    return
end

function create_origvars!(vars::Vector{Variable}, f::Formulation, prob::Problem, 
        src::MOI.ModelLike, copy_names::Bool)
    for m_var_id in MOI.get(src, MOI.ListOfVariableIndices())
        if copy_names
            name = MOI.get(src, MOI.VariableName(), m_var_id)
        else
            name = string("var_", m_var_id.value)
        end
        var = Variable(name)
        push!(vars, var)
        c_var_id = add!(f, var, OriginalVar)
        prob.mid2cid_map[m_var_id] = (c_var_id, var)
        prob.mid2uid_map[m_var_id] = MOI.VariableIndex(getuid(c_var_id))
    end
    return
end

function create_origconstr!(constrs, f::Formulation,
        prob, name, func::MOI.SingleVariable, set, m_constr_id)
    (c_var_id, var) = prob.mid2cid_map[func.variable]
    set!(var, set)
    sync!(getinfo(c_var_id), var)
    return
end

function create_origconstr!(constrs, f::Formulation,
        prob, name, func::MOI.ScalarAffineFunction, set, m_constr_id)
    constr = Constraint(name)
    set!(constr, set)
    push!(constrs, constr)
    membership = VarMemberDict()
    for term in func.terms
        c_var_id = prob.mid2cid_map[term.variable_index][1]
        add!(membership, c_var_id, term.coefficient)
    end
    c_constr_id = add!(f, constr, OriginalConstr, membership)
    id = MOI.ConstraintIndex{typeof(func),typeof(set)}(getuid(c_constr_id))
    prob.mid2cid_map[m_constr_id] = (c_constr_id, constr)
    prob.mid2uid_map[m_constr_id] = id
    return
end

function create_origconstrs!(constrs::Vector{Constraint}, f::Formulation,
        prob::Problem, src::MOI.ModelLike, copy_names::Bool)
    for (F, S) in MOI.get(src, MOI.ListOfConstraints())
        for m_constr_id in MOI.get(src, MOI.ListOfConstraintIndices{F, S}())
            if copy_names
                name = MOI.get(src, MOI.ConstraintName(), m_constr_id)
            else
                name = string("constr_", m_constr_id.value)
            end
            func = MOI.get(src, MOI.ConstraintFunction(), m_constr_id)
            set = MOI.get(src, MOI.ConstraintSet(), m_constr_id)
            create_origconstr!(constrs, f, prob, name, func, set, m_constr_id)
        end
    end
    return
end

function register_original_formulation!(prob::Problem, dest::Optimizer, src::MOI.ModelLike, copy_names)
    copy_names = true
    orig_form = Formulation(Original, prob)#, src)
    set_original_formulation!(prob, orig_form)

    vars = Variable[]
    create_origvars!(vars, orig_form, prob, src, copy_names)

    constrs = Constraint[]
    create_origconstrs!(constrs, orig_form, prob, src, copy_names)

    obj = MOI.get(src, MoiObjective())
    load_obj!(vars, prob, obj)

    sense = MOI.get(src, MOI.ObjectiveSense())
    min_sense = (sense == MOI.MIN_SENSE)
    register_objective_sense!(orig_form, min_sense)
    return
end

function load_annotation!(p::Problem, m_id, c_id::Id{VarState}, var, src::MOI.ModelLike)
    p.var_annotations[(c_id, var)] = MOI.get(src, BD.VariableDecomposition(), m_id)
    return
end

function load_annotation!(p::Problem, m_id, c_id::Id{ConstrState}, constr, src::MOI.ModelLike)
    p.constr_annotations[(c_id, constr)] = MOI.get(src, BD.ConstraintDecomposition(), m_id)
    return
end

function load_decomposition_annotations!(prob::Problem, src::MOI.ModelLike)
    for (m_id, (c_id, varconstr)) in prob.mid2cid_map
       load_annotation!(prob, m_id, c_id, varconstr, src)
    end
    return
end

function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike; copy_names=true)
    prob = dest.inner

    register_original_formulation!(prob, dest, src, copy_names)

    # Retrieve annotation
    load_decomposition_annotations!(prob, src)

    println(" \e[34m ORIGINAL FORMULATION \e[00m")
    @show prob.original_formulation
    println("\e[34m END ORIGINAL FORMULATION \e[00m")
    return prob.mid2uid_map
end

# function set_optimizers_dict(dest::Optimizer)
#     @warn "To be updated"
#     # set coluna optimizers
#     # prob = dest.inner
#     # master_problem = prob.extended_problem.master_problem
#     # prob.problemidx_optimizer_map[master_problem.prob_ref] =
#     #         dest.master_factory()
#     # for subprobidx in 1:dest.nb_subproblems
#     #     pricingprob = prob.extended_problem.pricing_vect[subprobidx]
#     #     prob.problemidx_optimizer_map[pricingprob.prob_ref] =
#     #             dest.pricing_factory()
#     # end
# end

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
