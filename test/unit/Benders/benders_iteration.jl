## original MIP:
## min cx + dy s.t.
##  Ax >= b 
##  Tx + Qy >= r
##  x, y >= 0, x ∈ Z^n

## master:
## min cx + η
##  Ax >= B
##  < benders cuts >

## SP:
## min  dy
##  Tx* + Qy >= r
##  y >= 0

## π: dual sol
## η: contribution to the objective of the second-level variables
## feasibility cut: πTx >= πr
## optimality cut: η + πTx >= πr


struct TestBendersIterationContext <: Coluna.Benders.AbstractBendersContext
    context::ClA.BendersContext
    master ##Formulation{Benders...}
    sps ##Dict{Int16, Coluna.ColunaBase.AbstractModel} 
    first_stage_sol::Dict{String, Float64} ## id of variable, value
    second_stage_sols::Dict{String, Float64} ##id of variable, value
end

Coluna.Benders.get_master(ctx::TestBendersIterationContext) = Coluna.Benders.get_master(ctx.context)
Coluna.Benders.get_reform(ctx::TestBendersIterationContext) = Coluna.Benders.get_reform(ctx.context)
Coluna.Benders.is_minimization(ctx::TestBendersIterationContext) = Coluna.Benders.is_minimization(ctx.context)
Coluna.Benders.get_benders_subprobs(ctx::TestBendersIterationContext) = Coluna.Benders.get_benders_subprobs(ctx.context)

## where to check stop condition ? 

## re-def if need to check something
Coluna.Benders.optimize_master_problem!(master, ctx::TestBendersIterationContext, env) = Coluna.Benders.optimize_master_problem!(master, ctx.context, env)

Coluna.Benders.treat_unbounded_master_problem_case!(master, ctx::TestBendersIterationContext, env) = Coluna.Benders.treat_unbounded_master_problem_case!(master, ctx.context, env) 

Coluna.Benders.setup_separation_for_unbounded_master_case!(ctx::TestBendersIterationContext, sp, mast_primal_sol) = Coluna.Benders.setup_separation_for_unbounded_master_case!(ctx.context, sp, mast_primal_sol) 


## TODO: redef to check cuts
Coluna.Benders.optimize_separation_problem!(ctx::TestBendersIterationContext, sp::Formulation{BendersSp}, env, unbounded_master) = Coluna.Benders.optimize_separation_problem!(ctx.context, sp, env, unbounded_master)

Coluna.Benders.master_is_unbounded(ctx::TestBendersIterationContext, second_stage_cost, unbounded_master_case) = Coluna.Benders.master_is_unbounded(ctx.context, second_stage_cost, unbounded_master_case)

## same
Coluna.Benders.treat_infeasible_separation_problem_case!(ctx::TestBendersIterationContext, sp::Formulation{BendersSp}, env, unbounded_master_case) = Coluna.Benders.treat_infeasible_separation_problem_case!(ctx.context, sp, env, unbounded_master_case)


Coluna.Benders.push_in_set!(ctx::TestBendersIterationContext, set::Coluna.Algorithm.CutsSet, sep_result::Coluna.Algorithm.BendersSeparationResult) = Coluna.Benders.push_in_set!(ctx.context, set, sep_result)

Coluna.Benders.push_in_set!(ctx::TestBendersIterationContext, set::Coluna.Algorithm.SepSolSet, sep_result::Coluna.Algorithm.BendersSeparationResult) = Coluna.Benders.push_in_set!(ctx.context, set, sep_result)

Coluna.Benders.insert_cuts!(reform, ctx::TestBendersIterationContext, cuts) = Coluna.Benders.insert_cuts!(reform, ctx.context, cuts)

function Coluna.Benders.build_primal_solution(ctx::TestBendersIterationContext, mast_primal_sol, sep_sp_sols) 
    output = Coluna.Benders.build_primal_solution(ctx.context, mast_primal_sol, sep_sp_sols)
    for (varid, val) in mast_primal_sol
        name = getname(ctx.master, varid)
        if haskey(ctx.first_stage_sol, name)
            @test ctx.first_stage_sol[name] ≈ val
        else
            @test 0.0 <= val <= 1.0e-4
        end
    end
    for (_, sp) in ctx.sps
        for sp_sol in sep_sp_sols.sols
            for (varid, val) in sp_sol
                name = getname(sp, varid)
                if haskey(ctx.second_stage_sols, name)
                    @test ctx.second_stage_sols[name] ≈ val
                else
                    @test 0.0 <= val <= 1.0e-4
                end
            end
        end
    end
    return output
end

Coluna.Benders.benders_iteration_output_type(ctx::TestBendersIterationContext) = Coluna.Benders.benders_iteration_output_type(ctx.context)

Coluna.Benders.update_sp_rhs!(ctx::TestBendersIterationContext, sp, mast_primal_sol) =
Coluna.Benders.update_sp_rhs!(ctx.context, sp, mast_primal_sol)
Coluna.Benders.set_of_cuts(ctx::TestBendersIterationContext) = Coluna.Benders.set_of_cuts(ctx.context)  

Coluna.Benders.set_of_sep_sols(ctx::TestBendersIterationContext) = Coluna.Benders.set_of_sep_sols(ctx.context)


## checks cuts

## stop criterion because of opt. sol found is matched
function benders_iter_opt_stop()
    env, reform = benders_form_location_routing_fixed_opt_continuous()
    master = ClMP.getmaster(reform)
    sps = ClMP.get_benders_sep_sps(reform)
    ClMP.relax_integrality!(master)

    ## sol fully fixed
    ##expected sol
    first_stage_sol = Dict(
        "y1" => 0.5,
        "y2" => 0.0,  
        "y3" => 0.3333,
        "z" => 175.16666666666666
    )
    second_stage_sols = Dict(
        "x11" => 0.5, 
        "x12" => 0.5, 
        "x13" => 0.49999, 
        "x14" => 0.5, 
        "x31" => 0.33333, 
        "x32" => 0.33333, 
        "x33" => 0.16666, 
        "x34" =>  0.33333
    )

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10
    )
    ctx = TestBendersIterationContext(
        Coluna.Algorithm.BendersContext(
            reform, alg
        ),
        master,
        sps,
        first_stage_sol,
        second_stage_sols
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
    @test result.master ≈ 293.4956666
end
register!(unit_tests, "benders_default", benders_iter_opt_stop)