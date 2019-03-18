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
    inner::Union{Nothing, Model}
    # varmap::Dict{MOI.VariableIndex,Variable} ## Keys and values are created in this file
    # # add conmap here
    # constr_probidx_map::Dict{Constraint,Int}
    # var_probidx_map::Dict{Variable,Int}
    # nb_subproblems::Int
    # master_factory::JuMP.OptimizerFactory
    # pricing_factory::JuMP.OptimizerFactory
end

function Optimizer(;kwargs...)
    return Optimizer(nothing)
end

function MOI.optimize!(optimizer::Optimizer)
    println("\e[34m OPTIMIZE \e[00m")
end

# function MOI.optimize!(coluna_optimizer::Optimizer)
#     solve(coluna_optimizer.inner)
# end
MOI.supports(m::MOI.ModelLike, attr::BD.ConstraintDecomposition) = true
MOI.supports(m::MOI.ModelLike, attr::BD.VariableDecomposition) = true
MOI.supports(m::MOI.ModelLike, attr::BD.ConstraintDecomposition, ::Type{MOI.ConstraintIndex{F,S}}) where {F,S} = true 
MOI.supports(m::MOI.ModelLike, attr::BD.VariableDecomposition, ::Type{MOI.VariableIndex}) = true

function MOI.get(dest::MOIU.UniversalFallback, 
        attribute::BD.ConstraintDecomposition, ci::MOI.ConstraintIndex)
    if haskey(dest.conattr, attribute)
        if haskey(dest.conattr[attribute], ci)
            return dest.conattr[attribute][ci]
        end
        #error("No annotation found for constraint $ci.")
    end
    return ()
end

function MOI.get(dest::MOIU.UniversalFallback,
        attribute::BD.VariableDecomposition, vi::MOI.VariableIndex)
    if haskey(dest.varattr, attribute)
        if haskey(dest.varattr[attribute], vi)
            return dest.varattr[attribute][vi]
        end
        #error("No annotation found for variable $vi.")
    end
    return ()
end

# ##########################################
# # Functions needed during copy procedure #
# ##########################################
# function add_memberships(dest::Optimizer, problem::Problem, constr::Constraint,
#                          f::MOI.ScalarAffineFunction, mapping::MOIU.IndexMap)
#     for term in f.terms
#         add_membership(dest.varmap[mapping.varmap[term.variable_index]],
#                        constr, term.coefficient; optimizer = nothing)
#     end


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

function load_obj!(vars::Vector{Variable}, moi_map::MOIU.IndexMap,
                  f::MOI.ScalarAffineFunction)
    # We need to increment values of cost_rhs with += to handle cases like $x_1 + x_2 + x_1$
    # This is safe becasue the variables are initialized with a 0.0 cost_rhs
    for term in f.terms
        coluna_var_id = moi_map[term.variable_index].value
        setcost!(vars[coluna_var_id], term.coefficient)
    end
    return
end

function create_origvars!(m::Model, orig_form::Formulation, 
        moi_map::MOIU.IndexMap, src::MOI.ModelLike, copy_names::Bool)
    vars = Variable[]
    for m_var_id in MOI.get(src, MOI.ListOfVariableIndices())
        if copy_names
            name = MOI.get(src, MOI.VariableName(), m_var_id)
        else
            name = string("var_", m_var_id.value)
        end
        var = OriginalVariable(m, name)
        push!(vars, var)
        c_var_id = MOI.VariableIndex(getuidval(var))
        setindex!(moi_map, m_var_id, c_var_id)
    end
    return vars
end

function create_origconstr!(constrs::Vector{Constraint}, vars::Vector{Variable}, 
        moi_map::MOIU.IndexMap, m::Model, name::String, 
        func::MOI.SingleVariable, set, m_constr_id)
    c_var_id = moi_map[func.variable].value
    set!(vars[c_var_id], set)
    return
end

function create_origconstr!(constrs::Vector{Constraint}, vars::Vector{Variable}, 
        moi_map::MOIU.IndexMap, m::Model, name::String, 
        f::MOI.ScalarAffineFunction, s, m_constr_id)
    constr = OriginalConstraint(m, name)
    set!(constr, s)
    push!(constrs, constr)
    for term in f.terms
        # term.variable_index, term.coefficient
    end
    c_constr_id = MOI.ConstraintIndex{typeof(f),typeof(s)}(getuidval(constr))
    setindex!(moi_map, m_constr_id, c_constr_id)
    return
