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

# Compute the coefficient of the added column. 

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

# Adapt the pricing callback to take into account the changes on the computation of the reduced cost induced by the custom cut. 

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

""" Output:

valid_lagr_bound = -29997.0
  <it=  1> <et=13.22> <mst= 2.30> <sp= 2.00> <cols= 1> <al= 0.00> <DB=-29997.0000> <mlp=30000.0000> <PB=Inf>
*********************
*********************
valid_lagr_bound = -49996.0
  <it=  2> <et=13.55> <mst= 0.08> <sp= 0.00> <cols= 1> <al= 0.00> <DB=-29997.0000> <mlp=10001.0000> <PB=Inf>
*********************
*********************
valid_lagr_bound = -49996.0
  <it=  3> <et=13.55> <mst= 0.00> <sp= 0.00> <cols= 1> <al= 0.00> <DB=-29997.0000> <mlp=10001.0000> <PB=Inf>
*********************
*********************
valid_lagr_bound = 1.5
  <it=  4> <et=13.55> <mst= 0.00> <sp= 0.00> <cols= 0> <al= 0.00> <DB=    1.5000> <mlp=    1.5000> <PB=Inf>
[ Info: Column generation algorithm has converged.
Robust cut separation callback adds 0 new essential cuts and 1 new facultative cuts.
avg. viol. = 0.00, max. viol. = 0.00, zero viol. = 1.
*********************
*********************
valid_lagr_bound = -9997.0
  <it=  1> <et=14.26> <mst= 0.01> <sp= 0.01> <cols= 1> <al= 0.00> <DB=    1.5000> <mlp= 5001.5000> <PB=Inf>
Robust cut separation callback adds 0 new essential cuts and 0 new facultative cuts.
*********************
*********************
valid_lagr_bound = -29995.0
  <it=  2> <et=14.26> <mst= 0.00> <sp= 0.00> <cols= 1> <al= 0.00> <DB=    1.5000> <mlp=    2.0000> <PB=2.0000>
*********************
*********************
valid_lagr_bound = -29995.0
  <it=  3> <et=14.26> <mst= 0.00> <sp= 0.00> <cols= 1> <al= 0.00> <DB=    1.5000> <mlp=    2.0000> <PB=2.0000>
*********************
*********************
valid_lagr_bound = 2.0
  <it=  4> <et=14.26> <mst= 0.00> <sp= 0.00> <cols= 0> <al= 0.00> <DB=    2.0000> <mlp=    2.0000> <PB=2.0000>
[ Info: Dual bound reached primal bound.
 ──────────────────────────────────────────────────────────────────────────────────────
                                              Time                    Allocations      
                                     ───────────────────────   ────────────────────────
          Tot / % measured:                209s /   6.9%           4.02GiB /  43.5%    

 Section                     ncalls     time    %tot     avg     alloc    %tot      avg
 ──────────────────────────────────────────────────────────────────────────────────────
 Coluna                           1    14.5s  100.0%   14.5s   1.75GiB  100.0%  1.75GiB
   SolveLpForm                    8    1.82s   12.6%   228ms   48.6MiB    2.7%  6.07MiB
   Update reduced costs           8    173ms    1.2%  21.6ms   2.78MiB    0.2%   356KiB
   Cleanup columns                8    157ms    1.1%  19.6ms   3.66MiB    0.2%   469KiB
   Update Lagrangian bound        8    128ms    0.9%  16.0ms   4.83MiB    0.3%   618KiB
   Smoothing update               8   93.8ms    0.6%  11.7ms   10.5MiB    0.6%  1.31MiB
 ──────────────────────────────────────────────────────────────────────────────────────
[ Info: Terminated
[ Info: Primal bound: 2.0
[ Info: Dual bound: 2.0

"""

# We see on the output that the algorithm has converged a first time before a cut is added. Coluna then starts a new iteration taking into account the cut. 
# We notice here an improvement of the value of the dual bound: before the cut, we converge towards 1.5. After the cut, we reach 2.0. 


