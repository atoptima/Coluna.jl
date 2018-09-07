export ColunaModelOptimizer

mutable struct ColunaModelOptimizer <: MOI.AbstractOptimizer
    inner::Model
    varmap::Dict{MOI.VariableIndex,Variable} ## Keys and values are created in this file
    # add conmap here
    constr_probidx_map::Dict{Constraint,Int}
    var_probidx_map::Dict{Variable,Int}
    nb_subproblems::Int
    function ColunaModelOptimizer()
        coluna_model = ModelConstructor()
        _varmap = Dict{MOI.VariableIndex,Variable}()
        _constr_probidx_map = Dict{Constraint,Int}()
        _var_probidx_map = Dict{Variable,Int}()
        new(coluna_model, _varmap, _constr_probidx_map, _var_probidx_map, 0)
    end
end

function MOI.optimize!(coluna_optimizer::ColunaModelOptimizer)
    solve(coluna_optimizer.inner)
end

############################################
# Annotations needed for column generation #
############################################
# Problem Index: if 0 -> Master problem, if > 0 -> subproblem index
struct ConstraintDantzigWolfeAnnotation <: MOI.AbstractConstraintAttribute end

function MOI.set(dest::MOIU.UniversalFallback, attribute::ConstraintDantzigWolfeAnnotation,
                  ci::MOI.ConstraintIndex, value::Int)
    if haskey(dest.conattr, attribute)
        dest.conattr[attribute][ci] = value
    else
        dest.conattr[attribute] = Dict{MOI.ConstraintIndex,Int}()
        dest.conattr[attribute][ci] = value
    end
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::ConstraintDantzigWolfeAnnotation,
                 ci::MOI.ConstraintIndex)
    if haskey(dest.conattr, attribute)
        if haskey(dest.conattr[attribute], ci)
            return dest.conattr[attribute][ci]
        end
    end
    return -1 # Returns value -1 as default if not found
end

# Problem Index: if 0 -> Master problem, if > 0 -> subproblem index
struct VariableDantzigWolfeAnnotation <: MOI.AbstractVariableAttribute end

function MOI.set(dest::MOIU.UniversalFallback, attribute::VariableDantzigWolfeAnnotation,
                  vi::MOI.VariableIndex, value::Int)
    if haskey(dest.varattr, attribute)
        dest.varattr[attribute][vi] = value
    else
        dest.varattr[attribute] = Dict{MOI.VariableIndex,Int}()
        dest.varattr[attribute][vi] = value
    end
end

function MOI.get(dest::MOIU.UniversalFallback, attribute::VariableDantzigWolfeAnnotation,
                 vi::MOI.VariableIndex)
    if haskey(dest.varattr, attribute)
        if haskey(dest.varattr[attribute], vi)
            return dest.varattr[attribute][vi]
        end
    end
    return -1 # Returns value -1 as default if not found
end

##########################################
# Functions needed during copy procedure #
##########################################
function load_obj(dest::ColunaModelOptimizer, mapping::MOIU.IndexMap,
                  f::MOI.ScalarAffineFunction)
    # We need to increment values of cost_rhs with += to handle cases like $x_1 + x_2 + x_1$
    # This is safe becasue the variables are initialized with a 0.0 cost_rhs
    for term in f.terms
        dest.varmap[mapping.varmap[term.variable_index]].cost_rhs += term.coefficient
    end
end

function add_memberships(dest::ColunaModelOptimizer, problem::Problem, constr::Constraint,
                         f::MOI.ScalarAffineFunction, mapping::MOIU.IndexMap)
    for term in f.terms
        add_membership(problem, dest.varmap[mapping.varmap[term.variable_index]],
                       constr, term.coefficient)
    end
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         src::MOI.ModelLike, mapping::MOIU.IndexMap,
                         f::MOI.ScalarAffineFunction, s::MOI.AbstractSet,
                         rhs::Float64, sense::Char, copy_names::Bool)
    if copy_names
        name = MOI.get(src, MOI.ConstraintName(), ci)
    else
        name = string("constraint_", ci.value)
    end
    prob_idx = MOI.get(src, ConstraintDantzigWolfeAnnotation(), ci)
    if prob_idx <= 0
        problem = dest.inner.extended_problem.master_problem
        constr = MasterConstr(problem.counter, name, rhs, sense, 'M', 's')
    else
        problem = dest.inner.extended_problem.pricing_vect[prob_idx]
        constr = Constraint(problem.counter, name, rhs, sense, 'M', 's')
    end
    dest.constr_probidx_map[constr] = prob_idx
    add_constraint(problem, constr) # Adds the constr to the lower-level solver
    add_memberships(dest, problem, constr, f, mapping) # Do only if prob_idx is 0
    update_constraint_map(mapping, ci, f, s)
