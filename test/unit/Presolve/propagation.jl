# Propagation between formulations of Dantzig-Wolf reformulation.
# In the following tests, we consider that the variables have the possible following duties

# Original formulation:
# variable:
# - OriginalVar
# constraint:
# - OriginalConstr

# Master:
# variable:
# - MasterRepPricingVar
# - MasterPureVar
# - MasterCol
# - MasterArtVar
# constraint:
# - MasterPureConstr
# - MasterMixedConstr
# - MasterConvexityConstr

# Pricing subproblems:
# variable:
# - DwSpPricingVar
# - DwSpSetupVar
# constraint:
# - DwSpPureConstr

## Helpers

function _presolve_propagation_vars(form, var_descriptions)
    vars = Tuple{String, Coluna.MathProg.Variable}[]
    for (name, duty, cost, lb, ub, id) in var_descriptions
        if isnothing(id)
            var = Coluna.MathProg.setvar!(form, name, duty, cost = cost, lb = lb, ub = ub)
        else
            id_of_clone = ClMP.VarId(id; duty = duty)
            var = Coluna.MathProg.setvar!(form, name, duty; id = id_of_clone, cost = cost, lb = lb, ub = ub) 
        end
        push!(vars, (name, var))
    end
    return vars
end

function _presolve_propagation_constrs(form, constr_descriptions)
    constrs = Tuple{String, Coluna.MathProg.Constraint}[]
    for (name, duty, rhs, sense, id) in constr_descriptions
        if isnothing(id)
            constr = Coluna.MathProg.setconstr!(form, name, duty, rhs = rhs, sense = sense)
        else
            id_of_clone = ClMP.ConstrId(id; duty = duty)
            constr = Coluna.MathProg.setconstr!(form, name, duty; id = id_of_clone, rhs = rhs, sense = sense)
        end
        push!(constrs, (name, constr))
    end
    return constrs
end

function _mathprog_formulation!(env, form_duty, var_descriptions, constr_descriptions)
    form = Coluna.MathProg.create_formulation!(env, form_duty)

    vars = _presolve_propagation_vars(form, var_descriptions)
    constrs = _presolve_propagation_constrs(form, constr_descriptions)

    name_to_vars = Dict(name => var for (name, var) in vars)
    name_to_constrs = Dict(name => constr for (name, constr) in constrs)
    return form, name_to_vars, name_to_constrs
end

function _presolve_formulation(var_names, constr_names, matrix, form, name_to_vars, name_to_constrs; lm=1, um=1)
    rhs = [Coluna.MathProg.getcurrhs(form, name_to_constrs[name]) for name in constr_names]
    sense = [Coluna.MathProg.getcursense(form, name_to_constrs[name]) for name in constr_names]
    lbs = [Coluna.MathProg.getcurlb(form, name_to_vars[name]) for name in var_names]
    ubs = [Coluna.MathProg.getcurub(form, name_to_vars[name]) for name in var_names]
    partial_solution = zeros(Float64, length(lbs))

    form_repr = Coluna.Algorithm.PresolveFormRepr(
        matrix,
        rhs,
        sense,
        lbs, 
        ubs,
        partial_solution,
        lm,
        um
    )

    col_to_var = [name_to_vars[name] for name in var_names]
    row_to_constr = [name_to_constrs[name] for name in constr_names]
    var_to_col = Dict(ClMP.getid(name_to_vars[name]) => i for (i, name) in enumerate(var_names))
    constr_to_row = Dict(ClMP.getid(name_to_constrs[name]) => i for (i, name) in enumerate(constr_names))

    presolve_form = Coluna.Algorithm.PresolveFormulation(
        col_to_var,
        row_to_constr,
        var_to_col,
        constr_to_row,
        form_repr,
        Coluna.MathProg.ConstrId[],
        Dict{Coluna.MathProg.VarId, Float64}()
    )
    return presolve_form
end

############################################################################################
# Constraint removing propagation.
############################################################################################

## OriginalConstr -> MasterMixedConstr
## OriginalConstr -> MasterPureConstr
function test_constr_removing_propagation_from_original_to_master()
    # Original
    # max x + y
    # s.t. x + y <= 1
    #      x + y <= 3 (remove)
    #      0 <= x <= 1
    #      0 <= y <= 1

    # Master
    # max _x + _y + MC1 + 1000a
    # s.t. _x + _y + MC1 + a <= 1
    #      _x + _y + MC1 + a <= 3 (remove by propagation)
    #      0 <= _x <= 1 (repr)
    #      0 <= _y <= 1 (repr)
    #      0 <= MC1 <= 1
    #      a >= 0

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    orig_form, orig_name_to_var, orig_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.Original(),
        [
            # name, duty, cost, lb, ub, id
            ("x", Coluna.MathProg.OriginalVar, 1.0, 0.0, 1.0, nothing),
            ("y", Coluna.MathProg.OriginalVar, 1.0, 0.0, 1.0, nothing)
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.OriginalConstr, 1.0, ClMP.Less, nothing),
            ("c2", Coluna.MathProg.OriginalConstr, 3.0, ClMP.Less, nothing)
        ]
    )

    orig_presolve_form = _presolve_formulation(
        ["x", "y"], ["c1", "c2"], [1 1; 1 1], orig_form, orig_name_to_var, orig_name_to_constr
    )

    master_form, master_name_to_var, master_constr_to_var = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("_x", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["x"])),
            ("_y", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["y"])),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("a", Coluna.MathProg.MasterArtVar, 1000.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, lb, ub, id
            ("c1", Coluna.MathProg.MasterPureConstr, 1.0, ClMP.Less, Coluna.Algorithm.getid(orig_name_to_constr["c1"])),
            ("c2", Coluna.MathProg.MasterPureConstr, 3.0, ClMP.Less, Coluna.Algorithm.getid(orig_name_to_constr["c2"]))
        ]
    )

    master_repr_presolve_form = _presolve_formulation(
        ["_x", "_y"], ["c1", "c2"], [1 1; 1 1], master_form, master_name_to_var, master_constr_to_var
    )

    # Run the presolve row deactivation on the original formulation.
    result = Coluna.Algorithm.rows_to_deactivate!(orig_presolve_form.form)

    # Test if the constraint was deactivated.
    @test result == [2] # remove row 2 of original formulation

    # Propagate


    # Test propagation
