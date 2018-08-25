export ColunaModelOptimizer


mutable struct ColunaModelOptimizer <: MOI.AbstractOptimizer
    inner::Model
    function ColunaModelOptimizer()
        coluna_model = ModelConstructor()
        new(coluna_model)
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
        add_membership(coluna_vars[mapping.varmap[term.variable_index].value],
                       constr, problem, term.coefficient)
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
                         f::MOI.ScalarAffineFunction, s::MOI.LessThan)

    ## Get the right problem id using MOI get function
    problem = get_problem_from_constraint(dest, ci)

    name = string("constraint_", mapping.conmap[ci].value)
    constr = MasterConstr(problem.counter, name,
                          s.upper - f.constant, 'L', 'M', 's')

    add_constraint(problem, constr)
    add_memberships(constr, coluna_vars, problem, f, mapping)

end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.ScalarAffineFunction, s::MOI.GreaterThan)

    ## Get the right problem id using MOI get function
    problem = get_problem_from_constraint(dest, ci)

    name = string("constraint_", mapping.conmap[ci].value)
    constr = MasterConstr(problem.counter, name,
                          s.lower - f.constant, 'G', 'M', 's')

    add_constraint(problem, constr)
    add_memberships(constr, coluna_vars, problem, f, mapping)

end

function load_constraint(ci::MOI.ConstraintIndex, dest::ColunaModelOptimizer,
                         mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar},
                         f::MOI.ScalarAffineFunction, s::MOI.EqualTo)

    ## Get the right problem id using MOI get function
    problem = get_problem_from_constraint(dest, ci)

    name = string("constraint_", mapping.conmap[ci].value)
    constr = MasterConstr(problem.counter, name,
                          s.value - f.constant, 'E', 'M', 's')

    add_constraint(problem, constr)
    add_memberships(constr, coluna_vars, problem, f, mapping)

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
    mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar})
    for (F,S) in MOI.get(src, MOI.ListOfConstraints())
        if F != MOI.SingleVariable
            for ci in MOI.get(src, MOI.ListOfConstraintIndices{F,S}())
                f = MOI.get(src, MOI.ConstraintFunction(), ci)
                s = MOI.get(src,  MOI.ConstraintSet(), ci)
                load_constraint(ci, dest, mapping, coluna_vars, f, s)
            end
        end
    end
end

function copy_singleVariable_constraints(dest::ColunaModelOptimizer, src::MOI.ModelLike,
    mapping::MOIU.IndexMap, coluna_vars::Vector{MasterVar})
    for (F,S) in MOI.get(src, MOI.ListOfConstraints())
        if F == MOI.SingleVariable
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
        mapping.varmap[var_index[i]] = MOI.VariableIndex(i)
    end
    return coluna_vars
end

function add_variables_to_problem(dest::ColunaModelOptimizer, coluna_vars::Vector{<:Variable})
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
        # if !(MOI.supportsconstraint(dest, F, S))
        #     return MOI.CopyResult(MOI.CopyUnsupportedConstraint,
        #     "Cbc MOI Interface does not support constraints of type " * (F,S) * ".", nothing)
        # end

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



"""
    function copy!(coluna_optimizer, user_optimizer; copynames=false)

    ## Create variables without adding to problem
    ## Update the variable cost_rhs
    ## Go through SingleVariable constraints and modify the variables
    ## Add variables to problem
    ## Go throught ScalarAffineFunction constraints

"""
function MOI.copy!(dest::ColunaModelOptimizer, src::MOI.ModelLike; copynames=false)
    if copynames
        error("Copynames not supported yet")
    end


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
    copy_singleVariable_constraints(dest, src, mapping, coluna_vars)
    add_variables_to_problem(dest, coluna_vars)
    copy_constraints(dest, src, mapping, coluna_vars)


    # println("Coluna variables:")
    # for var in coluna_vars
    #     println("var: ", var.name, ", ", var.vc_type, ",  ", var.lower_bound, ", ", var.upper_bound, ", ", var.cost_rhs)
    # end

    # println("var manager: ", length(dest.inner.extended_problem.master_problem.var_manager.active_static_list))
    # for var in dest.inner.extended_problem.master_problem.var_manager.active_static_list
    #     println("var: ", var.name, ", ", var.vc_type, ",  ", var.lower_bound, ", ", var.upper_bound, ", ", var.cost_rhs)
    # end

    # readline()
    return mapping

end




# ## canadd, canset, canget functions

# function MOI.canaddvariable(coluna_model_optimizer::ColunaModelOptimizer)
#     return false
# end

# ## supports constraints


