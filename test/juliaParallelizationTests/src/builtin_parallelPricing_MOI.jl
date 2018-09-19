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
# in the worker processes, who execute a waiter function to wait fot
# the master commands.
#
###################################################################
using Distributed
addprocs(3)
include("dataStructs.jl")
include("create_moi_model.jl")
include("shared_functions.jl")

@everywhere function solve_pricing(pricing_solver::MOI.ModelLike, dual::DualStruct,
                                   results::RemoteChannel,
                                   messages::RemoteChannel)
    println("Process ", myid(), " is solving the pricing for dual vector number ",
            dual.id, ".")

    sleep(4.0) # Do first part of processing

    if isready(messages) # Check if needs to stop
        message = take!(messages)
        if message == "stop"
            println("Process ", myid(), " was told to exit. No columns were generated.")
            return nothing
        end
    end
    sleep(2.0) # Do second part of processing

    println("Solving MOI model...")
    MOI.optimize!(pricing_solver)
    println("Done!")
    vars = MOI.get(pricing_solver, MOI.ListOfVariableIndices())
    values = MOI.get(pricing_solver, MOI.VariablePrimal(), vars)
    println("Solution from subproblem: ", values)

    if isready(messages)
        message = take!(messages)
        if message == "stop"
            println("I was told to exit, but too late, when I had already finished my processing.")
        end
    end

    col = Column(dual.id, myid(), rand(Bool, length(dual.duals_vec)), rand()-0.5, true)
    println("Process ", myid(), " generated column ", col.col_id, ".")
    put!(results, col)
    return nothing
end

@everywhere function waiter_function(data::SolverData,
                                     messages_to_waiter::RemoteChannel,
                                     messages_to_solver::RemoteChannel,
                                     messages_to_master::RemoteChannel,
                                     results_channel::RemoteChannel,
                                     duals_channel::RemoteChannel)

    pricing_solver = create_moi_model_with_glpk(data)

    while true
        println("Waiting...")
        message = take!(messages_to_waiter)
        if message == "stop waiting"
            println("I was told to stop waiting.")
            put!(messages_to_master, "No status")
            return "No output"
        elseif message == "solve pricing"
            println("I was told to solve the pricing problem")
            duals = take!(duals_channel)
            solve_pricing(pricing_solver, duals,
                          results_channel, messages_to_solver)
        elseif message == "solve something else"
            println("I was told to solve something else")
        else
            error("Unknown message ", message)
        end
    end

end

function solve_pricing_probs_in_parallel(duals::Vector{DualStruct},
                                         messages_struct::Messages)

    # This can be seen as if we call many pricing solvers in parallel
    println("Started to solve in parallel.")
    cur_proc = 2
    for i in 1:length(duals)
        println("Telling waiter in proc ", cur_proc, " to solve pricing.")
        put!(messages_struct.duals_channels[cur_proc-1], duals[i])
        put!(messages_struct.messages_to_waiter[cur_proc-1], "solve pricing")
        cur_proc += 1
        if cur_proc == nprocs() + 1
            cur_proc = 2
        end
    end

end

function cg_iteration(prob_size::Int, nb_dual_vecs::Int, messages_struct::Messages)

    duals = generate_duals(prob_size, nb_dual_vecs)
    solve_pricing_probs_in_parallel(duals, messages_struct)
    cols = get_results_from_channel(messages_struct.results_channel, messages_struct.messages_to_solver, nb_dual_vecs)
    sleep(10)
    print_results(cols)
    println("\nFinished iteration of column generation.\n\n")

    return nothing
end

function setup_workers(data::SolverData, nb_dual_vecs::Int)
    # This creates the channels used to send and receive messages to/form workers
    messages_to_waiter = RemoteChannel[]
    messages_to_solver = RemoteChannel[]
    duals_channels = RemoteChannel[]
    for proc in workers()
        remote_chnl = RemoteChannel(()->Channel{String}(10))
        push!(messages_to_waiter, remote_chnl)
        remote_chnl = RemoteChannel(()->Channel{String}(10))
        push!(messages_to_solver, remote_chnl)
        # Channel used to send the dual vectors
        remote_chnl = RemoteChannel(()->Channel{DualStruct}(10))
        push!(duals_channels, remote_chnl)
    end
    messages_from_workers = RemoteChannel(()->Channel{String}(10))

    # Channel to get the pricing results from the workers
    results_channel = RemoteChannel(()->Channel{Column}(nb_dual_vecs))

    # Run a waiter function in each process with all the channels
    # The waiters create the MOI solvers
    for proc in workers()
        remotecall(waiter_function, proc, data, messages_to_waiter[proc-1],
                   messages_to_solver[proc-1], messages_from_workers,
                   results_channel, duals_channels[proc-1])
    end

    messages_struct = Messages(messages_to_waiter,
                               messages_to_solver,
                               messages_from_workers,
                               results_channel,
                               duals_channels)
    return messages_struct
end

function main()
    println("Example: Solving parallel pricing using:")
    println("Built-in functions, MOI solver and a waiter function in the workers.")

    nb_vars = 3; nb_dual_vecs = 5

    # Get data
    data = SolverData("Data 1", rand(10, 10), nb_vars)
    messages_struct = setup_workers(data, nb_dual_vecs)

    # Imagine you are in a for loop of the column generation
    cg_iteration(nb_vars, nb_dual_vecs, messages_struct)
    # Continue the loop

end

main()
