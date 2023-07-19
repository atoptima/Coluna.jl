# GAP instance with two machines and 4 jobs s.t. each machine has a capacity of 2, each job has weight 1
# One of the job is forced to be assigned 0.5 times to machine 1 s.t. the linear relaxation of the problem is feasible, but not the original MIP. 
function test_treesearch_gap_1()
    M = [1,2]
    J = 1:4
    c = [10 3 7 5; 
         3 6 4 12
         ]
    coluna = optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm() # default branch-cut-and-price
    ),
    "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
    )

    @axis(M_axis, M)

    model = BlockModel(coluna)

    @variable(model, x[m in M_axis, j in J], Bin);
    @constraint(model, cov[j in J], sum(x[m, j] for m in M_axis) >= 1)
    @constraint(model, knp[m in M_axis], sum(1.0 * x[m, j] for j in J) <= 2.0)
    @objective(model, Min, sum(c[m, j] * x[m, j] for m in M_axis, j in J))

    #JuMP.relax_integrality(model)
    JuMP.fix(x[1, 1], 0.5; force=true)

    @dantzig_wolfe_decomposition(model, decomposition, M_axis)

    optimize!(model)
    @test_broken JuMP.termination_status(model) == MOI.INFEASIBLE

end
register!(e2e_tests, "treesearch", test_treesearch_gap_1)

# GAP instance with two machines and 4 jobs s.t. each machine has a capacity of 2, each job has weight 1
# One of the job is forced to be assigned 0.5 times (modification of the cov constraint) s.t. the linear relaxation of the problem is feasible, but not the original MIP. 
function test_treesearch_gap_2()
    M = [1,2]
    J = 1:4
    c = [10 3 7 5; 
         3 6 4 12
         ]
    @axis(M_axis, M)
    coluna = optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => Coluna.Params(
            solver = Coluna.Algorithm.TreeSearchAlgorithm() # default branch-cut-and-price
        ),
        "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
    )
    
    model = BlockModel(coluna)
    @variable(model, x[m in M_axis, j in J], Bin);
    @constraint(model, cov[j in J[2:end]], sum(x[m, j] for m in M_axis) >= 1)
    @constraint(model, cov2[j in J[1]], sum(x[m, j] for m in M_axis) == 0.5)
    @constraint(model, knp[m in M_axis], sum(1.0 * x[m, j] for j in J) <= 2.0)
    @objective(model, Min, sum(c[m, j] * x[m, j] for m in M_axis, j in J))

    @dantzig_wolfe_decomposition(model, decomposition, M_axis)
    optimize!(model)
    @test JuMP.termination_status(model) == MOI.INFEASIBLE

end
register!(e2e_tests, "treesearch", test_treesearch_gap_2)