# MOI.supportsconstraint(::ColunaModelOptimizer, ::Type{<:Union{MOI.ScalarAffineFunction{Float64}, MOI.SingleVariable}},
# ::Type{<:Union{MOI.EqualTo{Float64}, MOI.Interval{Float64}, MOI.LessThan{Float64},
# MOI.GreaterThan{Float64}, MOI.ZeroOne, MOI.Integer}}) = true

# MOI.supports(coluna_optimizer::ColunaModelOptimizer, object::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}) = true

# ## Set functions

# function MOI.write(coluna_optimizer::ColunaModelOptimizer, filename::String)
#     if !endswith("filename", "mps")
#         error("ColunaModelOptimizer only supports writing .mps files")
#     else
#         writeMps(coluna_optimizer.inner, filename)
#     end
# end

function MOI.set!(coluna_optimizer::ColunaModelOptimizer, object::MOI.ObjectiveSense,
                  sense::MOI.OptimizationSense)
    if sense != MOI.MinSense
        error("Minimization is the only supported sense for now.")
    end
end


# empty!
function MOI.empty!(coluna_optimizer::ColunaModelOptimizer)
    coluna_optimizer.inner = ModelConstructor()
end



# ## Get functions


# function MOI.canget(coluna_optimizer::ColunaModelOptimizer, object::MOI.PrimalStatus)
#     if object.N != 1
#         return false
#     end
#     return MOI.get(coluna_optimizer, MOI.ResultCount()) == 1
# end


# MOI.canget(coluna_optimizer::ColunaModelOptimizer, object::Union{MOI.NodeCount, MOI.ResultCount,
# MOI.TerminationStatus, MOI.ObjectiveSense, MOI.ObjectiveValue, MOI.ObjectiveBound, MOI.NumberOfVariables}) = true

# MOI.canget(coluna_optimizer::ColunaModelOptimizer, object::MOI.VariablePrimal, indexTypeOrObject::Type{MOI.VariableIndex}) = true


function MOI.isempty(coluna_optimizer::ColunaModelOptimizer)
    return (coluna_optimizer.inner.prob_counter.value == 0 &&
            coluna_optimizer.inner.extended_problem.counter.value == 0)
end


function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.ObjectiveBound)
    return coluna_optimizer.inner.extended_problem.dual_inc_bound
end

# function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.NodeCount)
# end

function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.ObjectiveValue)
    return coluna_optimizer.inner.extended_problem.primal_inc_bound
end

# function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.VariablePrimal, ref::MOI.VariableIndex)
#     variablePrimals = CbcCI.getColSolution(coluna_optimizer.inner)
#     return variablePrimals[ref.value]
# end

# function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.VariablePrimal, ref::Vector{MOI.VariableIndex})
#     variablePrimals = CbcCI.getColSolution(coluna_optimizer.inner)
#     return [variablePrimals[vi.value] for vi in ref]
# end


# function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.ResultCount)
#     if (isProvenInfeasible(coluna_optimizer.inner) || isContinuousUnbounded(coluna_optimizer.inner)
#         || isAbandoned(coluna_optimizer.inner) || CbcCI.getObjValue(coluna_optimizer.inner) >= 1e300)
#         return 0
#     end
#     return 1
# end


# function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.ObjectiveSense)
#     CbcCI.getObjSense(coluna_optimizer.inner) == 1 && return MOI.MinSense
#     CbcCI.getObjSense(coluna_optimizer.inner) == -1 && return MOI.MaxSense
# end



# function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.TerminationStatus)

#     if isProvenInfeasible(coluna_optimizer.inner)
#         return MOI.InfeasibleNoResult
#     elseif isContinuousUnbounded(coluna_optimizer.inner)
#         return MOI.InfeasibleOrUnbounded
#     elseif isNodeLimitReached(coluna_optimizer.inner)
#         return MOI.NodeLimit
#     elseif isSecondsLimitReached(coluna_optimizer.inner)
#         return MOI.TimeLimit
#     elseif isSolutionLimitReached(coluna_optimizer.inner)
#         return MOI.SolutionLimit
#     elseif (isProvenOptimal(coluna_optimizer.inner) || isInitialSolveProvenOptimal(coluna_optimizer.inner)
#         || MOI.get(coluna_optimizer, MOI.ResultCount()) == 1)
#         return MOI.Success
#     elseif isAbandoned(coluna_optimizer.inner)
#         return MOI.Interrupted
#     else
#         error("Internal error: Unrecognized solution status")
#     end

# end

# function MOI.get(coluna_optimizer::ColunaModelOptimizer, object::MOI.PrimalStatus)
#     if isProvenOptimal(coluna_optimizer.inner) || isInitialSolveProvenOptimal(coluna_optimizer.inner)
#         return MOI.FeasiblePoint
#     elseif isProvenInfeasible(coluna_optimizer.inner)
#         return MOI.InfeasiblePoint
#     end
# end