end

function create_origconstrs!(m::Model, orig_form::Formulation,
        moi_map::MOIU.IndexMap, src::MOI.ModelLike, vars, copy_names::Bool)
    constrs = Constraint[]
    for (F, S) in MOI.get(src, MOI.ListOfConstraints())
        for m_constr_id in MOI.get(src, MOI.ListOfConstraintIndices{F, S}())
            if copy_names
                name = MOI.get(src, MOI.ConstraintName(), m_constr_id)
            else
                name = string("constr_", m_constr_id.value)
            end
            f = MOI.get(src, MOI.ConstraintFunction(), m_constr_id)
            s = MOI.get(src, MOI.ConstraintSet(), m_constr_id)
            create_origconstr!(constrs, vars, moi_map, m, name, f, s, m_constr_id)
        end
    end
    return constrs
end

function load_decomposition!(dest::Optimizer, src::MOI.ModelLike, 
        moi_map::MOIU.IndexMap)
    println("\e[1m load decomposition. \e[0m")
    for (m_id, c_id) in moi_map.conmap
        if typeof(m_id) <: MOI.ConstraintIndex
            @show m_id
            @show c_id
            @show MOI.get(src, BD.ConstraintDecomposition(), m_id)
            println("\e[31m --------------- \e[00m")
        end
    end
    for (m_id, c_id) in moi_map.varmap
        if typeof(m_id) <: MOI.VariableIndex
            @show m_id
            @show c_id
            @show MOI.get(src, BD.VariableDecomposition(), m_id)
        end
        println("\e[31m --------------- \e[00m")
    end
    exit()
end

function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike; copy_names=true)
    println("\e[1m;45m COPY TO \e[00m")
    var_counter = Counter{Variable}()
    constr_counter = Counter{Constraint}()

    mapping = MOIU.IndexMap() # map from moi idx to coluna idx
    model = Model()
    orig_form = OriginalFormulation(src)

    vars = create_origvars!(model, orig_form, mapping, src, copy_names)
    constrs = create_origconstrs!(model, orig_form, mapping, src, vars, copy_names)

    obj = MOI.get(src, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    sense = MOI.get(src, MOI.ObjectiveSense())
    load_obj!(vars, mapping, obj)
    load_decomposition!(dest, src, mapping)
    return mapping
end

# # Set functions
# function set_card_bounds_dict(src::MOI.ModelLike,
#                               extended_problem::ExtendedProblem)
#     card_bounds_dict = MOI.get(src, DantzigWolfePricingCardinalityBounds())
#     for (idx, pricing_prob) in enumerate(extended_problem.pricing_vect)
#         extended_problem.problem_ref_to_card_bounds[
#             pricing_prob.prob_ref
#         ] = get(card_bounds_dict, idx, (1,1))
#     end
# end

# function set_optimizers_dict(dest::Optimizer)
#     # set coluna optimizers
#     model = dest.inner
#     master_problem = model.extended_problem.master_problem
#     model.problemidx_optimizer_map[master_problem.prob_ref] =
#             dest.master_factory()
#     for subprobidx in 1:dest.nb_subproblems
#         pricingprob = model.extended_problem.pricing_vect[subprobidx]
#         model.problemidx_optimizer_map[pricingprob.prob_ref] =
#                 dest.pricing_factory()
#     end
# end

# function MOI.set(coluna_optimizer::Optimizer, object::MOI.ObjectiveSense,
#                   sense::MOI.OptimizationSense)
#     if sense != MOI.MIN_SENSE
#         throw(MOI.CannotSetAttribute{MOI.ObjectiveSense}(MOI.ObjectiveSense, "Coluna only supports minimization sense for now."))
#     end
# end

function MOI.empty!(optimizer::Optimizer)
    optimizer.inner = nothing
end

# ######################
# ### Get functions ####
# ######################

MOI.is_empty(optimizer::Optimizer) = (optimizer.inner == nothing)

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

# function MOI.get(coluna_optimizer::Optimizer, object::MOI.ObjectiveSense)
#     # MaxSense is currently not supported
#     return MOI.MIN_SENSE
# end
