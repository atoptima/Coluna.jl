struct DivideOutput{N} <: Branching.AbstractDivideOutput
    children::Vector{N}
    optstate::Union{Nothing,OptimizationState}
end

Branching.get_children(output::DivideOutput) = output.children
Branching.get_opt_state(output::DivideOutput) = output.optstate

function get_extended_sol(eform, opt_state)
    return get_best_lp_primal_sol(opt_state)
end

function get_original_sol(reform, opt_state)
    extended_sol = get_best_lp_primal_sol(opt_state)
    master = getmaster(reform)
    original_sol = nothing
    if !isnothing(extended_sol)
        original_sol = if MathProg.projection_is_possible(master)
            proj_cols_on_rep(extended_sol)
        else
            get_best_lp_primal_sol(opt_state) # it means original_sol equals extended_sol(requires discussion)
        end
    end
    return original_sol
end

function Branching.projection_on_master_is_possible(::Branching.AbstractDivideContext, reform)
    return MathProg.projection_is_possible(getmaster(reform))
end

function run!(algo::AlgoAPI.AbstractDivideAlgorithm, env::Env, reform::Reformulation, input::Branching.AbstractDivideInput)
    ctx = new_context(branching_context_type(algo), algo, reform)

    parent = Branching.get_parent(input)
    optstate = TreeSearch.get_opt_state(parent)
    nodestatus = getterminationstatus(optstate)

    # We don't run the branching algorithm if the node is already conquered
    if nodestatus == OPTIMAL || nodestatus == INFEASIBLE || ip_gap_closed(optstate)             
        #println("Node is already conquered. No children will be generated.")
        return DivideOutput(SbNode[], optstate)
    end

    extended_sol = get_extended_sol(reform, TreeSearch.get_opt_state(parent))
    original_sol = get_original_sol(reform, TreeSearch.get_opt_state(parent))

    return Branching.run_branching!(ctx, env, reform, input, extended_sol, original_sol)
end