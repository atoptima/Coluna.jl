@testset "Integration - initial columns callback" begin
    function build_reformulation()
        nb_variables = 4
        form_string = """
            master
                min
                1.0*x1 + 2.0*x2 + 3.0*x3 + 4.0*x4
                s.t.
                1.0*x1 + 2.0*x2 + 3.0*x3 + 4.0*x4 >= 0.0

            dw_sp
                min
                1.0*x1 + 2.0*x2 + 3.0*x3 + 4.0*x4

            continuous
                representatives
                    x1, x2, x3, x4
        """
        env, master, subproblems, constraints, _ = reformfromstring(form_string)
        spform = subproblems[1]
        spvarids = Dict(CL.getname(spform, var) => varid for (varid, var) in CL.getvars(spform))

        # Fake JuMP model to simulate the user interacting with it in the callback.
        fake_model = JuMP.Model()
        @variable(fake_model, x[i in 1:nb_variables])

        for name in ["x$i" for i in 1:nb_variables] 
            CleverDicts.add_item(env.varids, spvarids[name])
        end
        return env, master, spform, x, constraints[1]
    end

    # Create a formulation with 4 variables [x1 x2 x3 x4] and provide an initial column
    # [1 0 2 0].
    # Cost of the column in the master should be 7.
    # Coefficient of the column in the constraint should be 7.
    @testset "normal case" begin
        env, master, spform, x, constr = build_reformulation()

        function callback(cbdata)
            variables = [x[1].index, x[3].index]
            values = [1.0, 2.0]
            custom_data = nothing
            CL._submit_initial_solution(env, cbdata, variables, values, custom_data)
        end 
        
        ClMP.initialize_solution_pool!(spform, callback)

        # iMC_5 because 4 variables before this one
        initcolid = findfirst(var -> ClMP.getname(master, var) == "iMC_5", ClMP.getvars(master))

        @test initcolid !== nothing
        @test ClMP.getperencost(master, initcolid) == 7
        @test ClMP.iscuractive(master, initcolid)
        
        @test ClMP.getcoefmatrix(master)[ClMP.getid(constr), initcolid] == 7
    end
end