end
register!(unit_tests, "presolve_propagation", test_constr_removing_propagation_from_original_to_master)

## OriginalConstr -> DwSpPureConstr
function test_constr_removing_propagation_from_original_to_subproblem()
    # Original
    # max x1 + x2 + y1 + y2
    # s.t. x1 + x2 + y1 + y2 <= 2
    #      x1 + x2 <= 2  (remove)
    #      y1 + y2 <= 1
    #      0 <= x1, x2 <= 1
    #      0 <= y1, y2 <= 2
    
    # Subproblems
    # max x1 + x2
    # s.t. x1 + x2 <= 2 (remove by propagation)
    #      0 <= x1, x2 <= 1

    # max y1 + y2
    # s.t. y1 + y2 <= 1
    #      0 <= y1, y2 <= 1

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    orig_form, orig_name_to_var, orig_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.Original(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.OriginalVar, 1.0, 0.0, 1.0, nothing),
            ("x2", Coluna.MathProg.OriginalVar, 1.0, 0.0, 1.0, nothing),
            ("y1", Coluna.MathProg.OriginalVar, 1.0, 0.0, 2.0, nothing),
            ("y2", Coluna.MathProg.OriginalVar, 1.0, 0.0, 2.0, nothing)
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.OriginalConstr, 3.0, ClMP.Less, nothing),
            ("c2", Coluna.MathProg.OriginalConstr, 2.0, ClMP.Less, nothing),
            ("c3", Coluna.MathProg.OriginalConstr, 1.0, ClMP.Less, nothing)
        ]
    )

    orig_presolve_form = _presolve_formulation(
        ["x1", "x2", "y1", "y2"], ["c1", "c2", "c3"], [1 1 1 1; 1 1 0 0; 0 0 1 1], orig_form, orig_name_to_var, orig_name_to_constr
    )

    sp1_form, sp1_name_to_var, sp1_name_to_constr = _mathprog_formulation!(
        env, 
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["x1"])),
            ("x2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["x2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c2", Coluna.MathProg.DwSpPureConstr, 2.0, ClMP.Less, Coluna.Algorithm.getid(orig_name_to_constr["c2"]))
        ],
    )

    sp1_presolve_form = _presolve_formulation(
        ["x1", "x2"], ["c2"], [1 1;], sp1_form, sp1_name_to_var, sp1_name_to_constr
    )

    sp2_form, sp2_name_to_var, sp2_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("y1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["y1"])),
            ("y2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["y2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c3", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Less, Coluna.Algorithm.getid(orig_name_to_constr["c3"]))
        ],
    )

    sp2_presolve_form = _presolve_formulation(
        ["y1", "y2"], ["c3"], [1 1;], sp2_form, sp2_name_to_var, sp2_name_to_constr
    )
       
    # Run the presolve row deactivation on the original formulation.
    result = Coluna.Algorithm.rows_to_deactivate!(orig_presolve_form.form)

    # Test if the constraint was deactivated.
    @test result == [2] # remove row 2 of original formulation
end
register!(unit_tests, "presolve_propagation", test_constr_removing_propagation_from_original_to_subproblem)

############################################################################################
# Variable bound propagation.
############################################################################################

## OriginalVar -> DwSpPricingVar (mapping exists)
## otherwise no propagation
function test_var_bound_propagation_from_original_to_subproblem()
    # Original
    # min x1 + x2 + y1 + y2 
    # s.t. x1 + x2 + y1 + y2 >= 2
    #      x1 + x2 >= 1
    #      y1 + y2 >= 1
    #      0 <= x1 <= 0.5
    #      0 <= y1 <= 0.7
    #      x2 >= 0  ( --> x2 >= 0.5) because row 2
    #      y2 >= 0  ( --> y2 >= 0.3) because row 3

    # Master
    # min _x1 + _x2 + _y1 + _y2 + MC1 + 2MC2 + 1000a 
    # s.t. _x1 + _x2 + _y1 + _y2 + MC1 + MC2 + a >= 2
    #      0 <= _x1, _x2 <= 1 (repr)
    #      0 <= _y1, _y2 <= 1 (repr)
    #      0 <= MC1 <= 1
    #      0 <= MC2 <= 1
    #      a >= 0

    # Subproblems
    # min x1 + x2
    # s.t. x1 + x2 >= 1
    #      0 <= x1 <= 0.5 
    #      x2 >= 0 ( --> x2 >= 0.5 by propagation)

    # min y1 + y2
    # s.t. y1 + y2 >= 1
    #      0 <= y1 <= 0.7
    #      y2 >= 0 ( --> y2 >= 0.3 by propagation)

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    orig_form, orig_name_to_var, orig_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.Original(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.OriginalVar, 1.0, 0.0, 0.5, nothing),
            ("x2", Coluna.MathProg.OriginalVar, 1.0, 0.0, Inf, nothing),
            ("y1", Coluna.MathProg.OriginalVar, 1.0, 0.0, 0.7, nothing),
            ("y2", Coluna.MathProg.OriginalVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.OriginalConstr, 2.0, ClMP.Greater, nothing),
            ("c2", Coluna.MathProg.OriginalConstr, 1.0, ClMP.Greater, nothing),
            ("c3", Coluna.MathProg.OriginalConstr, 1.0, ClMP.Greater, nothing)
        ]
    )

    orig_presolve_form = _presolve_formulation(
        ["x1", "x2", "y1", "y2"], ["c1", "c2", "c3"], [1 1 1 1; 1 1 0 0; 0 0 1 1], orig_form, orig_name_to_var, orig_name_to_constr
    )

    sp1_form, sp1_name_to_var, sp1_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 0.5, Coluna.Algorithm.getid(orig_name_to_var["x1"]))
            ("x2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, Inf, Coluna.Algorithm.getid(orig_name_to_var["x2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c2", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Greater, Coluna.Algorithm.getid(orig_name_to_constr["c2"]))
        ]
    )

    sp1_presolve_form = _presolve_formulation(
        ["x1", "x2"], ["c2"], [1 1;], sp1_form, sp1_name_to_var, sp1_name_to_constr
    )

    sp2_form, sp2_name_to_var, sp2_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("y1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 0.7, Coluna.Algorithm.getid(orig_name_to_var["y1"]))
            ("y2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, Inf, Coluna.Algorithm.getid(orig_name_to_var["y2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c3", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Greater, Coluna.Algorithm.getid(orig_name_to_constr["c3"]))
        ]
    )

    sp2_presolve_form = _presolve_formulation(
        ["y1", "y2"], ["c3"], [1 1;], sp2_form, sp2_name_to_var, sp2_name_to_constr
    )

    # Run the presolve bounds tightening on the original formulation.
    result = Coluna.Algorithm.bounds_tightening(orig_presolve_form.form)
    @test result[2] == (0.5, true, Inf, false)
    @test result[4] == (0.3, true, Inf, false)
