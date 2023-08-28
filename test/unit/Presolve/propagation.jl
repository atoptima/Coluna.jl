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

function _presolve_formulation!(env, form_duty, var_descriptions, constr_descriptions, matrix)
    form = Coluna.MathProg.create_formulation!(env, form_duty)

    vars = _presolve_propagation_vars(form, var_descriptions)
    constrs = _presolve_propagation_constrs(form, constr_descriptions)
    
    rhs = [rhs for (_, _, rhs, _, _) in constr_descriptions]
    sense = [sense for (_, _, _, sense, _) in constr_descriptions]
    lbs = [lb for (_, _, _, lb, _, _) in var_descriptions]
    ubs = [ub for (_, _, _, _, ub, _) in var_descriptions]

    form_repr = Coluna.Algorithm.PresolveFormRepr(
        matrix,
        rhs,
        sense,
        lbs, 
        ubs
    )

    col_to_var = [var for (_, var) in vars]
    row_to_constr = [constr for (_, constr) in constrs]
    var_to_col = Dict(ClMP.getid(var) => i for (i, var) in enumerate(col_to_var))
    constr_to_row = Dict(ClMP.getid(constr) => i for (i, constr) in enumerate(row_to_constr))

    presolve_form = Coluna.Algorithm.PresolveFormulation(
        col_to_var,
        row_to_constr,
        var_to_col,
        constr_to_row,
        form_repr
    )

    name_to_var = Dict(name => var for (name, var) in vars)
    name_to_constr = Dict(name => constr for (name, constr) in constrs)
    return presolve_form, name_to_var, name_to_constr
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

    orig_presolve_form, orig_name_to_var, orig_name_to_constr = _presolve_formulation!(
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
        ],
        [ 1 1; 1 1 ]
    )

    master_presolve_form, master_name_to_var, master_constr_to_var = _presolve_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("_x", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["x"])),
            ("_y", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["y"])),
            #("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            #("a", Coluna.MathProg.MasterArtVar, 1000.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, lb, ub, id
            ("c1", Coluna.MathProg.MasterPureConstr, 1.0, ClMP.Less, Coluna.Algorithm.getid(orig_name_to_constr["c1"])),
            ("c2", Coluna.MathProg.MasterPureConstr, 3.0, ClMP.Less, Coluna.Algorithm.getid(orig_name_to_constr["c2"]))
        ],
        [ 1 1; 1 1]
    )

    presolve_reform = Coluna.Algorithm.DwPresolveReform(
        orig_presolve_form,
        master_presolve_form,
        Dict{Coluna.MathProg.FormId, Coluna.Algorithm.PresolveFormulation}()
    )
    
    # Run the presolve row deactivation on the original formulation.
    result = Coluna.Algorithm.rows_to_deactivate!(orig_presolve_form.form)

    # Test if the constraint was deactivated.
    @test result == [2] # remove row 2 of original formulation

    # Propagate


    # Test propagation
end
register!(unit_tests, "presolve_propagation", test_constr_removing_propagation_from_original_to_master; f = true)

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

    orig_presolve_form, orig_name_to_var, orig_name_to_constr = _presolve_formulation!(
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
        ],
        [ 1 1 1 1; 1 1 0 0; 0 0 1 1 ]
    )

    sp1_presolve_form, sp1_name_to_var, sp1_name_to_constr = _presolve_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["x1"]))
            ("x2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["x2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c2", Coluna.MathProg.DwSpPureConstr, 2.0, ClMP.Less, Coluna.Algorithm.getid(orig_name_to_constr["c2"]))
        ],
        [ 1 1; ]
    )

    sp2_presolve_form, sp2_name_to_var, sp2_name_to_constr = _presolve_formulation!(
        env,
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("y1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["y1"]))
            ("y2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(orig_name_to_var["y2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c3", Coluna.MathProg.DwSpPureConstr, 1.0, ClMP.Less, Coluna.Algorithm.getid(orig_name_to_constr["c3"]))
        ],
        [ 1 1; ]
    )

        
    # Run the presolve row deactivation on the original formulation.
    result = Coluna.Algorithm.rows_to_deactivate!(orig_presolve_form.form)

    # Test if the constraint was deactivated.
    @test result == [2] # remove row 2 of original formulation
end
register!(unit_tests, "presolve_propagation", test_constr_removing_propagation_from_original_to_subproblem; f = true)

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

    orig_presolve_form, orig_name_to_var, orig_name_to_constr = _presolve_formulation!(
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
        ],
        [ 1 1 1 1; 1 1 0 0; 0 0 1 1 ]
    )

    sp1_presolve_form, sp1_name_to_var, sp1_name_to_constr = _presolve_formulation!(
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
        ],
        [ 1 1; ]
    )

    sp2_presolve_form, sp2_name_to_var, sp2_name_to_constr = _presolve_formulation!(
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
        ],
        [ 1 1; ]
    )

    # Run the presolve bounds tightening on the original formulation.
    result = Coluna.Algorithm.bounds_tightening(orig_presolve_form.form)
    @test result[2] == (0.5, true, Inf, false)
    @test result[4] == (0.3, true, Inf, false)
