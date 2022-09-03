function reformulation_for_colgen(nb_variables = 5, obj_sense = Coluna.MathProg.MinSense)
    env = Env{ClMP.VarId}(Coluna.Params())

    spform = ClMP.create_formulation!(env, ClMP.DwSp(nothing, 1, 1, ClMP.Integ), obj_sense = obj_sense)
    # Create subproblem variables
    spvars = Dict{String, ClMP.Variable}()
    for i in 1:nb_variables
        x = ClMP.setvar!(spform, "x$i", ClMP.DwSpPricingVar)
        ClMP.setperencost!(spform, x, i * 1.0)
        spvars["x$i"] = x
    end

    # Create the reformulation
    reform = ClMP.Reformulation(env)
    ClMP.add_dw_pricing_sp!(reform, spform)

    master = ClMP.create_formulation!(env, ClMP.DwMaster(); obj_sense = obj_sense)
    ClMP.setmaster!(reform, master)
    spform.parent_formulation = master
    master.parent_formulation = reform
    # Create sp representative variables in the master
    mastervars = Dict{String, ClMP.Variable}()
    for i in 1:nb_variables
        x = ClMP.setvar!(
            master, "x$i", ClMP.MasterRepPricingVar, id = getid(spvars["x$i"])
        )
        ClMP.setperencost!(master, x, i * 1.0)
        mastervars["x$i"] = x
    end

    # Create a constraint in the master
    constr = ClMP.setconstr!(
        master, "constr", ClMP.MasterMixedConstr;
        members = Dict(ClMP.getid(mastervars["x$i"]) => 1.0 * i for i in 1:nb_variables)
    )

    closefillmode!(ClMP.getcoefmatrix(master))
    closefillmode!(ClMP.getcoefmatrix(spform))
    return env, master, spform, spvars, constr
end

@testset "Algorithm - colgen" begin
    @testset "Two identical columns at two iterations" begin
        # Expected: unexpected variable state error.
        env, master, spform, spvars, constr = reformulation_for_colgen()
        algo = ClA.ColumnGeneration()
        phase = 1

        ## Iteration 1
        redcosts_spsols = [-2.0, 2.0]
        sp_optstate = ClA.OptimizationState(spform; max_length_ip_primal_sols = 5)

        col1 = ClMP.PrimalSolution(
            spform, 
            map(x -> ClMP.getid(spvars[x]), ["x1", "x3"]),
            [1.0, 2.0],
            1.0,
            ClB.FEASIBLE_SOL
        )
        col2 = ClMP.PrimalSolution(
            spform, 
            map(x -> ClMP.getid(spvars[x]), ["x2", "x3"]),
            [5.0, 2.0],
            2.5,
            ClB.FEASIBLE_SOL
        ) # not inserted because positive reduced cost.
        ClA.add_ip_primal_sols!(sp_optstate, col1, col2)
        
        nb_new_cols = ClA.insert_columns!(master, sp_optstate, redcosts_spsols, algo, phase)
        @test nb_new_cols == 1

        ## Iteration 2
        redcosts_spsols = [-1.0]
        sp_optstate = ClA.OptimizationState(spform; max_length_ip_primal_sols = 5)

        col3 = ClMP.PrimalSolution(
            spform, 
            map(x -> ClMP.getid(spvars[x]), ["x1", "x3"]),
            [1.0, 2.0],
            3.0,
            ClB.FEASIBLE_SOL
        )
        ClA.add_ip_primal_sols!(sp_optstate, col3)
        
        @test_throws ClA.ColumnAlreadyInsertedColGenError ClA.insert_columns!(master, sp_optstate, redcosts_spsols, algo, phase)
    end

    @testset "Two identical columns at same iteration" begin
        # Expected: no error and two identical columns in the formulation
        env, master, spform, spvars, constr = reformulation_for_colgen()
        algo = ClA.ColumnGeneration()

        redcosts_spsols = [-2.0, -2.0, 2.0]
        phase = 1

        sp_optstate = ClA.OptimizationState(spform; max_length_ip_primal_sols = 5)
        col1 = ClMP.PrimalSolution(
            spform, 
            map(x -> ClMP.getid(spvars[x]), ["x1", "x3"]),
            [1.0, 2.0],
            1.0,
            ClB.FEASIBLE_SOL
        )
        col2 = ClMP.PrimalSolution(
            spform, 
            map(x -> ClMP.getid(spvars[x]), ["x1", "x3"]),
            [1.0, 2.0],
            2.0,
            ClB.FEASIBLE_SOL
        )
        col3 = ClMP.PrimalSolution(
            spform, 
            map(x -> ClMP.getid(spvars[x]), ["x2", "x3"]),
            [5.0, 2.0],
            3.5,
            ClB.FEASIBLE_SOL
        ) # not inserted because positive reduced cost.
        ClA.add_ip_primal_sols!(sp_optstate, col1, col2, col3)

        nb_new_cols = ClA.insert_columns!(master, sp_optstate, redcosts_spsols, algo, phase)
        @test nb_new_cols == 2
    end

    @testset "Stabilization" begin
        
    end
end