end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_original_to_subproblem)

## OriginalVar -> MasterRepPricingVar (mapping exists)
## OriginalVar -> MasterPureVar (mapping exists)
## otherwise no propagation
function test_var_bound_propagation_from_original_to_master()
    # Original
    # max x + y
    # s.t. x + y <= 1
    #      0 <= x <= 0.5
    #      y >= 0 ( --> 0 <= y <= 1 by propagation)

    # Master
    # max _x + _y + MC1 + 1000a
    # s.t. _x + _y + MC1 + a <= 1
    #      0 <= _x <= 0.5 (repr)
    #      _y >= 0 (repr) ( --> 0 <= y <= 1 by propagation)
    #      0 <= MC1 <= 1
    #      a >= 0

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    orig_form, orig_name_to_var, orig_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.Original(),
        [
            # name, duty, cost, lb, ub, id
            ("x", Coluna.MathProg.OriginalVar, 1.0, 0.0, 0.5, nothing),
            ("y", Coluna.MathProg.OriginalVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.OriginalConstr, 1.0, ClMP.Less, nothing)
        ]
    )

    orig_presolve_form = _presolve_formulation(
        ["x", "y"], ["c1"], [1 1;], orig_form, orig_name_to_var, orig_name_to_constr
    )

    master_form, master_name_to_var, master_constr_to_var = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("_x", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.5, Coluna.Algorithm.getid(orig_name_to_var["x"])),
            ("_y", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, Inf, Coluna.Algorithm.getid(orig_name_to_var["y"])),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("a", Coluna.MathProg.MasterArtVar, 1000.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, lb, ub, id
            ("c1", Coluna.MathProg.MasterPureConstr, 1.0, ClMP.Less, Coluna.Algorithm.getid(orig_name_to_constr["c1"]))
        ],
    )

    master_repr_presolve_form = _presolve_formulation(
        ["_x", "_y"], ["c1"], [1 1;], master_form, master_name_to_var, master_constr_to_var
    )

    # Run the presolve bounds tightening on the original formulation.
    result = Coluna.Algorithm.bounds_tightening(orig_presolve_form.form)
    @test result[2] == (0.0, false, 1.0, true)
end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_original_to_master)

## MasterRepPricingVar -> DwSpPricingVar (mapping exists)
## otherwise no propagation
function test_var_bound_propagation_from_master_to_subproblem()
    # Master
    # min x1 + x2 + y1 + y2 + 2MC1 + MC2 + a
    # s.t. x1 + x2 + y1 + y2 + MC1 + 2MC2 + a >= 2
    #      0 <= x1 <= 0.5
    #      0 <= x2 <= 0.5
    #      0 <= y1 <= 0.7
    #      y2 >= 0 ( --> y2 >= 0.3 )

    # Subproblems
    # min x1 + x2
    # s.t. x1 + x2 >= 1
    #      0 <= x1 <= 0.5 
    #      0 <= x2 <= 0.5

    # min y1 + y2
    # s.t. y1 + y2 >= 1
    #      0 <= y1 <= 0.7
    #      y2 >= 0 ( --> y2 >= 0.3 by propagation)

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    master_form, master_name_to_var, master_constr_to_var = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.5, nothing),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.5, nothing),
            ("y1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.7, nothing),
            ("y2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, Inf, nothing),
            ("MC1", Coluna.MathProg.MasterCol, 2.0, 0.0, 1.0, nothing),
            ("MC2", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("a", Coluna.MathProg.MasterArtVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, lb, ub, id
            ("c1", Coluna.MathProg.MasterPureConstr, 2.0, ClMP.Greater, nothing)
        ]
    )

    master_repr_presolve_form = _presolve_formulation(
        ["x1", "x2", "y1", "y2"], ["c1"], [1 1 1 1;], master_form, master_name_to_var, master_constr_to_var
    )

    master_presolve_form = _presolve_formulation(
        ["MC1", "MC2", "a"], ["c1"], [1 1 1;], master_form, master_name_to_var, master_constr_to_var
    )

    sp1_form, sp1_name_to_var, sp1_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 0.5, Coluna.Algorithm.getid(master_name_to_var["x1"]))
            ("x2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, Inf, Coluna.Algorithm.getid(master_name_to_var["x2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Greater, Coluna.Algorithm.getid(master_constr_to_var["c1"]))
        ],
    )

    sp1_presolve_form = _presolve_formulation(
        ["x1", "x2"], ["c1"], [1 1;], sp1_form, sp1_name_to_var, sp1_name_to_constr
    )

    sp2_form, sp2_name_to_var, sp2_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("y1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 0.7, Coluna.Algorithm.getid(master_name_to_var["y1"]))
            ("y2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, Inf, Coluna.Algorithm.getid(master_name_to_var["y2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Greater, Coluna.Algorithm.getid(master_constr_to_var["c1"]))
        ],
    )

    sp2_presolve_form = _presolve_formulation(
        ["y1", "y2"], ["c1"], [1 1;], sp2_form, sp2_name_to_var, sp2_name_to_constr
    )

    # Run the presolve bounds tightening on the master formulation.
    result = Coluna.Algorithm.bounds_tightening(master_repr_presolve_form.form)
    @test result[4] == (0.3, true, Inf, false)
