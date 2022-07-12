@testset "Integration - initial columns callback" begin
    # DW subproblem formulation having a given nb of variables.
    # Its parent is the master with representatives of sp vars & a constraint sum_i i*x_i <= 0.
    # Cost of variable x[i] is i.
    function build_reformulation(nb_variables)
        env = CL.Env{ClMP.VarId}(CL.Params())

        # Create the reformulation
        reform = Reformulation()

        # Create subproblem and variables
        spform = ClMP.create_formulation!(env, DwSp(nothing, 0, 1, ClMP.Continuous))
        spvars = Dict{String, ClMP.Variable}();
        for i in 1:nb_variables
            x =  ClMP.setvar!(spform, "x$i", ClMP.DwSpPricingVar)
            ClMP.setperencost!(spform, x, i * 1.0)
            spvars["x$i"] = x
        end
        ClMP.add_dw_pricing_sp!(reform, spform)

        # Create master and representatives
        master = ClMP.create_formulation!(env, DwMaster(); parent_formulation = reform)
        spform.parent_formulation = master
        mastervars = Dict{String, ClMP.Variable}();
        for i in 1:nb_variables
            x = ClMP.setvar!(
                master, "x$i", ClMP.MasterRepPricingVar, id = getid(spvars["x$i"])
            )
            ClMP.setperencost!(master, x, i * 1.0)
            mastervars["x$i"] = x
        end

        constr = ClMP.setconstr!(
            master, "constr", ClMP.MasterMixedConstr; 
            members = Dict(ClMP.getid(mastervars["x$i"]) => 1.0 * i for i in 1:nb_variables)
        )
        ClMP.setmaster!(reform, master)

        closefillmode!(ClMP.getcoefmatrix(master))
        closefillmode!(ClMP.getcoefmatrix(spform))

        # Fake JuMP model to simulate the user interacting with it in the callback.
        fake_model = JuMP.Model()
        @variable(fake_model, x[i in 1:nb_variables])
    
        for name in ["x$i" for i in 1:nb_variables] 
            CleverDicts.add_item(env.varids, ClMP.getid(spvars[name]))
        end
        return env, master, spform, spvars, x, constr
    end

    # Create a formulation with 4 variables [x1 x2 x3 x4] and provide an initial column
    # [1 0 2 0].
    # Cost of the column in the master should be 7.
    # Coefficient of the column in the constraint should be 7.
    @testset "normal case" begin
        env, master, spform, vars, x, constr = build_reformulation(4)

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