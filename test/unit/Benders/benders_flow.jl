#################### tests with flags ####################

struct TestBendersMaster

end

struct TestBendersSubproblem

end

mutable struct TestBendersMasterRes ## mock of a master opt. result
    infeasible_master::Bool  
    unbounded_master::Bool
    is_certificate::Bool
end

function Coluna.Benders.is_unbounded(master_res::TestBendersMasterRes)
    return master_res.unbounded_master
end

function Coluna.Benders.is_infeasible(master_res::TestBendersMasterRes)
    return master_res.infeasible_master
end

function Coluna.Benders.is_certificate(master_res::TestBendersMasterRes)
    return master_res.is_certificate
end

function Coluna.Benders.get_primal_sol(master_res::TestBendersMasterRes)
    return nothing
end

function Coluna.Benders.get_obj_val(sep_res::TestBendersMasterRes)
    return 0.0
end


struct TestBendersSepRes ## mock of a sep. problem opt. result
    infeasible_sp::Bool 
    unbounded_sp::Bool
end


function Coluna.Benders.is_infeasible(sep_res::TestBendersSepRes)
    return sep_res.infeasible_sp
end

function Coluna.Benders.is_unbounded(sep_res::TestBendersSepRes)
    return sep_res.unbounded_sp
end

function Coluna.Benders.get_obj_val(sep_res::TestBendersSepRes)
    return 0.0
end



mutable struct TestBendersFlowFlagContext <: Coluna.Benders.AbstractBendersContext
    master_opt_res::TestBendersMasterRes
    sp_opt_res::TestBendersSepRes
    flag_unbounded_master::Bool ## check we enter treat_unbounded_master_problem_case!
    flag_unbounded_master_sp::Bool ## check we enter setup_separation_for_unbounded_master_case!
    flag_infeasible_sp::Bool ## check we enter treat_infeasible_separation_problem_case!
end

function Coluna.Benders.get_master(ctx::TestBendersFlowFlagContext) 
    return TestBendersMaster()
end

function Coluna.Benders.get_reform(ctx::TestBendersFlowFlagContext) 
    return nothing
end

function Coluna.Benders.is_minimization(ctx::TestBendersFlowFlagContext) 
    return true
end

function Coluna.Benders.benders_iteration_output_type(ctx::TestBendersFlowFlagContext) 
    return Coluna.Algorithm.BendersIterationOutput
end


function Coluna.Benders.optimize_master_problem!(master, ctx::TestBendersFlowFlagContext, env)
    return ctx.master_opt_res
end

function Coluna.Benders.treat_unbounded_master_problem_case!(master, ctx::TestBendersFlowFlagContext, env) 
    ctx.flag_unbounded_master = true
    ctx.master_opt_res.unbounded_master = false 
    return ctx.master_opt_res
end

function Coluna.Benders.get_benders_subprobs(ctx::TestBendersFlowFlagContext) 
    return [(1, TestBendersSubproblem())]
end

function Coluna.Benders.setup_separation_for_unbounded_master_case!(ctx::TestBendersFlowFlagContext, sp, mast_primal_sol) 
    ctx.flag_unbounded_master_sp = true
    return
end

function Coluna.Benders.update_sp_rhs!(ctx::TestBendersFlowFlagContext, sp, mast_primal_sol)
    return
end

function Coluna.Benders.optimize_separation_problem!(ctx::TestBendersFlowFlagContext, sp, env, unbounded_master)
    return ctx.sp_opt_res
end

function Coluna.Benders.treat_infeasible_separation_problem_case!(ctx::TestBendersFlowFlagContext, sp, env, unbounded_master_case) 
    ctx.flag_infeasible_sp = true
    return ctx.sp_opt_res
end

function Coluna.Benders.master_is_unbounded(ctx::TestBendersFlowFlagContext, second_stage_cost, unbounded_master_case)
    return ctx.master_opt_res.unbounded_master ## TODO check 
end

function Coluna.Benders.insert_cuts!(reform, ctx::TestBendersFlowFlagContext, cuts) 
    return []
end

function Coluna.Benders.build_primal_solution(ctx::TestBendersFlowFlagContext, mast_primal_sol, sep_sp_sols) 
    return
end

function Coluna.Benders.set_of_cuts(ctx::TestBendersFlowFlagContext) 
    return []
end

function Coluna.Benders.set_of_sep_sols(ctx::TestBendersFlowFlagContext) 
    return []
end

function Coluna.Benders.push_in_set!(ctx::TestBendersFlowFlagContext, set, elem)
    return false
end