end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_master_to_subproblem)

## DwSpPricingVar -> MasterRepPricingVar (mapping exists)
## otherwise no propagation
function test_var_bound_propagation_from_subproblem_to_master()
    # Subproblems
    # min x1 + x2
    # s.t. x1 + x2 >= 1
    #     0 <= x1 <= 0.5
    #     x2 >= 0 ( --> x2 >= 0.5)

    # min y1 + y2
    # s.t. y1 + y2 >= 1
    #    0 <= y1 <= 0.7
    #    y2 >= 0 ( --> y2 >= 0.3)

    # Master
    # min x1 + x2 + y1 + y2 + MC1 + MC2 + a 
    # s.t. x1 + x2 + y1 + y2 + MC1 + MC2 + a >= 2
    #    0 <= x1 <= 0.5
    #    0 <= y1 <= 0.7
    #    x2 >= 0 ( --> x2 >= 0.5 by propagation)
    #    y2 >= 0 ( --> y2 >= 0.3 by propagation)
    #    0 <= MC1 <= 1
    #    0 <= MC2 <= 1
    #    a >= 0

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    sp1_form, sp1_name_to_var, sp1_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 0.5, nothing)
            ("x2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Greater, nothing)
        ]
    )

    sp1_presolve_form = _presolve_formulation(
        ["x1", "x2"], ["c1"], [1 1;], sp1_form, sp1_name_to_var, sp1_name_to_constr
    )
    
    sp2_form, sp2_name_to_var, sp2_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("y1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 0.7, nothing)
            ("y2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Greater, nothing)
        ]
    )

    sp2_presolve_form = _presolve_formulation(
        ["y1", "y2"], ["c1"], [1 1;], sp2_form, sp2_name_to_var, sp2_name_to_constr
    )

    master_form, master_name_to_var, master_constr_to_var = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.5, Coluna.Algorithm.getid(sp1_name_to_var["x1"])),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, Inf, Coluna.Algorithm.getid(sp1_name_to_var["x2"])),
            ("y1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.7, Coluna.Algorithm.getid(sp2_name_to_var["y1"])),
            ("y2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, Inf, Coluna.Algorithm.getid(sp2_name_to_var["y2"])),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC2", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("a", Coluna.MathProg.MasterArtVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, lb, ub, id
            ("c1", Coluna.MathProg.MasterPureConstr, 2.0, ClMP.Greater, nothing)
        ]
    )

    master_repr_presolve_form = _presolve_formulation(
        ["x1", "x2", "y1", "y2"], ["c1"], [1 1 1 1;], master_form, master_name_to_var, master_constr_to_var
    )

    master_presolve_form = _presolve_formulation(
        ["MC1", "MC2", "a"], ["c1"], [1 1 1;], master_form, master_name_to_var, master_constr_to_var
    )

    # Run the presolve bounds tightening on the original formulation.
    result = Coluna.Algorithm.bounds_tightening(sp1_presolve_form.form)
    @test result[2] == (0.5, true, Inf, false)

    result = Coluna.Algorithm.bounds_tightening(sp2_presolve_form.form)
    @test result[2] == (0.3, true, Inf, false)
end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_subproblem_to_master)

############################################################################################
# Var fixing propagation.
############################################################################################

function test_var_fixing_propagation_within_formulation1()
    # Original
    # max x + y + z
    # s.t. 2x + y + z <= 15
    #      x == 2
    #      y >= 0
    #      z >= 0

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    orig_form, orig_name_to_var, orig_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.Original(),
        [
            # name, duty, cost, lb, ub, id
            ("x", Coluna.MathProg.OriginalVar, 1.0, 2.0, 2.0, nothing),
            ("y", Coluna.MathProg.OriginalVar, 1.0, 0.0, Inf, nothing),
            ("z", Coluna.MathProg.OriginalVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.OriginalConstr, 15.0, ClMP.Less, nothing)
        ],
    )

    orig_presolve_form = _presolve_formulation(
        ["x", "y", "z"], ["c1"], [2 1 1;], orig_form, orig_name_to_var, orig_name_to_constr
    )

    bounds_result = Coluna.Algorithm.bounds_tightening(orig_presolve_form.form)
    @test bounds_result[2] == (0.0, false, 11.0, true)
    @test bounds_result[3] == (0.0, false, 11.0, true)

    new_form = Coluna.Algorithm.propagate_in_presolve_form(
        orig_presolve_form,
        Int[],
        bounds_result
    )

    @test new_form.form.col_major_coef_matrix == [1 1;]
    @test new_form.form.rhs == [11.0]
    @test new_form.form.sense == [ClMP.Less]
    @test new_form.form.lbs == [0.0, 0.0]
    @test new_form.form.ubs == [11.0, 11.0]

    @test new_form.col_to_var == [orig_name_to_var["y"], orig_name_to_var["z"]]
    @test new_form.row_to_constr == [orig_name_to_constr["c1"]]

    @test new_form.var_to_col[ClMP.getid(orig_name_to_var["y"])] == 1
    @test new_form.var_to_col[ClMP.getid(orig_name_to_var["z"])] == 2
    @test length(new_form.var_to_col) == 2

    @test new_form.constr_to_row[ClMP.getid(orig_name_to_constr["c1"])] == 1
    @test length(new_form.constr_to_row) == 1

    @test length(new_form.deactivated_constrs) == 0

    @test new_form.fixed_vars[ClMP.getid(orig_name_to_var["x"])] == 2.0
    @test length(new_form.fixed_vars) == 1
