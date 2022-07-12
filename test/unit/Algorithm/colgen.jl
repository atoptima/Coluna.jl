# Tests to implement

# Two identical columns at same colgen iteration -> ok
# Two identical columns at two different colgen iteration -> error

function reformulation_for_colgen(nb_variables = 5, obj_sense = Coluna.MathProg.MinSense)
    env = Env(Coluna.Params())

    spform = ClMP.create_formulation!(env, ClMP.DwSp(), obj_sense)
    # Create subproblem variables
    spvars = Dict{String, ClMP.Varable}()
    for i in 1:nb_variables
        x = ClMP.setvar!(spform, "x$i", ClMP.DwSpPricingVar)
        ClMP.setperencost!(spform, x, i * 1.0)
        spvars["x$i"] = x
    end

    master = ClMP.create_formulation!(env, ClMP.DwMaster(), obj_sense)
    spform.parent_formulation = master
    mastervars = Dict{String, ClMP.Variable}()
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

    reform = ClMP.Reformulation()
    ClMP.setmaster!(reform, master)
    ClMP.add_dw_pricing_sp!(reform, spform)

    closefillmode!(ClMP.getcoefmatrix(master))
    closefillmode!(ClMP.getcoefmatrix(spform))
    return env, master, spform, spvars, constr
end

@testset "Algorithm - colgen" begin
    @testset "Two identical columns at two different colgen iteration" begin
        # Expected: unexpected variable state error.
        env, master, spform, spvars, constr = reformulation_for_colgen()
        

    end

    @testset "Two identical columns at same colgen iteration" begin
        # Expected: no error and two identical columns in the formulation
        env, master, spform, spvars, constr = reformulation_for_colgen()
    end
end