function benders_flow_infeasible_master()
    ctx = TestBendersFlowFlagContext( ## bounded master
        TestBendersMasterRes(
            true,
            false,
            false
        ),
        TestBendersSepRes(
            false,
            false
        ),
        false,
        false,
        false
    )
    res = Coluna.Benders.run_benders_iteration!(ctx, nothing, nothing, nothing)
    @test res.infeasible == true

    @test ctx.flag_unbounded_master == false
    @test ctx.flag_unbounded_master_sp == false
    @test ctx.flag_infeasible_sp == false

    ctx = TestBendersFlowFlagContext( ## unbounded master with certificate = true to ensure we stop before entering setup_separation_for_unbounded_master_case!
        TestBendersMasterRes(
            true,
            true,
            true
        ),
        TestBendersSepRes(
            false,
            false
        ),
        false,
        false,
        false
    )
    res = Coluna.Benders.run_benders_iteration!(ctx, nothing, nothing, nothing)
    @test res.infeasible == true

    @test ctx.flag_unbounded_master == true
    @test ctx.flag_unbounded_master_sp == false
    @test ctx.flag_infeasible_sp == false

end
register!(unit_tests, "benders_default", benders_flow_infeasible_master)


function benders_flow_unbounded_master()
    ctx = TestBendersFlowFlagContext(
        TestBendersMasterRes(
            false,
            true,
            false ## with certificate = false
        ),
        TestBendersSepRes(
            false,
            false
        ),
        false,
        false,
        false
    )
    res = Coluna.Benders.run_benders_iteration!(ctx, nothing, nothing, nothing)

    @test ctx.flag_unbounded_master == true
    @test ctx.flag_unbounded_master_sp == false
    @test ctx.flag_infeasible_sp == false

    ctx = TestBendersFlowFlagContext(
        TestBendersMasterRes(
            false,
            true,
            true ## with certificate = true
        ),
        TestBendersSepRes(
            false,
            false
        ),
        false,
        false,
        false
    )
    res = Coluna.Benders.run_benders_iteration!(ctx, nothing, nothing, nothing)

    @test ctx.flag_unbounded_master == true
    @test ctx.flag_unbounded_master_sp == true
    @test ctx.flag_infeasible_sp == false

end
register!(unit_tests, "benders_default", benders_flow_unbounded_master)


function benders_flow_infeasible_sp()
    ctx = TestBendersFlowFlagContext( ## bounded sp, bounded master
        TestBendersMasterRes(
            false,
            false,
            false
        ),
        TestBendersSepRes(
            true,
            false
        ),
        false,
        false,
        false
    )
    res = Coluna.Benders.run_benders_iteration!(ctx, nothing, nothing, nothing)

    @test ctx.flag_infeasible_sp == true
    @test ctx.flag_unbounded_master == false
    @test ctx.flag_unbounded_master_sp == false

    ctx = TestBendersFlowFlagContext( ## bounded sp, unbounded master
        TestBendersMasterRes(
            false,
            true,
            false
        ),
        TestBendersSepRes(
            true,
            false
        ),
        false,
        false,
        false
    )
    res = Coluna.Benders.run_benders_iteration!(ctx, nothing, nothing, nothing)

    @test ctx.flag_infeasible_sp == true
    @test ctx.flag_unbounded_master == true
    @test ctx.flag_unbounded_master_sp == false

    ctx = TestBendersFlowFlagContext( ## bounded sp, unbounded master with certificate
        TestBendersMasterRes(
            false,
            true,
            true
        ),
        TestBendersSepRes(
            true,
            false
        ),
        false,
        false,
        false
    )
    res = Coluna.Benders.run_benders_iteration!(ctx, nothing, nothing, nothing)

    @test ctx.flag_infeasible_sp == true
    @test ctx.flag_unbounded_master == true
    @test ctx.flag_unbounded_master_sp == true

end
register!(unit_tests, "benders_default", benders_flow_infeasible_sp)

## test unbounded sp flow when sp is either feasible or infeasible -> in both cases an error should be thrown
function benders_flow_unbounded_sp()

    ctx = TestBendersFlowFlagContext( ## feasible unbounded sp
        TestBendersMasterRes(
            false,
            false,
            false
        ),
        TestBendersSepRes(
            false,
            true
        ),
        false,
        false,
        false
    )
    
    @test_throws Coluna.Benders.UnboundedError Coluna.Benders.run_benders_iteration!(ctx, nothing, nothing, nothing)

    ctx = TestBendersFlowFlagContext( ## infeasible unbounded sp
        TestBendersMasterRes(
            false,
            false,
            false
        ),
        TestBendersSepRes(
            true,
            true
        ),
        false,
        false,
        false
    )

    @test_throws Coluna.Benders.UnboundedError Coluna.Benders.run_benders_iteration!(ctx, nothing, nothing, nothing)
    @test ctx.flag_infeasible_sp == true

end
register!(unit_tests, "benders_default", benders_flow_unbounded_sp)


