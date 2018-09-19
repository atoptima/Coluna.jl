## This file emulates the solution of a column generation iteration
## in a parallel scheme.
#
## Many dual vectors are generated and many processes are used in
## parallel to solve one pricing for each vector, generating columns.
#
## The used tools are the Julia built-in functions and macros
## available in package 'Distributed'.
#
# In this example we do not use a real MOI solver because generally
# the undelying solvers are written in C++, and we cannot transfer
# C pointers between the processes because they get lost.
#
###################################################################
using Distributed
addprocs(2)
include("dataStructs.jl")
include("create_moi_model.jl")
include("shared_functions.jl")

@everywhere function solve_pricing(dual::DualStruct, results::RemoteChannel,
                                   messages::RemoteChannel)

    println("Process ", myid(), " is solving the pricing for dual vector number ",
            dual.id, ".")

    sleep(4.0) # Do first processing
    # Arrive to a checkpoint
    # Check if needs to stop
    if isready(messages)
        message = take!(messages)
        if message == "stop"
            println("Process ", myid(), " was told to exit. No columns were generated.")
            return nothing
        end
    end
    sleep(2.0)

    col = Column(dual.id, myid(), rand(Bool, length(dual.duals_vec)), rand()-0.5, true)
    println("Process ", myid(), " generated column ", col.col_id, ".")
    put!(results, col)
    put!(messages, "done")
    return nothing
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
    println("Finished dispatching")
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

    return nothing
end

function main()
    println("Example: Solving parallel pricing using:")
    println("Built-in functions, no MOI solver.")
    nb_vars = 4; nb_dual_vecs = 5

    # Imagine the pricing solver is already created

    # Imagine you are in a for loop of the column generation
    cg_iteration(nb_vars, nb_dual_vecs)
    # Continue the loop

end

main()
