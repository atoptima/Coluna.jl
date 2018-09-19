## This file emulates the solution of a column generation iteration
## in a parallel scheme.
#
## Many dual vectors are generated and many processes are used in
## parallel to solve one pricing for each vector, generating columns.
#
## The used tools are the Julia built-in functions and macros
## available in package 'Distributed'.
#
# In this example we use a real MOI solver, which is created directly
# in the worker processes as a constant global variable, no waiter
# function is needed.
#
###################################################################
using Distributed
addprocs(5)
include("dataStructs.jl")
include("create_moi_model.jl")
include("shared_functions.jl")

@everywhere function solve_pricing(dual::DualStruct,
                                   results::RemoteChannel,
                                   messages::RemoteChannel)

    println("Process ", myid(), " is solving the pricing for dual vector number ",
            dual.id, ".")

    t1 = time_ns()
    sleep(2.0 + rand() * 2.0) # Do first processing
    # Arrive to a checkpoint
    # Check if needs to stop
    if isready(messages)
        message = take!(messages)
        if message == "stop"
            println("Process ", myid(), " was told to exit. No columns were generated.")
            return
        end
    end
    sleep(1.0 + rand())

    println("Solving MOI model...")
    pricing_solver = solver_container[1]
    MOI.optimize!(pricing_solver)
    println("Done!")
    vars = MOI.get(pricing_solver, MOI.ListOfVariableIndices())
    values = MOI.get(pricing_solver, MOI.VariablePrimal(), vars)
    cost = MOI.get(pricing_solver, MOI.ObjectiveValue())
    println("Solution from subproblem: ", values)

    col = Column(dual.id, myid(), values, cost, true)
    println("Process ", myid(), " generated column ", col.col_id, " in ", (time_ns()-t1)/1e9, " seconds.")
    put!(results, col)
    put!(messages, "done")
    return
end

function solve_pricing_probs_in_parallel(duals::Vector{DualStruct},
                                         results_channel::RemoteChannel,
                                         messages_channel_vec::Vector{RemoteChannel})
    # This can be seen as if we call many pricing solvers in parallel
    println("Started the distributed solutions using process ", myid(), ".")
    # By adding @sync, the master process waits for all the workers to finish
    @distributed for i in 1:length(duals)
        solve_pricing(duals[i], results_channel, messages_channel_vec[i])
    end
    return
end

function cg_iteration(prob_size::Int, nb_pricing_solvers::Int)

    ## Create channels needed fo rocmmunication between processes
    messages_channel_vec = RemoteChannel[]
    for i in 1:nb_pricing_solvers
        remote_chnl = RemoteChannel(()->Channel{String}(10))
        push!(messages_channel_vec, remote_chnl)
    end
    results_channel = RemoteChannel(()->Channel{Column}(nb_pricing_solvers))

    duals = generate_duals(prob_size, nb_pricing_solvers)
    println(duals)
    solve_pricing_probs_in_parallel(duals, results_channel, messages_channel_vec)
    cols = get_results_from_channel(results_channel, messages_channel_vec, nb_pricing_solvers)
    sleep(10)
    print_results(cols)
    println("\nFinished iteration of column generation.\n\n")
    return
end

function define_const_pricing_in_workers(data::SolverData)
    @sync for worker_id in workers()
        @everywhere [worker_id] const solver_container = Vector{MOI.ModelLike}()
        remotecall(create_and_put_solver_to_container, worker_id, data, :solver_container)
    end    
    return
end

function main()
    println("Example: Solving parallel pricing using:")
    println("Built-in functions, MOI solver as a constant in the workers.")

    nb_vars = 4; nb_dual_vecs = 10

    data = SolverData("Data 1", rand(10, 10), nb_vars)
    define_const_pricing_in_workers(data)

    # Imagine you are in a for loop of the column generation
    cg_iteration(nb_vars, nb_dual_vecs)
    # Continue the loop
    return
end

main()
