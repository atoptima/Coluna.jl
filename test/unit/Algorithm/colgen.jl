@testset "Algorithm - colgen" begin
    form_string = """
        master
            min
            x1 + x2 + x3 + x4 + x5
            s.t.
            x1 + x2 + x3 + x4 + x5 >= 0.0

        dw_sp
            min
            x1 + x2 + x3 + x4 + x5

        continuous
            representatives
                x1, x2, x3, x4, x5
    """
    @testset "insert_columns!" begin
        @testset "Two identical columns at two iterations" begin
            # Expected: unexpected variable state error.
            env, master, subproblems, constraints = reformfromstring(form_string)
            spform = subproblems[1]
            spvarids = Dict(CL.getname(spform, var) => varid for (varid, var) in CL.getvars(spform))
            algo = ClA.ColumnGeneration(
                throw_column_already_inserted_warning = true
            )
            phase = 1

            ## Iteration 1
            redcosts_spsols = [-2.0, 2.0]
            sp_optstate = ClA.OptimizationState(spform; max_length_ip_primal_sols = 5)

            col1 = ClMP.PrimalSolution(
                spform, 
                map(x -> spvarids[x], ["x1", "x3"]),
                [1.0, 2.0],
                1.0,
                ClB.FEASIBLE_SOL
            )
            col2 = ClMP.PrimalSolution(
                spform, 
                map(x -> spvarids[x], ["x2", "x3"]),
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
                map(x -> spvarids[x], ["x1", "x3"]),
                [1.0, 2.0],
                3.0,
                ClB.FEASIBLE_SOL
            )
            ClA.add_ip_primal_sols!(sp_optstate, col3)
            
            @test_throws ClA.ColumnAlreadyInsertedColGenWarning ClA.insert_columns!(master, sp_optstate, redcosts_spsols, algo, phase)
        end

        @testset "Two identical columns at same iteration" begin
            # Expected: no error and two identical columns in the formulation
            env, master, subproblems, constraints = reformfromstring(form_string)
            spform = subproblems[1]
            spvarids = Dict(CL.getname(spform, var) => varid for (varid, var) in CL.getvars(spform))
            algo = ClA.ColumnGeneration(
                throw_column_already_inserted_warning = true
            )

            redcosts_spsols = [-2.0, -2.0, 2.0]
            phase = 1

            sp_optstate = ClA.OptimizationState(spform; max_length_ip_primal_sols = 5)
            col1 = ClMP.PrimalSolution(
                spform, 
                map(x -> spvarids[x], ["x1", "x3"]),
                [1.0, 2.0],
                1.0,
                ClB.FEASIBLE_SOL
            )
            col2 = ClMP.PrimalSolution(
                spform, 
                map(x -> spvarids[x], ["x1", "x3"]),
                [1.0, 2.0],
                2.0,
                ClB.FEASIBLE_SOL
            )
            col3 = ClMP.PrimalSolution(
                spform, 
                map(x -> spvarids[x], ["x2", "x3"]),
                [5.0, 2.0],
                3.5,
                ClB.FEASIBLE_SOL
            ) # not inserted because positive reduced cost.
            ClA.add_ip_primal_sols!(sp_optstate, col1, col2, col3)

            nb_new_cols = ClA.insert_columns!(master, sp_optstate, redcosts_spsols, algo, phase)
            @test nb_new_cols == 2
        end

        @testset "Deactivated column added twice at same iteration" begin
            env, master, subproblems, constraints = reformfromstring(form_string)
            spform = subproblems[1]
            spvarids = Dict(CL.getname(spform, var) => varid for (varid, var) in CL.getvars(spform))
            algo = ClA.ColumnGeneration(
                throw_column_already_inserted_warning = true
            )

            # Add column.
            col1 = ClMP.PrimalSolution(
                spform, 
                map(x -> spvarids[x], ["x1", "x3"]),
                [1.0, 2.0],
                1.0,
                ClB.FEASIBLE_SOL
            )
            col_id = ClA.insert_column!(master, col1, "MC")

            # Deactivate column.
            ClMP.deactivate!(master, col_id)

            # Add same column twice.
            redcosts_spsols = [-2.0, -2.0]
            phase = 1

            sp_optstate = ClA.OptimizationState(spform; max_length_ip_primal_sols = 5)
            col2 = ClMP.PrimalSolution(
                spform, 
                map(x -> spvarids[x], ["x1", "x3"]),
                [1.0, 2.0],
                1.0,
                ClB.FEASIBLE_SOL
            )
            col3 = ClMP.PrimalSolution(
                spform, 
                map(x -> spvarids[x], ["x1", "x3"]),
                [1.0, 2.0],
                2.0,
                ClB.FEASIBLE_SOL
            )
            ClA.add_ip_primal_sols!(sp_optstate, col2, col3)

            nb_new_cols = ClA.insert_columns!(master, sp_optstate, redcosts_spsols, algo, phase)
            @test nb_new_cols == 1
        end

        @testset "Infeasible subproblem" begin
            env, master, subproblems, constraints = reformfromstring(form_string)
            spform = subproblems[1]
            spvarids = Dict(CL.getname(spform, var) => varid for (varid, var) in CL.getvars(spform))
            algo = ClA.ColumnGeneration(
                throw_column_already_inserted_warning = true
            )

            sp_optstate = ClA.OptimizationState(spform; termination_status = ClB.INFEASIBLE_OR_UNBOUNDED)

            redcosts_spsols = [3.9256065065274015e-10]
            phase = 1

            nb_new_cols = ClA.insert_columns!(master, sp_optstate, redcosts_spsols, algo, phase)
            @test nb_new_cols == -1
        end
    end
end
