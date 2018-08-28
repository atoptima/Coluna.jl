export ColunaModelOptimizer

mutable struct ColunaModelOptimizer <: MOI.AbstractOptimizer
    inner::Model
    varmap::Dict{MOI.VariableIndex,Variable}
    ci_probidx_map::Dict{MOI.ConstraintIndex,Int}
    vi_probidx_map::Dict{MOI.VariableIndex,Int}
    function ColunaModelOptimizer()
        coluna_model = ModelConstructor()
        _varmap = Dict{MOI.VariableIndex,Variable}()
        _ci_probidx_map = Dict{MOI.ConstraintIndex,Int}()
        _vi_probidx_map = Dict{MOI.VariableIndex,Int}()
        new(coluna_model, _varmap, _ci_probidx_map, _vi_probidx_map)
    end
end

## Annotations needed for column generation
struct ConstraintProblemIndex <: MOI.AbstractConstraintAttribute end

function MOI.set!(dest::ColunaModelOptimizer, attribute::ConstraintProblemIndex,
                  ci::MOI.ConstraintIndex, value::Int)
    dest.ci_probidx_map[ci] = value
end

function MOI.get(dest::ColunaModelOptimizer, attribute::ConstraintProblemIndex,
                 ci::MOI.ConstraintIndex)
    return dest.ci_probidx_map[ci]
end

struct VariableProblemIndex <: MOI.AbstractVariableAttribute end

function MOI.set!(dest::ColunaModelOptimizer, attribute::VariableProblemIndex,
                  vi::MOI.VariableIndex, value::Int)
    dest.vi_probidx_map[vi] = value
end

function MOI.get(dest::ColunaModelOptimizer, attribute::VariableProblemIndex,
                 vi::MOI.VariableIndex)
    return dest.vi_probidx_map[vi]
end
###

function MOI.optimize!(coluna_optimizer::ColunaModelOptimizer)
    solve(coluna_optimizer.inner)
end

function load_obj(dest::ColunaModelOptimizer, coluna_vars::Vector{<:Variable},
                  mapping::MOIU.IndexMap, f::MOI.ScalarAffineFunction)
    # We need to increment values of cost_rhs with += to handle cases like $x_1 + x_2 + x_1$
    # This is safe becasue the variables are initialized with a 0.0 cost_rhs
    for term in f.terms
        coluna_vars[mapping.varmap[term.variable_index].value].cost_rhs += term.coefficient
    end
end

function add_memberships(constr::Constraint, coluna_vars::Vector{MasterVar},
                         problem::Problem, f::MOI.ScalarAffineFunction,
                         mapping::MOIU.IndexMap)
    for term in f.terms
        add_membership(problem, coluna_vars[mapping.varmap[term.variable_index].value],
                       constr, term.coefficient)
    end
end

function get_problem_from_constraint(dest::ColunaModelOptimizer, ci::MOI.ConstraintIndex)
    problem_id = 0 ## TODO:: Implement this with MOI get function
    if problem_id == 0
        problem = dest.inner.extended_problem.master_problem
    else
        problem = dest.inner.extended_problem.pricing_vect[problem_id]
    end
    return problem
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.ScalarAffineFunction, s::MOI.AbstractSet,
                         rhs::Float64, sense::Char)
    ## Get the right problem id using MOI get function
    problem = get_problem_from_constraint(dest, ci)
    name = string("constraint_", ci.value)
    constr = MasterConstr(problem.counter, name, rhs, sense, 'M', 's')
    add_constraint(problem, constr)
    add_memberships(constr, coluna_vars, problem, f, mapping)
    update_constraint_map(mapping, ci, f, s)
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.ScalarAffineFunction, s::MOI.LessThan)
    load_constraint(ci, dest, mapping, coluna_vars, f, s, s.upper - f.constant, 'L')
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.ScalarAffineFunction, s::MOI.GreaterThan)
    load_constraint(ci, dest, mapping, coluna_vars, f, s, s.lower - f.constant, 'G')
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.ScalarAffineFunction, s::MOI.EqualTo)
    load_constraint(ci, dest, mapping, coluna_vars, f, s, s.value - f.constant, 'E')
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.ScalarAffineFunction, s::MOI.Interval)
    load_constraint(ci, dest, mapping, coluna_vars, f, s, s.upper - f.constant, 'L')
    load_constraint(ci, dest, mapping, coluna_vars, f, s, s.lower - f.constant, 'G')
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.SingleVariable, s::MOI.ZeroOne)
    coluna_vars[mapping.varmap[f.variable].value].vc_type = 'I'
    coluna_vars[mapping.varmap[f.variable].value].lower_bound = 0.0
    coluna_vars[mapping.varmap[f.variable].value].upper_bound = 1.0
    update_constraint_map(mapping, ci, f, s)
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.SingleVariable, s::MOI.Integer)
    coluna_vars[mapping.varmap[f.variable].value].vc_type = 'I'
    update_constraint_map(mapping, ci, f, s)
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.SingleVariable, s::MOI.LessThan)
    if s.upper < coluna_vars[mapping.varmap[f.variable].value].upper_bound
        coluna_vars[mapping.varmap[f.variable].value].upper_bound = s.upper
        update_constraint_map(mapping, ci, f, s)
    end
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.SingleVariable, s::MOI.GreaterThan)
    if s.lower > coluna_vars[mapping.varmap[f.variable].value].lower_bound
        coluna_vars[mapping.varmap[f.variable].value].lower_bound = s.lower
        update_constraint_map(mapping, ci, f, s)
    end
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.SingleVariable, s::MOI.EqualTo)
    coluna_vars[mapping.varmap[f.variable].value].lower_bound = s.value
    coluna_vars[mapping.varmap[f.variable].value].upper_bound = s.value
    update_constraint_map(mapping, ci, f, s)
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.SingleVariable, s::MOI.Interval)
    if s.lower > coluna_vars[mapping.varmap[f.variable].value].lower_bound
        coluna_vars[mapping.varmap[f.variable].value].lower_bound = s.lower
    end
    if s.upper < coluna_vars[mapping.varmap[f.variable].value].upper_bound
        coluna_vars[mapping.varmap[f.variable].value].upper_bound = s.upper
    end
    update_constraint_map(mapping, ci, f, s)