end

function MOI.supports_constraint(model::ColunaModelOptimizer, 
        ::Type{MOI.SingleVariable}, 
        ::Type{<:Union{MOI.ZeroOne, MOI.Integer}}) where T
        
    return true
end

function MOI.supports_constraint(model::ColunaModelOptimizer, 
        ::Type{MOI.SingleVariable},
        ::Type{<:Union{MOI.EqualTo{T}, MOI.GreaterThan{T}, MOI.LessThan{T}}}) where T
        
    return true
end

function MOI.supports_constraint(model::ColunaModelOptimizer, 
        ::Type{MOI.ScalarAffineFunction{T}}, 
        ::Type{<:Union{MOI.EqualTo{T}, MOI.GreaterThan{T}, MOI.LessThan{T}}}) where T
    
    return true
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         src::MOI.ModelLike, mapping::MOIU.IndexMap,
                         f::MOI.ScalarAffineFunction, s::MOI.LessThan, copy_names::Bool)
    load_constraint(ci, dest, src, mapping, f, s, s.upper - f.constant, 'L', copy_names)
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         src::MOI.ModelLike, mapping::MOIU.IndexMap,
                         f::MOI.ScalarAffineFunction, s::MOI.GreaterThan, copy_names::Bool)
    load_constraint(ci, dest, src, mapping, f, s, s.lower - f.constant, 'G', copy_names)
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         src::MOI.ModelLike, mapping::MOIU.IndexMap,
                         f::MOI.ScalarAffineFunction, s::MOI.EqualTo, copy_names::Bool)
    load_constraint(ci, dest, src, mapping, f, s, s.value - f.constant, 'E', copy_names)
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         src::MOI.ModelLike, mapping::MOIU.IndexMap,
                         f::MOI.SingleVariable, s::MOI.ZeroOne)
    dest.varmap[mapping.varmap[f.variable]].vc_type = 'B'
    dest.varmap[mapping.varmap[f.variable]].lower_bound = 0.0
    dest.varmap[mapping.varmap[f.variable]].upper_bound = 1.0
    update_constraint_map(mapping, ci, f, s)
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         src::MOI.ModelLike, mapping::MOIU.IndexMap,
                         f::MOI.SingleVariable, s::MOI.Integer)
    dest.varmap[mapping.varmap[f.variable]].vc_type = 'I'
    update_constraint_map(mapping, ci, f, s)
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         src::MOI.ModelLike, mapping::MOIU.IndexMap,
                         f::MOI.SingleVariable, s::MOI.LessThan)
    if s.upper < dest.varmap[mapping.varmap[f.variable]].upper_bound
        dest.varmap[mapping.varmap[f.variable]].upper_bound = s.upper
        update_constraint_map(mapping, ci, f, s)
    end
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         src::MOI.ModelLike, mapping::MOIU.IndexMap,
                         f::MOI.SingleVariable, s::MOI.GreaterThan)
    if s.lower > dest.varmap[mapping.varmap[f.variable]].lower_bound
        dest.varmap[mapping.varmap[f.variable]].lower_bound = s.lower
        update_constraint_map(mapping, ci, f, s)
    end
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         src::MOI.ModelLike, mapping::MOIU.IndexMap,
                         f::MOI.SingleVariable, s::MOI.EqualTo)
    dest.varmap[mapping.varmap[f.variable]].lower_bound = s.value
    dest.varmap[mapping.varmap[f.variable]].upper_bound = s.value
    update_constraint_map(mapping, ci, f, s)
