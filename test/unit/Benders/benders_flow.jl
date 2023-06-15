mutable struct TestBendersFlowContext <: Coluna.Benders.AbstractBendersContext
    context::ClA.BendersContext
    infeasible_master::Bool  
    unbounded_master::Bool##flag to check that we enter treat_unbounded_master_problem_case!
    infeasible_sp::Bool ## flag to check that we enter treat_infeasible_separation_problem_case
    opt_sp::Bool
end


Coluna.Benders.get_master(ctx::TestBendersFlowContext) = Coluna.Benders.get_master(ctx.context)
Coluna.Benders.get_reform(ctx::TestBendersFlowContext) = Coluna.Benders.get_reform(ctx.context)
Coluna.Benders.is_minimization(ctx::TestBendersFlowContext) = Coluna.Benders.is_minimization(ctx.context)
Coluna.Benders.get_benders_subprobs(ctx::TestBendersFlowContext) = Coluna.Benders.get_benders_subprobs(ctx.context)


Coluna.Benders.optimize_master_problem!(master, ctx::TestBendersFlowContext, env) = Coluna.Benders.optimize_master_problem!(master, ctx.context, env)

function Coluna.Benders.treat_unbounded_master_problem_case!(master, ctx::TestBendersFlowContext, env) 
    output = Coluna.Benders.treat_unbounded_master_problem_case!(master, ctx.context, env)
    ctx.unbounded_master = true
    return output
end

Coluna.Benders.setup_separation_for_unbounded_master_case!(ctx::TestBendersFlowContext, sp, mast_primal_sol) = Coluna.Benders.setup_separation_for_unbounded_master_case!(ctx.context, sp, mast_primal_sol) 


function Coluna.Benders.optimize_separation_problem!(ctx::TestBendersFlowContext, sp::Formulation{BendersSp}, env, unbounded_master) 
    output = Coluna.Benders.optimize_separation_problem!(ctx.context, sp, env, unbounded_master)
    ctx.opt_sp = true
    return output
end

Coluna.Benders.master_is_unbounded(ctx::TestBendersFlowContext, second_stage_cost, unbounded_master_case) = Coluna.Benders.master_is_unbounded(ctx.context, second_stage_cost, unbounded_master_case)


function Coluna.Benders.treat_infeasible_separation_problem_case!(ctx::TestBendersFlowContext, sp::Formulation{BendersSp}, env, unbounded_master_case) 
    output = Coluna.Benders.treat_infeasible_separation_problem_case!(ctx.context, sp, env, unbounded_master_case)
    ctx.infeasible_sp = true
    return output
end


Coluna.Benders.push_in_set!(ctx::TestBendersFlowContext, set::Coluna.Algorithm.CutsSet, sep_result::Coluna.Algorithm.BendersSeparationResult) = Coluna.Benders.push_in_set!(ctx.context, set, sep_result)

Coluna.Benders.push_in_set!(ctx::TestBendersFlowContext, set::Coluna.Algorithm.SepSolSet, sep_result::Coluna.Algorithm.BendersSeparationResult) = Coluna.Benders.push_in_set!(ctx.context, set, sep_result)

Coluna.Benders.insert_cuts!(reform, ctx::TestBendersFlowContext, cuts) = Coluna.Benders.insert_cuts!(reform, ctx.context, cuts)

Coluna.Benders.build_primal_solution(ctx::TestBendersFlowContext, mast_primal_sol, sep_sp_sols) = Coluna.Benders.build_primal_solution(ctx.context, mast_primal_sol, sep_sp_sols)


Coluna.Benders.benders_iteration_output_type(ctx::TestBendersFlowContext) = Coluna.Benders.benders_iteration_output_type(ctx.context)

Coluna.Benders.update_sp_rhs!(ctx::TestBendersFlowContext, sp, mast_primal_sol) =
Coluna.Benders.update_sp_rhs!(ctx.context, sp, mast_primal_sol)
Coluna.Benders.set_of_cuts(ctx::TestBendersFlowContext) = Coluna.Benders.set_of_cuts(ctx.context)  

Coluna.Benders.set_of_sep_sols(ctx::TestBendersFlowContext) = Coluna.Benders.set_of_sep_sols(ctx.context)


function benders_flow_unbounded_master()
    env, reform, _ = benders_form_unbounded_master()
    alg = Coluna.Algorithm.BendersCutGeneration()
    ctx = TestBendersFlowContext(
        Coluna.Algorithm.BendersContext(
            reform, alg
        ),
        false,
        false,
        false,
        false
    )
    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    for (_, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_iteration!(ctx, nothing, env, nothing)
    @test ctx.unbounded_master == true
end
register!(unit_tests, "benders_default", benders_flow_unbounded_master, f = true)



## x2 fixed to zero
## z cost fixed to dumb value
function benders_infeasible_sp()
    form = """
     master
         min
         x1 + 4x2 + z
         s.t.
         x1 + x2 >= 1
  
     benders_sp
         min
         0x1 + 0x2 + 2y1 + 3y2 + y3 + art1 + art2 + z
         s.t.
         x1 + x2 + y1 + 2y3 + art1 >= 1 {BendTechConstr}
         x2 + y2 + art2 >= 2 {BendTechConstr}
 
     integer
         first_stage
             x1, x2
 
     continuous
         second_stage_cost
             z
         second_stage
             y1, y2, y3
         second_stage_artificial
            art1, art2
     
     bounds
         10 <= z <= 10
         0 <= x1 <= 1
         0 <= x2 <= 0
         0 <= y1 <= 1
         0 <= y2 <= 1
         0 <= y3 <= 1
         0 <= art1 <= Inf
         0 <= art2 <= Inf
         0 <= art3 <= Inf
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform
 
 end


 function benders_flow_infeasible_sp()
    env, reform = benders_infeasible_sp()
    alg = Coluna.Algorithm.BendersCutGeneration()
    master = ClMP.getmaster(reform)
    sps = ClMP.get_benders_sep_sps(reform)
    @show master
    for sp in sps
        @show sp
    end

    ctx = TestBendersFlowContext(
        Coluna.Algorithm.BendersContext(
            reform, alg
        ),
        false,
        false,
        false,
        false
    )
    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    for (_, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_iteration!(ctx, nothing, env, nothing)

    @test ctx.opt_sp == true
    @test ctx.infeasible_sp == true
end
register!(unit_tests, "benders_default", benders_flow_infeasible_sp, f = true)