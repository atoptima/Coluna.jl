export ColunaModelOptimizer

mutable struct ColunaModelOptimizer <: MOI.AbstractOptimizer
    inner::Model
    map::Dict{MOI.VariableIndex,Variable}
    function ColunaModelOptimizer()
        coluna_model = ModelConstructor()
        _map = Dict{MOI.VariableIndex,Variable}()
        new(coluna_model, _map)
    end
end

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
                         f::MOI.ScalarAffineFunction, rhs::Float64, sense::Char)
    ## Get the right problem id using MOI get function
    problem = get_problem_from_constraint(dest, ci)
    name = string("constraint_", mapping.conmap[ci].value)
    constr = MasterConstr(problem.counter, name, rhs, sense, 'M', 's')
    add_constraint(problem, constr)
    add_memberships(constr, coluna_vars, problem, f, mapping)
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.ScalarAffineFunction, s::MOI.LessThan)
    load_constraint(ci, dest, mapping, coluna_vars, f, s.upper - f.constant, 'L')
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.ScalarAffineFunction, s::MOI.GreaterThan)
    load_constraint(ci, dest, mapping, coluna_vars, f, s.lower - f.constant, 'G')
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.ScalarAffineFunction, s::MOI.EqualTo)
    load_constraint(ci, dest, mapping, coluna_vars, f, s.value - f.constant, 'E')
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.ScalarAffineFunction, s::MOI.Interval)
    load_constraint(ci, dest, mapping, coluna_vars, f, s.upper - f.constant, 'L')
    load_constraint(ci, dest, mapping, coluna_vars, f, s.lower - f.constant, 'G')
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.SingleVariable, s::MOI.ZeroOne)
    coluna_vars[mapping.varmap[f.variable].value].vc_type = 'I'
    coluna_vars[mapping.varmap[f.variable].value].lower_bound = 0.0
    coluna_vars[mapping.varmap[f.variable].value].upper_bound = 1.0
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.SingleVariable, s::MOI.Integer)
    coluna_vars[mapping.varmap[f.variable].value].vc_type = 'I'
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.SingleVariable, s::MOI.LessThan)
    if s.upper < coluna_vars[mapping.varmap[f.variable].value].upper_bound
        coluna_vars[mapping.varmap[f.variable].value].upper_bound = s.upper
    end
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.SingleVariable, s::MOI.GreaterThan)
    if s.lower > coluna_vars[mapping.varmap[f.variable].value].lower_bound
        coluna_vars[mapping.varmap[f.variable].value].lower_bound = s.lower
    end
end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.SingleVariable, s::MOI.EqualTo)
    coluna_vars[mapping.varmap[f.variable].value].lower_bound = s.value
    coluna_vars[mapping.varmap[f.variable].value].upper_bound = s.value
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
        dest.map[new_idx] = var
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

function build_constraint_mapping(mapping::MOIU.IndexMap, src::MOI.ModelLike)
    list_of_constraints = MOI.get(src, MOI.ListOfConstraints())
    num_rows = 0
    for (F,S) in list_of_constraints
        ci = MOI.get(src, MOI.ListOfConstraintIndices{F,S}())
        if F != MOI.SingleVariable
            ## Update conmap for (F,S) for F != MOI.SingleVariable
            ## Single variables are treated by bounds inside the varconstr,
            ## so no need to add a row
            for i in 1:length(ci)
                mapping.conmap[ci[i]] = MOI.ConstraintIndex{F,S}(num_rows + i)
            end
            num_rows += MOI.get(src, MOI.NumberOfConstraints{F,S}())
        end
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
    build_constraint_mapping(mapping, src)
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
    var = coluna_optimizer.map[ref] ## This gets a coluna variable
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
