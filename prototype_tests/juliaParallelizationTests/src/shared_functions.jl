
function generate_duals(prob_size::Int, nb_pricing_solvers::Int)
    duals = Vector{DualStruct}()
    for i in 1:nb_pricing_solvers
        push!(duals, DualStruct(i, rand(prob_size)))
    end
    return duals
end

function print_results(cols::Vector{Column})
    println("Results: ")
    for col in cols
        println("Process/thread ", col.proc_id, " generated column ", col.col_id, ": ",
                col.col, ". With reduced cost: ", col.reduced_cost, ".")
    end
end

function stop_solvers(messages_channel_vec::Vector{RemoteChannel})
    for channel in messages_channel_vec
        put!(channel, "stop") # telling to stop
    end
end

function get_results_from_channel(results_channel::RemoteChannel,
                                  messages_channel_vec::Vector{RemoteChannel},
                                  nb_pricing_solvers::Int)
    results = Vector{Column}()
    while true
        col = take!(results_channel)
        push!(results, col)
        ## work on current pool of columns
        println("Got column ", col.col_id)
        if length(results) == 3 ## condition to exit
            break
        end
    end
    println("Already got enought columns, telling active solvers to exit")
    stop_solvers(messages_channel_vec)
    return results
end

