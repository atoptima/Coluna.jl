# In this test, we use the Martinelli's knapsack solver pkg (https://github.com/rafaelmartinelli/Knapsacks.jl)
# to test the interface of custom models/solvers.

using Knapsacks
mutable struct KnapsackLibModel <: Coluna.MathProg.AbstractFormulation
    nbitems::Int
    costs::Vector{Float64}
    weights::Vector{Float64}
    capacity::Float64
    job_to_jumpvar::Dict{Int, JuMP.VariableRef}
    #varids::Vector{Coluna.MathProg.VarId}
    #map::Dict{Coluna.MathProg.VarId,Float64}
end
KnapsackLibModel(nbitems) = KnapsackLibModel(
    nbitems, zeros(Float64, nbitems), zeros(Float64, nbitems), 0.0,
    Dict{Int, JuMP.VariableRef}()
)
setcapacity!(model::KnapsackLibModel, cap) = model.capacity = cap
setweight!(model::KnapsackLibModel, j::Int, w) = model.weights[j] = w
setcost!(model::KnapsackLibModel, j::Int, c) = model.costs[j] = c
map!(model::KnapsackLibModel, j::Int, x::JuMP.VariableRef) = model.job_to_jumpvar[j] = x

mutable struct KnapsackLibOptimizer <: BlockDecomposition.AbstractCustomOptimizer
    model::KnapsackLibModel
end

function Coluna.Algorithm.get_units_usage(opt::KnapsackLibOptimizer, form) # form is Coluna Formulation
    units_usage = Tuple{AbstractModel, ClB.UnitType, ClB.UnitPermission}[]
    # TODO : the abstract model is KnapsackLibModel (opt.model)
    return units_usage
end

function _fixed_costs(model::KnapsackLibModel, form, env::Env)
    costs = Float64[]
    for j in 1:length(model.costs)
        cost = Coluna.MathProg.getcurcost(form, _getvarid(model, form, env, j))
        push!(costs, cost < 0 ? -cost : 0)
    end
    return costs
end

function _scale_to_int(vals...)
    return map(x -> Integer(round(10000x)), vals)
end

_getvarid(model::KnapsackLibModel, form, env::Env, j::Int) = Coluna.MathProg.getid(Coluna.MathProg.getvar(form, env.varids[model.job_to_jumpvar[j].index]))

function Coluna.Algorithm.run!(
    opt::KnapsackLibOptimizer, env::Coluna.Env, form::Coluna.MathProg.Formulation,
    input::Coluna.Algorithm.OptimizationInput; kw...
)
    costs = _fixed_costs(opt.model, form, env)
    ws = _scale_to_int(opt.model.capacity, opt.model.weights...)
    cs = _scale_to_int(costs...)

    data = Knapsack(ws[1], [ws[2:end]...], [cs...])
    _, selected = solveKnapsack(data)

    setup_var_id = form.duty_data.setup_var

    cost = sum(-costs[j] for j in selected) + Coluna.MathProg.getcurcost(form, setup_var_id)

    varids = Coluna.MathProg.VarId[]
    varvals = Float64[]

    for j in selected
        if costs[j] > 0
            push!(varids, _getvarid(opt.model, form, env, j))
            push!(varvals, 1)
        end
    end

    push!(varids, setup_var_id)
    push!(varvals, 1)

    sol = Coluna.MathProg.PrimalSolution(form, varids, varvals, cost, Coluna.MathProg.FEASIBLE_SOL)

    result = Coluna.Algorithm.OptimizationState(form; termination_status = Coluna.MathProg.OPTIMAL)
    Coluna.Algorithm.add_ip_primal_sol!(result, sol)
    dual_bound = Coluna.getvalue(Coluna.Algorithm.get_ip_primal_bound(result))
    Coluna.Algorithm.set_ip_dual_bound!(result, Coluna.DualBound(form, dual_bound))
    return Coluna.Algorithm.OptimizationOutput(result)
end


################################################################################
# User model
################################################################################
@testset "Old - knapsack custom model" begin
    data = ClD.GeneralizedAssignment.data("play2.txt")
    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
        "default_optimizer" => GLPK.Optimizer
    )

    model = BlockModel(coluna; direct_model = true)
    @axis(M, data.machines)
    @variable(model, x[m in M, j in data.jobs], Bin)
    @constraint(model, 
        sp[j in data.jobs], sum(x[m,j] for m in data.machines) == 1
    )
    @objective(model, Min,
        sum(data.cost[j,m]*x[m,j] for m in M, j in data.jobs)
    )

    @dantzig_wolfe_decomposition(model, dec, M)

    sp = getsubproblems(dec)
    for m in M
        knp_model = KnapsackLibModel(length(data.jobs))
        setcapacity!(knp_model, data.capacity[m])
        for j in data.jobs
            setweight!(knp_model, j, data.weight[j,m])
            setcost!(knp_model, j, data.cost[j,m])
            map!(knp_model, j, x[m,j])
        end
        knp_optimizer = KnapsackLibOptimizer(knp_model)
        specify!(sp[m], solver = knp_optimizer) ##model = knp_model)
    end

    optimize!(model)

    @test JuMP.objective_value(model) ≈ 75.0
end