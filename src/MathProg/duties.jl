## Duties :
@exported_nestedenum begin
    Duty{Variable}
        AbstractOriginalVar <= Duty{Variable}
            OriginalVar <= AbstractOriginalVar
            OriginalExpression <= AbstractOriginalVar
        AbstractMasterVar <= Duty{Variable}
            AbstractOriginMasterVar <= AbstractMasterVar
                MasterPureVar <= AbstractOriginMasterVar
                MasterBendFirstStageVar <= AbstractOriginMasterVar
            AbstractAddedMasterVar <= AbstractMasterVar
                MasterCol <= AbstractAddedMasterVar
                MasterArtVar <= AbstractAddedMasterVar
                MasterBendSecondStageCostVar <= AbstractAddedMasterVar
            AbstractImplicitMasterVar <= AbstractMasterVar
                AbstractMasterRepDwSpVar <= AbstractImplicitMasterVar
                    MasterRepPricingVar <= AbstractMasterRepDwSpVar
                    MasterRepPricingSetupVar <= AbstractMasterRepDwSpVar
        AbstractDwSpVar <= Duty{Variable}
            DwSpPricingVar <= AbstractDwSpVar
            DwSpSetupVar <= AbstractDwSpVar
            DwSpPureVar <= AbstractDwSpVar
            DwSpPrimalSol <= AbstractDwSpVar
        AbstractBendSpVar <= Duty{Variable}
            AbstractBendSpSlackMastVar <= AbstractBendSpVar
                BendSpSlackFirstStageVar <= AbstractBendSpSlackMastVar
                BendSpSlackSecondStageCostVar <= AbstractBendSpSlackMastVar
            BendSpSepVar <= AbstractBendSpVar
            BendSpPureVar <= AbstractBendSpVar
            BendSpPrimalSol <= AbstractBendSpVar
        UndefinedVarDuty <= Duty{Variable}
end

@exported_nestedenum begin
    Duty{Constraint}
        AbstractOriginalConstr <= Duty{Constraint}
            OriginalConstr <= AbstractOriginalConstr
        AbstractMasterConstr <= Duty{Constraint}
            AbstractMasterOriginConstr <= AbstractMasterConstr
                MasterPureConstr <= AbstractMasterOriginConstr
                MasterMixedConstr <= AbstractMasterOriginConstr
            AbstractMasterAddedConstr <= AbstractMasterConstr
                MasterConvexityConstr <= AbstractMasterAddedConstr
                MasterSecondStageCostConstr <= AbstractMasterAddedConstr
            AbstractMasterImplicitConstr <= AbstractMasterConstr
                AbstractMasterRepBendSpConstr <= AbstractMasterImplicitConstr
                    MasterRepBendSpSecondStageCostConstr <= AbstractMasterRepBendSpConstr
                    MasterRepBendSpTechnologicalConstr <= AbstractMasterRepBendSpConstr
            AbstractMasterCutConstr <= AbstractMasterConstr
                MasterBendCutConstr <= AbstractMasterCutConstr
            AbstractMasterBranchingConstr <= AbstractMasterConstr
            MasterBranchOnOrigVarConstr <= AbstractMasterBranchingConstr
        AbstractDwSpConstr <= Duty{Constraint}
            DwSpPureConstr <= AbstractDwSpConstr
            DwSpDualSol <= AbstractDwSpConstr
            DwSpRepMastBranchConstr <= AbstractDwSpConstr
        AbstractBendSpPureConstr <= Duty{Constraint}
        AbstractBendSpConstr <= Duty{Constraint}
            AbstractBendSpMasterConstr <= AbstractBendSpConstr
                BendSpSecondStageCostConstr <= AbstractBendSpMasterConstr
                BendSpTechnologicalConstr <= AbstractBendSpMasterConstr
            BendSpPureConstr <= AbstractBendSpConstr
            BendSpDualSol <= AbstractBendSpConstr
        UndefinedConstrDuty <= Duty{Constraint}
end

function isaStaticDuty(duty::NestedEnum)
    return duty <= OriginalVar ||
    duty <= OriginalExpression ||
    duty <= MasterPureVar ||
    duty <= MasterArtVar ||
    duty <= MasterBendSecondStageCostVar ||
    duty <= MasterBendFirstStageVar ||
    duty <= MasterRepPricingVar ||
    duty <= MasterRepPricingSetupVar ||
    duty <= DwSpPricingVar ||
    duty <= DwSpSetupVar ||
    duty <= DwSpPureVar ||
    duty <= DwSpPrimalSol ||
    duty <= DwSpDualSol ||
    duty <= BendSpSepVar ||
    duty <= BendSpPureVar ||
    duty <= BendSpSlackFirstStageVar  ||
    duty <= BendSpSlackSecondStageCostVar ||
    duty <= OriginalConstr ||
    duty <= MasterPureConstr ||
    duty <= MasterMixedConstr ||
    duty <= MasterConvexityConstr ||
    duty <= MasterSecondStageCostConstr ||
    duty <= DwSpPureConstr ||
    duty <= BendSpPureConstr ||
    duty <= BendSpDualSol ||
    duty <= BendSpPrimalSol ||
    duty <= BendSpSecondStageCostConstr ||
    duty <= BendSpTechnologicalConstr
end

function isaDynamicDuty(duty::NestedEnum)
    duty <= MasterCol ||
    duty <= MasterBranchOnOrigVarConstr ||
    duty <= MasterBendCutConstr ||
    duty <= MasterBranchOnOrigVarConstr ||
    duty <= DwSpRepMastBranchConstr ||
    duty <= DwSpRepMastBranchConstr
end

function isanOriginalRepresentatives(duty::NestedEnum)
    duty <= MasterPureVar ||
    duty <= MasterRepPricingVar
end

function isanArtificialDuty(duty::NestedEnum)
    return duty <= MasterArtVar
end