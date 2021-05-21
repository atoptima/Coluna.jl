# In this test, we use the Martinelli's knapsack lib to test the interface 
# to custom models/solvers : https://github.com/rafaelmartinelli/KnapsackLib.jl

#using KnapsackLib

mutable struct KnapsackLibModel <: Coluna.MathProg.AbstractFormulation
    nbitems::Int
    costs::Vector{Float64}
    weights::Vector{Float64}
    capacity::Float64
end
KnapsackLibModel(nbitems) = KnapsackLibModel(nbitems, zeros(Float64, nbitems), zeros(Float64, nbitems), 0.0)
setcapacity!(model::KnapsackLibModel, cap) = model.capacity = cap
setweight!(model::KnapsackLibModel, j::Int, w) = model.weights[j] = w
setcost!(model::KnapsackLibModel, j::Int, c) = model.costs[j] = c

mutable struct KnapsackLibOptimizer <: BlockDecomposition.AbstractCustomOptimizer

end

function knpcustommodel()
    @testset "knapsack custom model" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")
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
            end
            specify!(sp[m], solver = KnapsackLibOptimizer) ##model = knp_model)
        end

        optimize!(model)
    end
    exit()
end

knpcustommodel()