end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_within_formulation1)

function test_var_fixing_propagation_within_formulation2()
    # Original
    # max x + y + z
    # s.t. 2x + y + z >= 15 # test with rhs = 1 ==> bug
    #      x == 4
    #      y >= 0
    #      z >= 0

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    orig_form, orig_name_to_var, orig_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.Original(),
        [
            # name, duty, cost, lb, ub, id
            ("x", Coluna.MathProg.OriginalVar, 1.0, 4.0, 4.0, nothing),
            ("y", Coluna.MathProg.OriginalVar, 1.0, 0.0, Inf, nothing),
            ("z", Coluna.MathProg.OriginalVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.OriginalConstr, 15.0, ClMP.Greater, nothing)
        ],
    )

    orig_presolve_form = _presolve_formulation(
        ["x", "y", "z"], ["c1"], [2 1 1;], orig_form, orig_name_to_var, orig_name_to_constr
    )

    bounds_result = Coluna.Algorithm.bounds_tightening(orig_presolve_form.form)
    @test isempty(bounds_result)

    new_form = Coluna.Algorithm.propagate_in_presolve_form(
        orig_presolve_form,
        Int[],
        #result,
        bounds_result
    )

    @test new_form.form.col_major_coef_matrix == [1 1;]
    @test new_form.form.rhs == [15.0 - 8.0]
    @test new_form.form.sense == [ClMP.Greater]
    @test new_form.form.lbs == [0.0, 0.0]
    @test new_form.form.ubs == [Inf, Inf]

    @test new_form.col_to_var == [orig_name_to_var["y"], orig_name_to_var["z"]]
    @test new_form.row_to_constr == [orig_name_to_constr["c1"]]

    @test new_form.var_to_col[ClMP.getid(orig_name_to_var["y"])] == 1
    @test new_form.var_to_col[ClMP.getid(orig_name_to_var["z"])] == 2
    @test length(new_form.var_to_col) == 2

    @test new_form.constr_to_row[ClMP.getid(orig_name_to_constr["c1"])] == 1
    @test length(new_form.constr_to_row) == 1

    @test length(new_form.deactivated_constrs) == 0

    @test new_form.fixed_vars[ClMP.getid(orig_name_to_var["x"])] == 4.0
    @test length(new_form.fixed_vars) == 1
end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_within_formulation2)

function test_var_fixing_propagation_within_formulation3()
    # Original
    # max x + y + z
    # s.t. -2x + y + z >= 150
    #      -x  + y + z <= 600
    #      x == 10
    #      y >= 0
    #      z >= 0

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    orig_form, orig_name_to_var, orig_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.Original(),
        [
            # name, duty, cost, lb, ub, id
            ("x", Coluna.MathProg.OriginalVar, 1.0, 10.0, 10.0, nothing),
            ("y", Coluna.MathProg.OriginalVar, 1.0, 0.0, Inf, nothing),
            ("z", Coluna.MathProg.OriginalVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.OriginalConstr, 150.0, ClMP.Greater, nothing),
            ("c2", Coluna.MathProg.OriginalConstr, 600.0, ClMP.Less, nothing)
        ],
    )

    orig_presolve_form = _presolve_formulation(
        ["x", "y", "z"], ["c1", "c2"], [-2 1 1; -1 1 1;], orig_form, orig_name_to_var, orig_name_to_constr
    )

    bounds_result = Coluna.Algorithm.bounds_tightening(orig_presolve_form.form)
    @test bounds_result[2] == (0.0, false, 610.0, true)
    @test bounds_result[3] == (0.0, false, 610.0, true)
    @test length(bounds_result) == 2    

    new_form = Coluna.Algorithm.propagate_in_presolve_form(
        orig_presolve_form,
        Int[],
        bounds_result
    )

    @test new_form.form.col_major_coef_matrix == [1 1; 1 1;]
    @test new_form.form.rhs == [150.0 + 20, 600.0 + 10]
    @test new_form.form.sense == [ClMP.Greater, ClMP.Less]
    @test new_form.form.lbs == [0.0, 0.0]
    @test new_form.form.ubs == [610.0, 610.0]

    @test new_form.col_to_var == [orig_name_to_var["y"], orig_name_to_var["z"]]
    @test new_form.row_to_constr == [orig_name_to_constr["c1"], orig_name_to_constr["c2"]]

    @test new_form.var_to_col[ClMP.getid(orig_name_to_var["y"])] == 1
    @test new_form.var_to_col[ClMP.getid(orig_name_to_var["z"])] == 2
    @test length(new_form.var_to_col) == 2

    @test new_form.constr_to_row[ClMP.getid(orig_name_to_constr["c1"])] == 1
    @test new_form.constr_to_row[ClMP.getid(orig_name_to_constr["c2"])] == 2
    @test length(new_form.constr_to_row) == 2

    @test length(new_form.deactivated_constrs) == 0

    @test new_form.fixed_vars[ClMP.getid(orig_name_to_var["x"])] == 10.0
    @test length(new_form.fixed_vars) == 1
end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_within_formulation3)


## OriginalVar -> DwSpPricingVar (mapping exists)
## otherwise no propagation
function test_var_fixing_propagation_from_original_to_subproblem()

end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_original_to_subproblem)