end

function update_constraint_map(mapping::MOIU.IndexMap, ci::MOI.ConstraintIndex,
                               f::MOI.AbstractFunction, s::MOI.AbstractSet)
    idx = length(mapping.conmap) + 1
    new_ci = MOI.ConstraintIndex{typeof(f),typeof(s)}(idx)
    mapping.conmap[ci] = new_ci
end

function copy_constraints(dest::ColunaModelOptimizer, src::MOI.ModelLike,
    mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar}, only_singlevariable::Bool)
    for (F,S) in MOI.get(src, MOI.ListOfConstraints())
        if (F == MOI.SingleVariable && only_singlevariable
            || F != MOI.SingleVariable && !only_singlevariable)
            for ci in MOI.get(src, MOI.ListOfConstraintIndices{F,S}())
                f = MOI.get(src, MOI.ConstraintFunction(), ci)
                s = MOI.get(src,  MOI.ConstraintSet(), ci)
                load_constraint(ci, dest, mapping, coluna_vars, f, s)
            end
        end
    end
end

function create_coluna_variables(dest::ColunaModelOptimizer, num_cols::Int,
                                 var_index::Vector{MOI.VariableIndex},
                                 mapping::MOIU.IndexMap, copynames::Bool)
    coluna_vars = MasterVar[]
    for i in 1:num_cols
        name = string("var(", i, ")") ## Update to support copynames
        ## get whatever attribute is needed to create the variable
        ## i.e. MOI.get(src, var_index[i], Coluna.ColGenDecompositionAttribute)
        ## Create the right type of Coluna variable with the correct arguments
        counter = dest.inner.extended_problem.counter
        var = MasterVar(counter, name, 0.0, 'P', 'I', 's', 'U', 1.0, -Inf, Inf)
        push!(coluna_vars, var)
        new_idx = MOI.VariableIndex(i)
        # Update map
        mapping.varmap[var_index[i]] = new_idx
        dest.varmap[new_idx] = var
    end
    return coluna_vars
end

function add_variables_to_problem(dest::ColunaModelOptimizer,
                                  coluna_vars::Vector{<:Variable},
                                  mapping::MOIU.IndexMap)
    for idx in 1:length(coluna_vars)
        ### Get the right problem of the variable through attributes
        problem = dest.inner.extended_problem.master_problem
        add_variable(problem, coluna_vars[idx])
    end
end

function MOI.copy!(dest::ColunaModelOptimizer, src::MOI.ModelLike; copynames=false)
    if copynames
        error("Copynames not supported yet")
    end

    ## Create variables without adding to problem
    ## Update the variable cost_rhs
    ## Go through SingleVariable constraints and modify the variables
    ## Add variables to problem
    ## Go throught ScalarAffineFunction constraints

    mapping = MOIU.IndexMap()
    var_index = MOI.get(src, MOI.ListOfVariableIndices())
    num_cols = MOI.get(src, MOI.NumberOfVariables())
    coluna_vars = create_coluna_variables(dest, num_cols, var_index, mapping, copynames)
    ## Copy objective function
    objF = MOI.get(src, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    load_obj(dest, coluna_vars, mapping, objF)
    sense = MOI.get(src, MOI.ObjectiveSense())
    MOI.set!(dest, MOI.ObjectiveSense(), sense)
    ##########################
    copy_constraints(dest, src, mapping, coluna_vars, true)
    add_variables_to_problem(dest, coluna_vars, mapping)
    copy_constraints(dest, src, mapping, coluna_vars, false)

    return mapping
end

function MOI.set!(coluna_optimizer::ColunaModelOptimizer, object::MOI.ObjectiveSense,
                  sense::MOI.OptimizationSense)
    if sense != MOI.MinSense
        error("Minimization is the only supported sense for now.")
    end
end

function MOI.empty!(coluna_optimizer::ColunaModelOptimizer)
    coluna_optimizer.inner = ModelConstructor()
end

# ## Get functions
MOI.canget(coluna_optimizer::ColunaModelOptimizer,
           object::Union{MOI.ObjectiveSense, MOI.ObjectiveValue, MOI.ObjectiveBound}) = true

MOI.canget(coluna_optimizer::ColunaModelOptimizer, object::MOI.VariablePrimal, indexTypeOrObject::Type{MOI.VariableIndex}) = true

function MOI.isempty(coluna_optimizer::ColunaModelOptimizer)
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
    var = coluna_optimizer.varmap[ref] ## This gets a coluna variable
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
