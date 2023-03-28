# # Custom Variables and Cuts 

# Let us consider a Bin Packing problem with only 3 items such that any pair of items
# fits into one bin but the 3 items do not. The objective function is to minimize the number
# of bins being used. Pricing is done by inspection over the 6 combinations of items (3 pairs and 3
# singletons). The root relaxation has 1.5 bins, each 0.5 corresponding to a bin with one
# of the possible pairs of items. Coluna is able to solve this instance by branching on the
# number of bins but the limit one on the number of nodes prevents it to be solved without
# cuts. Every subproblem solution s has a custom data with the number of items in the bin,
# given by length(s). The custom cut used to cut the fractional solution is
#                 `sum(λ_s for s in sols if length(s) >= 2) <= 1`
# where sols is the set of possible combinations of items in a bin, meaning that there cannot be more than one bin with more than two items in it. 

# We define the dependencies:

using JuMP, BlockDecomposition, Coluna, GLPK;

# TODO to comment

struct MyCustomVarData <: BlockDecomposition.AbstractCustomData
    nb_items::Int
end

struct MyCustomCutData <: BlockDecomposition.AbstractCustomData
    min_items::Int
end

# Compute the coefficient of the column taking into account the custom variables and cuts. 

function Coluna.MathProg.computecoeff(
    ::Coluna.MathProg.Variable, var_custom_data::MyCustomVarData,
    ::Coluna.MathProg.Constraint, constr_custom_data::MyCustomCutData
)
    return (var_custom_data.nb_items >= constr_custom_data.min_items) ? 1.0 : 0.0
end

# Build the model: 

function build_toy_model(optimizer)
    toy = BlockModel(optimizer)
    I = [1, 2, 3]
    @axis(B, [1])
    @variable(toy, y[b in B] >= 0, Int)
    @variable(toy, x[b in B, i in I], Bin)
    @constraint(toy, sp[i in I], sum(x[b,i] for b in B) == 1)
    @objective(toy, Min, sum(y[b] for b in B))
    @dantzig_wolfe_decomposition(toy, dec, B)

    return toy, x, y, dec
end



coluna = JuMP.optimizer_with_attributes(
    Coluna.Optimizer,
    "default_optimizer" => GLPK.Optimizer,
    "params" => Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm(
            conqueralg = Coluna.Algorithm.ColCutGenConquer(
                stages = [Coluna.Algorithm.ColumnGeneration(
                            pricing_prob_solve_alg = Coluna.Algorithm.SolveIpForm(
                                optimizer_id = 1
                            ))
                            ]
            ),
            maxnumnodes = 1
        )
    )
)

model, x, y, dec = build_toy_model(coluna)
BlockDecomposition.customvars!(model, MyCustomVarData)
BlockDecomposition.customconstrs!(model, MyCustomCutData)

# Adapt the pricing callback to take into account the changes on the reduced cost caused by the custom cuts. 

function my_pricing_callback(cbdata)
    # Get the reduced costs of the original variables
    I = [1, 2, 3]
    b = BlockDecomposition.callback_spid(cbdata, model)
    rc_y = BlockDecomposition.callback_reduced_cost(cbdata, y[b])
    rc_x = [BlockDecomposition.callback_reduced_cost(cbdata, x[b, i]) for i in I]
    # Get the dual values of the custom cuts
    custduals = Tuple{Int, Float64}[]
    for (_, constr) in Coluna.MathProg.getconstrs(cbdata.form.parent_formulation)
        if typeof(constr.custom_data) == MyCustomCutData
            push!(custduals, (
                constr.custom_data.min_items,
                Coluna.MathProg.getcurincval(cbdata.form.parent_formulation, constr)
            ))
        end
    end
    # check all possible solutions
    sols = [[1], [2], [3], [1, 2], [1, 3], [2, 3]]
    best_s = Int[]
    best_rc = Inf
    for s in sols
        rc_s = rc_y + sum(rc_x[i] for i in s)
        if !isempty(custduals)
            rc_s -= sum((length(s) >= minits) ? dual : 0.0 for (minits, dual) in custduals)
        end
        if rc_s < best_rc
            best_rc = rc_s
            best_s = s
        end
    end
    # build the best one and submit
    solcost = best_rc 
    solvars = JuMP.VariableRef[]
    solvarvals = Float64[]
    for i in best_s
        push!(solvars, x[b, i])
        push!(solvarvals, 1.0)
    end
    push!(solvars, y[b])
    push!(solvarvals, 1.0)
    # Submit the solution
    MOI.submit(
        model, BlockDecomposition.PricingSolution(cbdata), solcost, solvars, solvarvals,
        MyCustomVarData(length(best_s))
    )
    MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), solcost)
    return
end

subproblems = BlockDecomposition.getsubproblems(dec)
BlockDecomposition.specify!.(
    subproblems, lower_multiplicity = 0, upper_multiplicity = 3,
    solver = my_pricing_callback
)

# If the incumbent solution violates the custom cut `sum(λ_s for s in sols if length(s) >= 2) <= 1`, the cut is added to the model. 
function custom_cut_sep(cbdata)
    # compute the constraint violation
    viol = -1.0
    for (varid, varval) in cbdata.orig_sol
        var = Coluna.MathProg.getvar(cbdata.form, varid)
        if var.custom_data !== nothing
            if var.custom_data.nb_items >= 2
                viol += varval
            end
        end
    end
    # add the cut (at most one variable with 2 or more of the 3 items) if violated
    if viol > 0.001
        MOI.submit(
            model, MOI.UserCut(cbdata),
            JuMP.ScalarConstraint(JuMP.AffExpr(0.0), MOI.LessThan(1.0)), MyCustomCutData(2)
        )
    end
    return
end 

MOI.set(model, MOI.UserCutCallback(), custom_cut_sep)
JuMP.optimize!(model)

@test JuMP.termination_status(model) == MOI.OPTIMAL