## OriginalVar -> MasterRepPricingVar (mapping exists)
## OriginalVar -> MasterPureVar (mapping exists)
## otherwise no propagation
function test_var_fixing_propagation_from_original_to_master()
    # Original
    # max x + y
    # s.t. x + y <= 1
    #      0 <= x <= 1 (--> x == 0 by bounds tightening)
    #      y == 1

    # Master
    # max _x + _y + MC1 + MC2 + MC3 + MC4 + 10000a
    # s.t. _x + _y + MC1 + MC2 + MC3 + MC4 + a <= 1 ( --> _x + MC3 + MC4 + a <= 0)
    #      0 <= _x <= 0.5 (repr) (--> x = 0 b y propagation)
    #      _y >= 0 (repr) ( --> y == 1 by propagation )
    #      0 <= MC1 <= 1 ( --> MC1 == 0 by propagation )
    #      0 <= MC2 <= 1 ( --> MC2 == 0 by propagation )
    #      0 <= MC3 <= 1 ( --> MC3 == 1 by propagation )
    #      0 <= MC4 <= 1 ( --> MC4 == 0 by propagation )
    #      a >= 0

    # with:
    # - MC1 = [x = 1, y = 0] 
    # - MC2 = [x = 0, y = 0] 
    # - MC3 = [x = 0, y = 1] 
    # - MC4 = [x = 1, y = 1] (not suitable because x == 0)

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    orig_form, orig_name_to_var, orig_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.Original(),
        [
            # name, duty, cost, lb, ub, id
            ("x", Coluna.MathProg.OriginalVar, 1.0, 0.0, 0.5, nothing),
            ("y", Coluna.MathProg.OriginalVar, 1.0, 1.0, 1.0, nothing)
        ],
        [
            # name, duty, rhs, sense, id
            ("c1", Coluna.MathProg.OriginalConstr, 1.0, ClMP.Less, nothing)
        ],
    )

    orig_presolve_form = _presolve_formulation(
        ["x", "y"], ["c1"], [1 1;], orig_form, orig_name_to_var, orig_name_to_constr
    )

    master_form, master_name_to_var, master_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            ("_x", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.5, Coluna.Algorithm.getid(orig_name_to_var["x"])),
            ("_y", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, Inf, Coluna.Algorithm.getid(orig_name_to_var["y"])),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC2", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC3", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC4", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("a", Coluna.MathProg.MasterArtVar, 10000.0, 0.0, Inf, nothing)
        ],
        [
            ("c1", Coluna.MathProg.MasterPureConstr, 1.0, ClMP.Less, nothing)
        ]
    )

    master_repr_presolve_form = _presolve_formulation(
        ["_x", "_y"], ["c1"], [1 1;], master_form, master_name_to_var, master_name_to_constr
    )

    master_presolve_form = _presolve_formulation(
        ["MC1", "MC2", "MC3", "MC4", "a"], ["c1"], [1 1 1 1 1;], master_form, master_name_to_var, master_name_to_constr
    )

    # Run the presolve variable fixing on the original formulation.
    bounds_result = Coluna.Algorithm.bounds_tightening(orig_presolve_form.form)
    @test bounds_result[1] == (0, false, 0, true)
    @test length(bounds_result) == 1
end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_original_to_master)

## MasterColumns -> MasterRepPricingVar -> DwSpPricingVar
## otherwise no propagation
function test_var_fixing_propagation_from_master_to_subproblem1()
    # Master
    # min x1 + x2 + y1 + y2 + MC1 + MC2 + MC3 + MC4 + a 
    # s.t. 2x1 + 2x2 + 2y1 + 2y2 + 2MC1 + 2MC2 + 2MC3 + 2MC4 + a >= 4
    #    0 <= x1 <= 0 (repr) --> (fixing x1 == 0)
    #    0 <= x2 <= 1 (repr)
    #    0 <= y1 <= 1 (repr)
    #    1 <= y2 <= 1 (repr) --> (fixing y2 == 1)
    #    0 <= MC1 <= 1
    #    0 <= MC2 <= 1
    #    0 <= MC3 <= 1
    #    0 <= MC4 <= 1
    #    a >= 0

    # with:
    # - MC1 = [x1 = 0, x2 = 0]
    # - MC2 = [x1 = 1, x2 = 0] (--> fixing MC2 == 0 because x1 == 0 -- propagation)
    # - MC3 = [x1 = 0, x2 = 1]
    # - MC4 = [x1 = 1, x2 = 1] (--> fixing MC4 == 0 because x1 == 0 -- propagation)
    # - MC5 = [y1 = 0, y2 = 0] 
    # - MC6 = [y1 = 1, y2 = 0]
    # - MC7 = [y1 = 0, y2 = 1]
    # - MC8 = [y1 = 1, y2 = 1]

    # Subproblems
    # min x1 + x2
    # s.t. x1 + x2 >= 1
    #     0 <= x1 <= 1 --> (fixing x1 == 0 by propagation)
    #     0 <= x2 <= 1

    # min y1 + y2
    # s.t. y1 + y2 >= 1
    #    0 <= y1 <= 1
    #    0 <= y2 <= 1 (--> fixing y2 == 1 by propagation)

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    master_form, master_name_to_var, master_constr_to_var = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.0, nothing),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing),
            ("y1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing),
            ("y2", Coluna.MathProg.MasterRepPricingVar, 1.0, 1.0, 1.0, nothing),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC2", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC3", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC4", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("a", Coluna.MathProg.MasterArtVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, sense , id
            ("c1", Coluna.MathProg.MasterMixedConstr, 4.0, ClMP.Greater, nothing)
        ]
    )

    master_repr_presolve_form = _presolve_formulation(
        ["x1", "x2", "y1", "y2"],  ["c1"], [2 2 2 2;], master_form, master_name_to_var, master_constr_to_var
    )

    master_presolve_form = _presolve_formulation(
        ["MC1", "MC2", "MC3", "MC4", "a"], ["c1"], [2 2 2 2 1;], master_form, master_name_to_var, master_constr_to_var
    )

    sp1_form, sp1_name_to_var, sp1_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["x1"])),
            ("x2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["x2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c3", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Greater, nothing)
        ]
    )
     
    sp1_presolve_form = _presolve_formulation(
        ["x1", "x2"], ["c3"], [1 1;], sp1_form, sp1_name_to_var, sp1_name_to_constr
    )

    sp2_form, sp2_name_to_var, sp2_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("y1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["y1"])),
            ("y2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["y2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c4", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Greater, nothing)
        ]
    )

    sp2_presolve_form = _presolve_formulation(
        ["y1", "y2"], ["c4"], [1 1;], sp2_form, sp2_name_to_var, sp2_name_to_constr
    )

    # Run the presolve variable fixing on the original formulation.
    bounds_result = Coluna.Algorithm.bounds_tightening(master_repr_presolve_form.form)
    @test isempty(bounds_result)
    return