end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_original_to_subproblem; f = true)

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

    orig_presolve_form, orig_name_to_var, orig_name_to_constr = _presolve_formulation!(
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
        ],
        [ 1 1 ]
    )

    master_presolve_form, master_name_to_var, master_constr_to_var = _presolve_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("_x", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.5, Coluna.Algorithm.getid(orig_name_to_var["x"])),
            ("_y", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, Inf, Coluna.Algorithm.getid(orig_name_to_var["y"])),
            #("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            #("a", Coluna.MathProg.MasterArtVar, 1000.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, lb, ub, id
            ("c1", Coluna.MathProg.MasterPureConstr, 1.0, ClMP.Less, Coluna.Algorithm.getid(orig_name_to_constr["c1"]))
        ],
        [ 1 1 ]
    )

    # Run the presolve bounds tightening on the original formulation.
    result = Coluna.Algorithm.bounds_tightening(orig_presolve_form.form)
    @test result[2] == (0.0, false, 1.0, true)
end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_original_to_master; f = true)

## MasterRepPricingVar -> DwSpPricingVar (mapping exists)
## otherwise no propagation
function test_var_bound_propagation_from_master_to_subproblem()
    # Master
    # min x1 + x2 + y1 + y2 + 2MC1 + MC2 + a
    # s.t. x1 + x2 + y1 + y2 + MC1 + 2MC2 + a >= 2
    #      0 <= x1 <= 0.5
    #      0 <= y1 <= 0.7
    #      x2 >= 0  ( --> x2 >= 0.5)
    #      y2 >= 0  ( --> y2 >= 0.3)

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

    master_presolve_form, master_name_to_var, master_constr_to_var = _presolve_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.5, nothing),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, Inf, nothing),
            ("y1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.7, nothing),
            ("y2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, Inf, nothing),
            #("MC1", Coluna.MathProg.MasterCol, 2.0, 0.0, 1.0, nothing),
            #("MC2", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            #("a", Coluna.MathProg.MasterArtVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, lb, ub, id
            ("c1", Coluna.MathProg.MasterPureConstr, 2.0, ClMP.Greater, nothing)
        ],
        [ 1 1 1 1]
    )

    sp1_presolve_form, sp1_name_to_var, sp1_name_to_constr = _presolve_formulation!(
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
        [ 1 1; ]
    )

    sp2_presolve_form, sp2_name_to_var, sp2_name_to_constr = _presolve_formulation!(
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
        [ 1 1; ]
    )
end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_master_to_subproblem; f = true)

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

    sp1_presolve_form, sp1_name_to_var, sp1_name_to_constr = _presolve_formulation!(
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
        ],
        [ 1 1; ]
    )

    sp2_presolve_form, sp2_name_to_var, sp2_name_to_constr = _presolve_formulation!(
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
        ],
        [ 1 1; ]
    )

    master_presolve_form, master_name_to_var, master_constr_to_var = _presolve_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.5, Coluna.Algorithm.getid(sp1_name_to_var["x1"])),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, Inf, Coluna.Algorithm.getid(sp1_name_to_var["x2"])),
            ("y1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 0.7, Coluna.Algorithm.getid(sp2_name_to_var["y1"])),
            ("y2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, Inf, Coluna.Algorithm.getid(sp2_name_to_var["y2"])),
            #("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            #("MC2", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            #("a", Coluna.MathProg.MasterArtVar, 1.0, 0.0, Inf, nothing)
        ],
        [
            # name, duty, rhs, lb, ub, id
            ("c1", Coluna.MathProg.MasterPureConstr, 2.0, ClMP.Greater, nothing)
        ],
        [ 1 1 1 1]
    )

    # Run the presolve bounds tightening on the original formulation.
    result = Coluna.Algorithm.bounds_tightening(sp1_presolve_form.form)
    @test result[2] == (0.5, true, Inf, false)

    result = Coluna.Algorithm.bounds_tightening(sp2_presolve_form.form)
    @test result[2] == (0.3, true, Inf, false)
end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_subproblem_to_master; f = true)

############################################################################################
# Var fixing propagation.
############################################################################################

## OriginalVar -> DwSpPricingVar (mapping exists)
## otherwise no propagation
function test_var_fixing_propagation_from_original_to_subproblem()

end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_original_to_subproblem; f = true)

## OriginalVar -> MasterRepPricingVar (mapping exists)
## OriginalVar -> MasterPureVar (mapping exists)
## otherwise no propagation
function test_var_fixing_propagation_from_original_to_master()

end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_original_to_master; f = true)

## MasterRepPricingVar -> DwSpPricingVar (mapping exists)
## otherwise no propagation
function test_var_fixing_propagation_from_master_to_subproblem()

end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_master_to_subproblem; f = true)

## DwSpPricingVar -> MasterRepPricingVar (mapping exists)
## otherwise no propagation
function test_var_fixing_propagation_from_subproblem_to_master()

end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_subproblem_to_master; f = true)