end

function update_constraint_map(mapping::MOIU.IndexMap, ci::MOI.ConstraintIndex,
                               f::MOI.AbstractFunction, s::MOI.AbstractSet)
    idx = length(mapping.conmap) + 1
    new_ci = MOI.ConstraintIndex{typeof(f),typeof(s)}(idx)
    mapping.conmap[ci] = new_ci
end

function copy_constraints(dest::ColunaModelOptimizer, src::MOI.ModelLike,
    mapping::MOIU.IndexMap, copy_names::Bool; only_singlevariable = false)
    for (F,S) in MOI.get(src, MOI.ListOfConstraints())
        if F == MOI.SingleVariable && only_singlevariable
            for ci in MOI.get(src, MOI.ListOfConstraintIndices{F,S}())
                f = MOI.get(src, MOI.ConstraintFunction(), ci)
                s = MOI.get(src, MOI.ConstraintSet(), ci)
                load_constraint(ci, dest, src, mapping, f, s)
            end
        elseif F != MOI.SingleVariable && !only_singlevariable
            for ci in MOI.get(src, MOI.ListOfConstraintIndices{F,S}())
                f = MOI.get(src, MOI.ConstraintFunction(), ci)
                s = MOI.get(src, MOI.ConstraintSet(), ci)
                load_constraint(ci, dest, src, mapping, f, s, copy_names)
            end
        end
    end
end

function create_coluna_variables(dest::ColunaModelOptimizer, src::MOI.ModelLike,
                                 mapping::MOIU.IndexMap, copy_names::Bool)
    var_index = MOI.get(src, MOI.ListOfVariableIndices())
    num_cols = MOI.get(src, MOI.NumberOfVariables())
    coluna_vars = Variable[]
    for i in 1:num_cols
        if copy_names
            name = MOI.get(src, MOI.VariableName(), var_index[i])
        else
            name = string("var_", i)
        end
        counter = dest.inner.extended_problem.counter
        # Get variable annotation
        prob_idx = MOI.get(src, VariableDantzigWolfeAnnotation(), var_index[i])
        if prob_idx <= 0
            var = MasterVar(counter, name, 0.0, 'P', 'C', 's', 'U', 1.0, -Inf, Inf)
        else
            var = SubprobVar(counter, name, 0.0, 'P', 'C', 's', 'U', 1.0, -Inf, Inf,
                             -Inf, Inf, -Inf, Inf)
        end
        push!(coluna_vars, var)
        new_idx = MOI.VariableIndex(i)
        # Update maps
        mapping.varmap[var_index[i]] = new_idx
        dest.varmap[new_idx] = var
        dest.var_probidx_map[var] = prob_idx
    end
    return coluna_vars
end

function add_variables_to_problem(dest::ColunaModelOptimizer, src::MOI.ModelLike,
                                  coluna_vars::Vector{<:Variable},
                                  mapping::MOIU.IndexMap)
    for idx in 1:length(coluna_vars)
        # Get the right problem of the variable through annotations
        prob_idx = dest.var_probidx_map[coluna_vars[idx]]
        if prob_idx <= 0
            problem = dest.inner.extended_problem.master_problem
        else
            problem = dest.inner.extended_problem.pricing_vect[prob_idx]
        end
        add_variable(problem, coluna_vars[idx])
    end
end

function find_number_of_subproblems(src::MOI.ModelLike)
    nb_subproblems = 0
    var_index = MOI.get(src, MOI.ListOfVariableIndices())
    problem_indices = BitSet()
    for i in 1:length(var_index)
        prob_idx = MOI.get(src, VariableDantzigWolfeAnnotation(), var_index[i])
        if prob_idx > 0
            push!(problem_indices, prob_idx)
        end
        if prob_idx > nb_subproblems
            nb_subproblems = prob_idx
        end
    end
    for (F,S) in MOI.get(src, MOI.ListOfConstraints())
        for ci in MOI.get(src, MOI.ListOfConstraintIndices{F,S}())
            prob_idx = MOI.get(src, ConstraintDantzigWolfeAnnotation(), ci)
            if prob_idx > 0
                push!(problem_indices, prob_idx)
            end
            if prob_idx > nb_subproblems
                nb_subproblems = prob_idx
            end
        end
    end
    if nb_subproblems != length(problem_indices)
        error("Subproblem indices are not contiguous.")
    end
    return nb_subproblems