end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_master_to_subproblem1)

function test_var_fixing_propagation_from_master_to_subproblem2()
    # Master
    # min x1 + x2 + y1 + y2 + MC1 + MC2 + MC3 + MC4 a 
    # s.t. 2x1 + 2x2 + 2y1 + 2y2 + 2MC1 + 2MC2 + 2MC3 + 2MC4 + a >= 4
    #    0 <= x1 <= 0 (repr) --> (fixing x1 == 0)
    #    0 <= x2 <= 1 (repr)
    #    0 <= y1 <= 1 (repr)
    #    1 <= y2 <= 1 (repr) --> (fixing y2 == 1)
    #    0 <= MC1 <= 1
    #    0 <= MC2 <= 1
    #    0 <= MC3 <= 1
    #    0 <= MC4 <= 1
    #    a >= 0

    # with:
    # - MC1 = [x1 = 0, x2 = 0]
    # - MC2 = [x1 = 1, x2 = 0] (--> fixing MC2 == 0 because x1 == 0 -- propagation)
    # - MC3 = [x1 = 0, x2 = 1]
    # - MC4 = [x1 = 1, x2 = 1] (--> fixing MC4 == 0 because x1 == 0 -- propagation)
    # - MC5 = [y1 = 0, y2 = 0] 
    # - MC6 = [y1 = 1, y2 = 0]
    # - MC7 = [y1 = 0, y2 = 1]
    # - MC8 = [y1 = 1, y2 = 1]

    # Subproblems
    # min x1 + x2
    # s.t. x1 + x2 >= 1
    #     0 <= x1 <= 1 --> (fixing x1 == 0 by propagation)
    #     0 <= x2 <= 1

    # min y1 + y2
    # s.t. y1 + y2 >= 1
    #    0 <= y1 <= 1
    #    0 <= y2 <= 1 (--> fixing y2 == 1 by propagation)

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    master_form, master_name_to_var, master_constr_to_var = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.0, nothing),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing),
            ("y1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing),
            ("y2", Coluna.MathProg.MasterRepPricingVar, 1.0, 1.0, 1.0, nothing),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC2", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC3", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC4", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("a", Coluna.MathProg.MasterArtVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, sense , id
            ("c1", Coluna.MathProg.MasterMixedConstr, 4.0, ClMP.Greater, nothing)
        ]
    )

    master_repr_presolve_form = _presolve_formulation(
        ["x1", "x2", "y1", "y2"],  ["c1"], [2 2 2 2;], master_form, master_name_to_var, master_constr_to_var
    )

    master_presolve_form = _presolve_formulation(
        ["MC1", "MC2", "MC3", "MC4", "a"], ["c1"], [2 2 2 2 1;], master_form, master_name_to_var, master_constr_to_var
    )

    sp1_form, sp1_name_to_var, sp1_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["x1"])),
            ("x2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["x2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c3", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Greater, nothing)
        ]
    )
    
    sp1_presolve_form = _presolve_formulation(
        ["x1", "x2"], ["c3"], [1 1;], sp1_form, sp1_name_to_var, sp1_name_to_constr
    )

    sp2_form, sp2_name_to_var, sp2_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("y1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["y1"])),
            ("y2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["y2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c4", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Greater, nothing)
        ]
    )

    sp2_presolve_form = _presolve_formulation(
        ["y1", "y2"], ["c4"], [1 1;], sp2_form, sp2_name_to_var, sp2_name_to_constr
    )

    # Run the presolve variable fixing on the original formulation.
    bounds_result = Coluna.Algorithm.bounds_tightening(master_repr_presolve_form.form)
    @test isempty(bounds_result)

    new_master_repr_presolve_form = Coluna.Algorithm.propagate_in_presolve_form(
        master_repr_presolve_form, 
        Int[], 
        bounds_result
    )
    
    # Propagate bounds in subproblems
    @test sp1_presolve_form.form.lbs[1] == 0.0
    @test sp1_presolve_form.form.ubs[1] == 1.0

    Coluna.Algorithm.propagate_var_bounds_from!(sp1_presolve_form, new_master_repr_presolve_form)

    @test sp1_presolve_form.form.lbs[1] == 0.0
    @test sp1_presolve_form.form.ubs[1] == 0.0

    @test sp2_presolve_form.form.lbs[2] == 0.0
    @test sp2_presolve_form.form.ubs[2] == 1.0

    Coluna.Algorithm.propagate_var_bounds_from!(sp2_presolve_form, new_master_repr_presolve_form)
    
    @test sp2_presolve_form.form.lbs[2] == 1.0
    @test sp2_presolve_form.form.ubs[2] == 1.0

    # Fixing variables in subproblems
    sp1_bounds_result = Coluna.Algorithm.bounds_tightening(sp1_presolve_form.form)
    @test sp1_bounds_result == Dict(2 => (1, true, 1, false))

    sp2_bounds_result = Coluna.Algorithm.bounds_tightening(sp2_presolve_form.form)
    @test isempty(sp2_bounds_result)
    return
