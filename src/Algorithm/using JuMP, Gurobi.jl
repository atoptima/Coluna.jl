using JuMP, Gurobi, Luxor

A = 10
B = 30

I = 1:18
I² = Tuple{Int,Int}[]
for j in 2:length(I), i in 1:(j-1)
    push!(I², (i, j))
end

c = [5, 10, 8, 5, 12, 45, 12, 41, 33, 21, 10, 12, 21, 14, 15, 12, 17, 18]
r = [5, 4, 5, 5, 3, 2.5, 4, 1, 2, 2, 1.2, 4.2, 5, 0.2, 0.5, 0.7, 5, 8]

gurobi = optimizer_with_attributes(
    Gurobi.Optimizer,
    "NonConvex" => 2
)

m = Model(gurobi)

@variable(m, x[i in I] >= 0)
@variable(m, y[i in I] >= 0)
@variable(m, δ[i in I], Bin)
@variable(m, γ[p in I²], Bin)

@constraint(m, x_pos1[i in I], x[i] >= r[i]δ[i])
@constraint(m, x_pos2[i in I], x[i] <= (A-r[i]) * δ[i])
@constraint(m, y_pos1[i in I], y[i] >= r[i]δ[i])
@constraint(m, y_pos2[i in I], y[i] <= (B-r[i]) * δ[i])
@constraint(m, lin_δ_prod1[(i,j) in I²], γ[(i,j)] <= δ[i])
@constraint(m, lin_δ_prod2[(i,j) in I²], γ[(i,j)] <= δ[j])
@constraint(m, lin_δ_prod3[(i,j) in I²], γ[(i,j)] >= δ[i] + δ[j] - 1)
@constraint(m, dist_circles[(i,j) in I²], 
    (x[i] - x[j])^2 + (y[i] - y[j])^2 >= (r[i] + r[j])^2 * γ[(i,j)]
)

for (i,j) in I²
    x_i = value(x[i])
    y_i = value(y[i])
    x_j = value(x[j])
    y_j = value(y[j])
    lhs = sqrt((x_i - x_j)^2 + (y_i - y_j)^2)
    rhs = value(δ[i]) * value(δ[j]) * (r[i] + r[j])
    println("$lhs >= $rhs")
    @assert lhs >= rhs
end

@objective(m, Max, sum(c[i] * δ[i] for i in I))

optimize!(m)

objective_value(m)
value.(δ)

width = 200
height = 500
d = Drawing(width, height, "solution.png")
sethue("gray70") # knapsack

rect(Point(10, 10), A*10, B*10, :fill)

_point(i) = (Point(value(x[i]), value(y[i])) + 1) * 10

sethue("red")
for i in I
    if value(δ[i]) ≈ 1.0
        circle(_point(i), r[i] * 10, :stroke)
    end
end

finish()

# draws the solution



bcp = Coluna.Algorithm.TreeSearchAlgorithm(
    conqueralg = ColCutGenConquer(
        colgen = ColumnGeneration(
            max_nb_iterations = 1000
        ),
        primal_heuristics = [DefaultRestrictedMasterHeuristic()],
        cutgen = CutCallbacks()
    ),
    dividealg = SimpleBranching(),
    explorestrategy = DepthFirstStrategy(),
    maxnumnodes::Int = 50,
    branchingtreefile = "tree.dot"
)