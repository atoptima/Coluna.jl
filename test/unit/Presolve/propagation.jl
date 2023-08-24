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

############################################################################################
# Variable removing propagation.
############################################################################################

## MasterRepPricingVar -> OriginalVar (mapping exists)
## MasterPureVar -> OriginalVar (mapping exists)
## otherwise no propagation
function test_var_removing_propagation_from_master_to_original()

end
register!(unit_tests, "presolve_propagation", test_var_removing_propagation_from_master_to_original; f = true)

## MasterRepPricingVar -> DwSpPricingVar (mapping exists)
## otherwise no propagation
function test_var_removing_propagation_from_master_to_subproblem()

end
register!(unit_tests, "presolve_propagation", test_var_removing_propagation_from_master_to_subproblem; f = true)

## OriginalVar -> DwSpPricingVar (mapping exists)
## otherwise no propagation
function test_var_removing_propagation_from_original_to_subproblem()

end
register!(unit_tests, "presolve_propagation", test_var_removing_propagation_from_original_to_subproblem; f = true)

## OriginalVar -> MasterRepPricingVar (mapping exists)
## OriginalVar -> MasterPureVar (mapping exists)
## otherwise no propagation
function test_var_removing_propagation_from_original_to_master()

end
register!(unit_tests, "presolve_propagation", test_var_removing_propagation_from_original_to_master; f = true)

## DwSpPricingVar -> MasterRepPricingVar (mapping exists)
## otherwise no propagation
function test_var_removing_propagation_from_subproblem_to_master()

end
register!(unit_tests, "presolve_propagation", test_var_removing_propagation_from_subproblem_to_master; f = true)

## DwSpPricingVar -> OriginalVar (mapping exists)
## otherwise no propagation
function test_var_removing_propagation_from_subproblem_to_original()

end
register!(unit_tests, "presolve_propagation", test_var_removing_propagation_from_subproblem_to_original; f = true)

############################################################################################
# Constraint removing propagation.
############################################################################################

## MasterPureConstr -> OriginalConstr (mapping exists)
## MasterMixedConstr -> OriginalConstr (mapping exists)
## otherwise no propagation
function test_constr_removing_propagation_from_master_to_original()

end
register!(unit_tests, "presolve_propagation", test_constr_removing_propagation_from_master_to_original; f = true)

## no propagation at all.
## Needs investigation: what happens if you deactivate a master mixed constraint that is the
# only one to contain some representative subproblem variables?
function test_constr_removing_propagation_from_master_to_subproblem()

end
register!(unit_tests, "presolve_propagation", test_constr_removing_propagation_from_master_to_subproblem; f = true)

## OriginalConstr -> MasterMixedConstr
## OriginalConstr -> MasterPureConstr
function test_constr_removing_propagation_from_original_to_subproblem()

end
register!(unit_tests, "presolve_propagation", test_constr_removing_propagation_from_original_to_subproblem; f = true)

## OriginalConstr -> DwSpPureConstr
function test_constr_removing_propagation_from_original_to_subproblem()

end
register!(unit_tests, "presolve_propagation", test_constr_removing_propagation_from_original_to_subproblem; f = true)

## DwSpPureConstr -> MasterMixedConstr
function test_constr_removing_propagation_from_subproblem_to_master()

end
register!(unit_tests, "presolve_propagation", test_constr_removing_propagation_from_subproblem_to_master; f = true)

## DwSpPureConstr -> OriginalConstr
function test_constr_removing_propagation_from_subproblem_to_original()

end
register!(unit_tests, "presolve_propagation", test_constr_removing_propagation_from_subproblem_to_original; f = true)

############################################################################################
# Variable bound propagation.
############################################################################################

## MasterRepPricingVar -> OriginalVar (mapping exists)
## MasterPureVar -> OriginalVar (mapping exists)
## otherwise no propagation
function test_var_bound_propagation_from_master_to_original()

end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_master_to_original; f = true)

## MasterRepPricingVar -> DwSpPricingVar (mapping exists)
## otherwise no propagation
function test_var_bound_propagation_from_master_to_subproblem()

end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_master_to_subproblem; f = true)

## OriginalVar -> DwSpPricingVar (mapping exists)
## otherwise no propagation
function test_var_bound_propagation_from_original_to_subproblem()

end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_original_to_subproblem; f = true)

## OriginalVar -> MasterRepPricingVar (mapping exists)
## OriginalVar -> MasterPureVar (mapping exists)
## otherwise no propagation
function test_var_bound_propagation_from_original_to_master()

end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_original_to_master; f = true)

## DwSpPricingVar -> MasterRepPricingVar (mapping exists)
## otherwise no propagation
function test_var_bound_propagation_from_subproblem_to_master()

end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_subproblem_to_master; f = true)

## DwSpPricingVar -> OriginalVar (mapping exists)
## otherwise no propagation
function test_var_bound_propagation_from_subproblem_to_original()

end
register!(unit_tests, "presolve_propagation", test_var_bound_propagation_from_subproblem_to_original; f = true)

############################################################################################
# Var fixing propagation.
############################################################################################

## MasterRepPricingVar -> OriginalVar (mapping exists)
## MasterPureVar -> OriginalVar (mapping exists)
## otherwise no propagation
function test_var_fixing_propagation_from_master_to_original()

end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_master_to_original; f = true)

## MasterRepPricingVar -> DwSpPricingVar (mapping exists)
## otherwise no propagation
function test_var_fixing_propagation_from_master_to_subproblem()

end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_master_to_subproblem; f = true)

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

## DwSpPricingVar -> MasterRepPricingVar (mapping exists)
## otherwise no propagation
function test_var_fixing_propagation_from_subproblem_to_master()

end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_subproblem_to_master; f = true)

## DwSpPricingVar -> OriginalVar (mapping exists)
## otherwise no propagation
function test_var_fixing_propagation_from_subproblem_to_original()

end
register!(unit_tests, "presolve_propagation", test_var_fixing_propagation_from_subproblem_to_original; f = true)