end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_master_to_subproblem2)

## DwSpPricingVar -> MasterRepPricingVar 
## otherwise no propagation
function test_var_fixing_propagation_from_subproblem_to_master()
 # TODO
end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_subproblem_to_master)

################################################################################
# Update DW reformulation
################################################################################

function update_master_repr_formulation()
    # min x1 + x2 + y1 + y2 + MC1 + MC2 + MC3 + MC4 + a1 + a2
    # s.t. x1 + x2 + y1 + y2 + 2MC1 + MC2 + MC3 + MC4 + a1 >= 4
    #      2x1 + x2    + 3y2 + 3MC1 + 2MC2 + 3MC3     + a2 >= 4
    # 0 <= x1 <= 1
    # 0 <= x2 <= 1
    # 0 <= y1 <= 1
    # 0 <= y2 <= 1
    # 0 <= MC1 <= 1
    # 0 <= MC2 <= 1
    # 0 <= MC3 <= 1
    # 0 <= MC4 <= 1
    # a1 >= 0
    # a2 >= 0
    # with following columns
    # MC1 = [x1 = 1, x2 = 1]
    # MC2 = [x1 = 1]
    # MC3 = [y2 = 1]
    # MC4 = [y1 = 1]

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    master_form, master_name_to_var, master_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing),
            ("y1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing),
            ("y2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC2", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC3", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC4", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("a1", Coluna.MathProg.MasterArtVar, 1.0, 0.0, Inf, nothing),
            ("a2", Coluna.MathProg.MasterArtVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, sense , id
            ("c1", Coluna.MathProg.MasterMixedConstr, 4.0, ClMP.Greater, nothing),
            ("c2", Coluna.MathProg.MasterMixedConstr, 4.0, ClMP.Greater, nothing)
        ]
    )

    coeffs = [
        ("c1", "x1", 1.0),
        ("c1", "x2", 1.0),
        ("c1", "y1", 1.0),
        ("c1", "y2", 1.0),
        ("c1", "MC1", 2.0),
        ("c1", "MC2", 1.0),
        ("c1", "MC3", 1.0),
        ("c1", "MC4", 1.0),
        ("c1", "a1", 1.0),
        ("c2", "x1", 2.0),
        ("c2", "x2", 1.0),
        ("c2", "y2", 3.0),
        ("c2", "MC1", 3.0),
        ("c2", "MC2", 2.0),
        ("c2", "MC3", 3.0),
        ("c2", "a2", 1.0)
    ]

    master_form_coef_matrix = Coluna.MathProg.getcoefmatrix(master_form)
    for (constr_name, var_name, coef) in coeffs
        constr = master_name_to_constr[constr_name]
        var = master_name_to_var[var_name]
        master_form_coef_matrix[ClMP.getid(constr), ClMP.getid(var)] = coef
    end
    DynamicSparseArrays.closefillmode!(master_form_coef_matrix)
    
    master_repr_presolve_form = _presolve_formulation(
        ["x1", "x2", "y1", "y2"], 
        ["c1", "c2"],
        [1 1 1 1; 2 1 3 3;],
        master_form,
        master_name_to_var,
        master_name_to_constr
    )

    updated_master_repr_presolve_form = Coluna.Algorithm.propagate_in_presolve_form(
        master_repr_presolve_form,
        Int[2],
        Dict(1 => (1.0, true, 1.0, false), 2 => (0.1, true, 0.5, true))
    )

    @test updated_master_repr_presolve_form.form.col_major_coef_matrix == [1 1 1;]
    @test updated_master_repr_presolve_form.form.rhs == [4 - 1 - 0.1]
    @test updated_master_repr_presolve_form.form.sense == [ClMP.Greater]
    @test updated_master_repr_presolve_form.form.lbs == [0.0, 0.0, 0.0]
    @test updated_master_repr_presolve_form.form.ubs == [0.4, 1.0, 1.0]
    
    Coluna.Algorithm.update_form_from_presolve!(master_form, updated_master_repr_presolve_form)

    vars = [
        # name, lb, ub, partial_sol_value, deactivated
        ("x1", 0.0, 0.0, 1.0, true),
        ("x2", 0.0, 0.4, 0.1, false),
        ("y1", 0.0, 1.0, 0.0, false),
        ("y2", 0.0, 1.0, 0.0, false),
        ("MC1", 0.0, 1.0, 0.0, false),
        ("MC2", 0.0, 1.0, 0.0, false),
        ("MC3", 0.0, 1.0, 0.0, false),
        ("MC4", 0.0, 1.0, 0.0, false),
        ("a1", 0.0, Inf, 0.0, false),
        ("a2", 0.0, Inf, 0.0, false)
    ]

    for (var_name, lb, ub, partial_sol_value, deactivated) in vars
        var = master_name_to_var[var_name]
        @test ClMP.getcurlb(master_form, var) == lb
        @test ClMP.getcurub(master_form, var) == ub
        @test ClMP.get_value_in_partial_sol(master_form, var) == partial_sol_value
        @test ClMP.iscuractive(master_form, var) == !deactivated
    end

    constrs = [
        ("c1", ClMP.Greater, 2.9),
    ]
    for (constr_name, sense, rhs) in constrs
        constr = master_name_to_constr[constr_name]
        @test ClMP.getcursense(master_form, constr) == sense
        @test ClMP.getcurrhs(master_form, constr) == rhs
    end
end
register!(unit_tests, "presolve_formulation", update_master_repr_formulation)

function update_master_formulation()
end
register!(unit_tests, "presolve_formulation", update_master_formulation; x = true)

function update_sp_formulation()
end
register!(unit_tests, "presolve_formulation", update_sp_formulation; x = true)