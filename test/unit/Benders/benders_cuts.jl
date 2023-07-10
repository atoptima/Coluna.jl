# opt: x1 = 0.0, x2 = 1.0
#      y1 = 1.2727272727272727, y2 = 0.36363636363636365, y3 = 0.0
#      mlp = 3.909090909090909

# sub-opt: x1 = 1.0, x2 = 0.6666666666666666
#          y1 = 0.8484848484848484, y2 = 0.5757575757575757, y3 = 0.0
#          mlp = 5.9393939393939394

# infeasible: x1 = x2 = 0

function benders_form_D()
    #using JuMP, GLPK
    #m = Model(GLPK.Optimizer)
    #@variable(m, x[1:2] >= 0)
    #@variable(m, y[1:3] >= 0) 
    #@constraint(m, x[1] + x[2] >= 1) ok
    #@constraint(m, 2x[1] - x[2] + 5y[1] - y[2] >= 5) ok
    #@constraint(m, x[1] + 3x[2] - 2y[3] >= 3) ok
    #@constraint(m, y[1] + 2y[2] + y[3] >= 2) ok
    #@objective(m, Min, 3x[1] + 1x[2] + 2y[1] + y[2] + y[3]) ok
    #optimize!(m)
    #@show objective_value(m)
    #@show value.(x)
    #@show value.(y)
    form = """
     master
         min
         3x1 + 1x2 + z
         s.t.
         x1 + x2 >= 1
  
     benders_sp
         min
         0x1 + 0x2 + 2y1 + y2 + y3 + art1 + art2 + art3 + z
         s.t.
         y1 + 2y2 + y3 + art1 >= 2 
         2x1 - x2 + 5y1 - y2 + art2 >= 5 {BendTechConstr}
         x1 + 3x2 - 2y3 + art3 >= 3 {BendTechConstr}
 
     integer
         first_stage
             x1, x2
 
     continuous
         second_stage_cost
             z
         second_stage
             y1, y2, y3
         second_stage_artificial
            art1, art2, art3
     
     bounds
         -Inf <= z <= Inf
         0 <= x1 <= 1
         1 <= x2 <= 1
         1 <= y1 <= 2
         0 <= y2 <= 2
         0 <= y3 <= 2
         0 <= art1 <= Inf
         0 <= art2 <= Inf
         0 <= art3 <= Inf
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform
 
 end


# function test_benders_form_D()
#    env, reform = benders_form_D() 
#    master = Coluna.MathProg.getmaster(reform)
#    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
#    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
#    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
#        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
#        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
#    end
#
#    alg = Coluna.Algorithm.BendersCutGeneration(
#        max_nb_iterations = 10,
#        restr_master_solve_alg = Coluna.Algorithm.SolveIpForm()
#    )
#    ctx = Coluna.Algorithm.BendersContext(
#        reform, alg;
#    )
#    Coluna.set_optim_start_time!(env)
#
#    result = Coluna.Benders.run_benders_loop!(ctx, env)
#    @test result.mlp ≈ 3.909090909090909
#
#end
#register!(unit_tests, "benders_default", test_benders_form_D)



function get_name_to_constrids(form)
    d = Dict{String, ClMP.ConstrId}()
    for (constrid, constr) in ClMP.getconstrs(form)
        d[ClMP.getname(form, constr)] = constrid
    end
    return d
end

function get_name_to_varsids(form)
    d = Dict{String, ClMP.VarId}()
    for (varid, var) in ClMP.getvars(form)
        d[ClMP.getname(form, var)] = varid
    end
    return d
end


function test_benders_cut_lhs()
    _, reform = benders_form_D()
    master = Coluna.MathProg.getmaster(reform)
    sps = Coluna.MathProg.get_benders_sep_sps(reform) ##one sp, spid = 3
    sp = sps[3]
    cids = get_name_to_constrids(sp)
    vids = get_name_to_varsids(sp)
    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 100,
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg, 
    )

    dual_sol  = Coluna.MathProg.DualSolution(
        master,
        [cids["sp_c1"], cids["sp_c2"], cids["sp_c3"]],
        [2.0, 4.0, 1.0], ##dumb dual sol
        Coluna.MathProg.VarId[], Float64[], Coluna.MathProg.ActiveBound[],
        0.0,
        Coluna.MathProg.FEASIBLE_SOL
    )

    coeff_cut_lhs = Coluna.Algorithm._compute_cut_lhs(ctx, sp, dual_sol, false) ##opt cut
    @test coeff_cut_lhs[vids["x1"]] ≈ 9.0
    @test coeff_cut_lhs[vids["x2"]] ≈ -1.0
    @test coeff_cut_lhs[sp.duty_data.second_stage_cost_var] ≈ 1.0 ## η
    coeff_cut_lhs = Coluna.Algorithm._compute_cut_lhs(ctx, sp, dual_sol, true) ##feas cut
    @test coeff_cut_lhs[vids["x1"]] ≈ 9.0
    @test coeff_cut_lhs[vids["x2"]] ≈ -1.0
    @test coeff_cut_lhs[sp.duty_data.second_stage_cost_var] ≈ 0.0 ## η


end
register!(unit_tests, "benders_default", test_benders_cut_lhs)


function test_benders_cut_rhs()

    _, reform = benders_form_D()
    master = Coluna.MathProg.getmaster(reform)
    sps = Coluna.MathProg.get_benders_sep_sps(reform) ##one sp, spid = 3
    sp = sps[3]
    cids = get_name_to_constrids(sp)
    vids = get_name_to_varsids(sp)
    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 100,
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg, 
    )

    dual_sol  = Coluna.MathProg.DualSolution(
        master,
        [cids["sp_c1"], cids["sp_c2"], cids["sp_c3"]],
        [2.0, 4.0, 1.0], ##dumb dual sol
        Coluna.MathProg.VarId[vids["y1"], vids["x1"], vids["y2"], vids["x2"]], Float64[10.0, 5.0, 2.0, 3.0], Coluna.MathProg.ActiveBound[MathProg.LOWER, MathProg.UPPER, MathProg.UPPER, MathProg.LOWER], ## x2 fixed to 1.0
        0.0,
        Coluna.MathProg.FEASIBLE_SOL
    )

    coeff_cut_rhs = Coluna.Algorithm._compute_cut_rhs_contrib(ctx, sp, dual_sol)
    @test coeff_cut_rhs == 27.0 + (1*10.0 + 1*5.0 + 2*2.0 + 3.0) ## πr + bounding_constraints ##TODO: update when we know how to deal with equalities in the rhs computation

end
register!(unit_tests, "benders_default", test_benders_cut_rhs)