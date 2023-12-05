struct TestAttachCustomDataAlgorithm end

struct CustomVarData <: BD.AbstractCustomVarData
    var_value::Int
end

struct CustomConstrData <: BD.AbstractCustomConstrData
    constr_value::Int
end

function Coluna.Algorithm.run!(::TestAttachCustomDataAlgorithm, _, form, _)
    vars = Dict{String, Coluna.MathProg.Variable}()
    for (_, var) in Coluna.MathProg.getvars(form)
        vars[getname(form, var)] = var
    end

    constrs = Dict{String, Coluna.MathProg.Constraint}()
    for (_, constr) in Coluna.MathProg.getconstrs(form)
        constrs[getname(form, constr)] = constr
    end

    @test Coluna.MathProg.getcustomdata(form, vars["x[1]"]).var_value == 1
    @test Coluna.MathProg.getcustomdata(form, vars["x[2]"]).var_value == 2
    @test Coluna.MathProg.getcustomdata(form, constrs["c"]).constr_value == 3
    return Coluna.Algorithm.OptimizationState(form)
end

function attach_custom_data()
    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => CL.Params(
            solver = TestAttachCustomDataAlgorithm()
        ),
        "default_optimizer" => GLPK.Optimizer,
    )
    
    model = BlockModel(coluna)
    @variable(model, x[1:2], Bin)
    @constraint(model, c, x[1] + x[2] <= 1)
    @objective(model, Max, 2x[1] + 3x[2])

    customvars!(model, CustomVarData)
    customconstrs!(model, CustomConstrData)

    customdata!(x[1], CustomVarData(1))
    customdata!(x[2], CustomVarData(2))
    customdata!(c, CustomConstrData(3))
    optimize!(model)
end
register!(integration_tests, "attach_custom_data", attach_custom_data)