end

function create_subproblems(dest::ColunaModelOptimizer, src::MOI.ModelLike)
    extended_problem = dest.inner.extended_problem
    prob_counter = dest.inner.prob_counter
    counter = dest.inner.extended_problem.counter
    dest.nb_subproblems = find_number_of_subproblems(src)
    for i in 1:dest.nb_subproblems
        subprob = SimpleCompactProblem(prob_counter, counter)
        push!(extended_problem.pricing_vect, subprob)
    end
end

function MOI.copy_to(dest::ColunaModelOptimizer, 
                     src::MOI.ModelLike; copy_names=true)

    # Create variables without adding to problem
    # Update the variable cost_rhs
    # Go through SingleVariable constraints and modify the variables
    # Add variables to problem
    # Go throught ScalarAffineFunction constraints

    mapping = MOIU.IndexMap()
    coluna_vars = create_coluna_variables(dest, src, mapping, copy_names)
    create_subproblems(dest, src)
    set_default_optimizers(dest)

    # Copy objective function
    obj = MOI.get(src, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    load_obj(dest, mapping, obj)
    sense = MOI.get(src, MOI.ObjectiveSense())
    return_value = MOI.set(dest, MOI.ObjectiveSense(), sense)

    copy_constraints(dest, src, mapping, copy_names; only_singlevariable = true)
    add_variables_to_problem(dest, src, coluna_vars, mapping)
    copy_constraints(dest, src, mapping, copy_names; only_singlevariable = false)

    return mapping
end

# Set functions
function set_default_optimizers(dest::ColunaModelOptimizer)
    # set coluna optimizers
    model = dest.inner
    master_problem = model.extended_problem.master_problem
    model.problemidx_optimizer_map[master_problem.prob_ref] = GLPK.Optimizer()
    for subprobidx in 1:dest.nb_subproblems
        pricingprob = model.extended_problem.pricing_vect[subprobidx]
        model.problemidx_optimizer_map[pricingprob.prob_ref] = GLPK.Optimizer()
    end
    set_model_optimizers(model)
end

function MOI.set(coluna_optimizer::ColunaModelOptimizer, object::MOI.ObjectiveSense,
                  sense::MOI.OptimizationSense)
    if sense != MOI.MinSense
        throw(MOI.CannotSetAttribute{MOI.ObjectiveSense}(MOI.ObjectiveSense, "Coluna only supports minimization sense for now."))
    end
end

function MOI.empty!(coluna_optimizer::ColunaModelOptimizer)
    coluna_optimizer.inner = ModelConstructor()
end

######################
### Get functions ####
######################

function MOI.is_empty(coluna_optimizer::ColunaModelOptimizer)
    return (coluna_optimizer.inner.prob_counter.value == 0 &&
            coluna_optimizer.inner.extended_problem.counter.value == 0)
end

function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.ObjectiveBound)
    return coluna_optimizer.inner.extended_problem.dual_inc_bound
end

function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.ObjectiveValue)
    return coluna_optimizer.inner.extended_problem.primal_inc_bound
end

function MOI.get(coluna_optimizer::ColunaModelOptimizer,
                 object::MOI.VariablePrimal, ref::MOI.VariableIndex)
    solution = coluna_optimizer.inner.extended_problem.solution.var_val_map
    var = coluna_optimizer.varmap[ref] # This gets a coluna variable
    if haskey(solution, var)
        return solution[var]
    else
        return 0.0
    end
end

function MOI.get(coluna_optimizer::ColunaModelOptimizer,
                 object::MOI.VariablePrimal, ref::Vector{MOI.VariableIndex})
    return [MOI.get(coluna_optimizer, object, ref[i]) for i in 1:length(ref)]
end

function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.ObjectiveSense)
    # MaxSense is currently not supported
    return MOI.MinSense
end
