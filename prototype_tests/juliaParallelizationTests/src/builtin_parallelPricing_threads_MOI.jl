## This file emulates the solution of a column generation iteration
## in a parallel scheme using multi-threading.
#
## Many dual vectors are generated and many processes are used in
## parallel to solve one pricing for each vector, generating columns.
#
## The used tools are the Julia built-in functions and macros related
## to multi-threading.
#
# By using multi-threading we share the memory used, which makes it
# difficult to recover the correct results of the subproblem solvers.
#
###################################################################
include("dataStructs.jl")
include("create_moi_model.jl")
include("shared_functions.jl")

function solve_pricing(pricing_solver::MOI.ModelLike, dual::DualStruct,
                       cols::Vector{Column})

    nb_solved = 0
    for col in cols
        if col.solved
            nb_solved += 1
        end
    end
    if nb_solved >= 3
        return nothing
    end

    MOI.optimize!(pricing_solver)
    vars = MOI.get(pricing_solver, MOI.ListOfVariableIndices())
    values = MOI.get(pricing_solver, MOI.VariablePrimal(), vars)
    cost = MOI.get(pricing_solver, MOI.ObjectiveValue())

    col = cols[dual.id]
    col.col_id = dual.id
    col.proc_id = Threads.threadid()
    col.col = values
    col.reduced_cost = cost
    col.solved = true
    return
end

function solve_pricing_probs_in_parallel(solvers::Vector{<:MOI.ModelLike},
                                         duals::Vector{DualStruct},
                                         cols::Vector{Column})
    # This can be seen as if we call many pricing solvers in parallel
    println("Started the distributed solutions using multi-thread.")
    # The @threads macro always syncs in the end of the for loop
    Threads.@threads for i in 1:length(duals)
        solve_pricing(solvers[i], duals[i], cols)
    end
    return
end

function cg_iteration(data::SolverData, prob_size::Int, nb_pricing_solvers::Int)

    duals = generate_duals(prob_size, nb_pricing_solvers)
    cols = [EmptyColumn() for i in 1:nb_pricing_solvers]
    solvers = [create_moi_model_with_glpk(data) for i in 1:nb_pricing_solvers]
    println(duals)
    solve_pricing_probs_in_parallel(solvers, duals, cols)
    println("Finished parallel pricing.")
    print_results(cols)
    println("\nFinished iteration of column generation.\n\n")

    for solver in solvers
        Base.finalize(solver)
    end
    return
end

function main()
    nb_vars = 4; nb_dual_vecs = 5
    data = SolverData("Data 1", rand(10, 10), nb_vars)
 
    # Imagine you are in a for loop of the column generation
    cg_iteration(data, nb_vars, nb_dual_vecs)
    # Continue the loop

    return
end

main()

