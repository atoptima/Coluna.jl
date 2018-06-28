
@hl type VariableSmallInfo
    variable::Variable
    cost::Float
    status::VCSTATUS
end

VariableSmallInfoBuilder(var::Variable, status::VCSTATUS) = (var, var.curcost, status)
VariableSmallInfoBuilder(var::Variable) = VariableSmallInfoBuilder(var, Active)

function applyvarinfo(info::VariableSmallInfo)::Void
    resetcurcostbyvalue(var, info.cost)
end

@hl type VariableInfo <: VariableSmallInfo
    lb::Float
    ub::Float
end

VariableInfoBuilder(var::Variable, status::VCSTATUS) =
        tuplejoin(VariableSmallInfoBuilder(var, status), var.globalcurlb, var.globalcurub)

VariableInfoBuilder(var::Variable) = VariableInfoBuilder(var::Variable, Active)

function applyvarinfo(info::VariableInfo)::Void
    @callsuper applyvarinfo(var::VariableInfoSmall)
    var.globalcurlb = info.lb
    var.globalcurub = info.ub
end

function isneedtochangebounds(info::VariableInfo)::Bool
    var = info.variable
    ub = info.ub
    lb = info.lb
    return var.incurform && (lb != var.globalcurlb || ub != var.globalcurub)
end

@hl type SpVariableInfo <: VariableInfo
    locallb::Float
    localub::Float
end

SpVariableInfoBuilder(var::SubProbVar, status::VCSTATUS) =
        tuplejoin(VariableInfoBuilder(var,status), var.localcurlb, var.localcurub)

function applyvarinfo(info::SubProbVar)::Void
    @callsuper applyvarinfo(var::VariableInfo)
    var.localcurlb = info.locallb
    var.localcurub = info.localub
end

type ConstraintInfo
    constraint::Constraint
    minslack::Float
    maxslack::Float
    rhs::Float
    status::VCSTATUS
end

ConstraintInfo(constr, status) = ConstraintInfo(constr, constr.minslack, constr.maxslack, constr.rhs, status)
CosntraintInfo(constr) = ConstraintInfo(constr, Active)

function applyconstrinfo(info::ConstraintInfo)::Void
    info.constraint.minslack = info.minslack
    info.constraint.maxslack = info.maxslack
    info.constraint.rhs = info.rhs
end

type SubProblemInfo
    subproblem::Problem
    lb::Float
    ub::Float
end

SubProblemInfo(subprob::Problem) = SubProblemInfo(subprob, subprob.lbconvexitymasterconstr.currhs,
        subprob.ubconvexitymasterconstr.currhs)

type ProblemSetupInfo
    treatorder::Int
    numberofnodes::Int
    fullsetupisobligatory::Bool

    suitablemastercolumnsinfo::Vector{VariableSmallInfo}
    suitablemastercutsinfo::Vector{ConstraintInfo}
    activebranchingconstraintsinfo::Vector{ConstraintInfo}
    subproblemsinfo::Vector{SubProblemInfo}
    masterpartialsolutioninfo::Vector{VariableSolInfo}

    # - In these two lists we keep only static variables and constraints for
    # which at least one of the attributes in VariableInfo and ConstraintInfo is different from the default.
    # Default values are set by the user and can be changed by the preprocessing at the root
    # - Unsuitable static variables or constraints are ignored: they are eliminated by the preprocessed at the root
    # - We keep variables and constraints in the strict order: master -> subprob 1 -> subprob 2 -> ...

    modifiedstaticvarsinfo::Vector{VariableInfo}
    modifiedstaticconstrsinf::Vector{ConstraintInfo}
end

ProblemSetupInfo(treatorder) = ProblemSetupInfo(treatoder,0,false, Vector{VariableSmallInfo}(),
        Vector{ConstraintInfo}(), Vector{ConstraintInfo}(), Vector{SubProblemInfo}(), Vector{VariableSolInfo}(),
        Vector{VariableInfo}(), Vector{ConstraintInfo}())

@hl type AlgToSetdownNode
    masterprob::Problem
    pricingprobs::Vector{Problem}
end

function run(alg::AlgToSetdownNode)
    alg.masterprob.curnode = Nullable{Node}()
    for prob in alg.pricingprobs
        prob.curnode = Nullable{Node}()
    end
end

function recordProblemInfo(alg::AlgToSetdownNode, globaltreatorder::Int)::ProblemSetupInfo
    return ProblemSetupInfo(alg.masterprob.curnode.treatorder)
end
recordProblemInfo(alg) = recordProblemInfo(alg, -1)

@hl type AlgToSetdownNodeFully <: AlgToSetdownNode end

function recordProblemInfo(alg::AlgToSetdownNodeFully, globalTreatOrder::Int)
    const masterprob = alg.masterprob
    const probinfo = ProblemSetupInfo(alg.masterprob.curnode.treatorder)

    #patial solution of master
    for (var, val) in masterprob.partialsolution
        push!(probinfo.masterpartialsolutioninfo, VariableSolInfo(var, val))
    end

    #static variables of master
    for var in masterprob.varmanager.activestaticlist
        if var.globalcurlb != var.globallb || var.globalcurub != var.globalub || var.curcost != var.costrhs
            push!(probinfo.modifiedstaticvarsinfo, VariableInfo(var, Active))
        end
    end
    for var in masterprob.varmanager.inactivestaticlist
        push!(probinfo.modifiedstaticvarsinfo, VariableInfo(var, Inactive))
    end

    # dynamic master variables
    for var in masterprob.varmanager.activedynamiclist
        if isa(var, MasterColumn)
            push!(probinfo.suitablemastercolumnsinfo, VariableSmallInfo(var, Active))
        end
    end

    for var in masterprob.varmanager.inactivedynamiclist
        push!(probinfo.suitablemastercolumnsinfo, VariableSmallInfo(var, Inactive))
    end

    printl(1) && print("Stored ", legnth(masterprob.varmanager.activedynamiclist), " active and ",
                 legnth(masterprob.varmanager.inactivedynamiclist), " inactive")

    # static constraints of the master
    for constr in masterprob.constrmanager.activestaticlist
        if !isa(constr, ConvexityMasterConstr) && constr.curMinSlack != constr.minSlack &&
                constr.curMaxSlack != constr.maxSlack && constr.curUse != 0 # is curUse needed?
            push!(probinfo.modifiedstaticconstrsinfo, ConstraintInfo(constr))
        end
    end

    for constr in masterprob.constrmanager.inactivestaticlist
        if !isa(constr, ConvexityMasterConstr)
            push!(probinfo.modifiedstaticconstrsinfo, ConstraintInfo(constr, Inactive))
        end
    end

    # dynamic constraints of the master (cuts and branching constraints)
    for constr in masterprob.constrmanager.activedynamiclist
        # if isa(constr, BranchingMasterConstr) TODO: requires branching
        #     push!(probinfo.activebranchingconstraintsinfo, ConstraintInfo(constr)
        # else
        if isa(constr, MasterConstr)
            push!(probinfo.suitablemastercutsinfo, ConstraintInfo(constr, Active))
        end
    end

    for constr in masterprob.constrmanager.inactivedynamiclist
        push!(masterprob.suitablemastercutsinfo, ConstraintInfo(constr, Inactive))
    end

    #subprob multiplicity
    for subprob in alg.pricingprobs
        push!(probinfo.subproblemsinfo, SubProblemInfo(subprob))
    end

    #subprob variables
    for subprob in alg.pricingprobs
        for var in subprob.varmanager.activestaticlist
            if (var.curgloballb != var.globallb || var.curglobalub != var.globalub || var.curlocallb != locallb
                    || var.curlocalub != var.localub || var.curcost != var.costrhs)
                push!(modifiedstaticvarsinfo, SpVariableInfo(var))
            end
        end

        for var in subprob.varmanager.inactivestaticlist
            push!(modifiedstaticvarsinfo, SpVariableInfo(var, Inactive))
        end
    end

    return probinfo
end

@hl type AlgToSetupNode
    # node::Node
    masterprob::Problem
    pricingprobs::Vector{Problem}
    problemsetupinfo::ProblemSetupInfo
    isallcolumnsactive::Bool
    varstochangecost::Vector{Variable}
end

function resetPartialSolution(alg::AlgToSetupNode)
    # const node = alg.node
    # if !isempty(node.localfixedsolution)
    #     for (var, val) in node.localfixedsolution.solvarvalmap
    #         updatepartialsolution(alg.masterprob, var, val)
    #     end
    # end
end

# function run(alg::AlgToSetupNode, node::Node)
function run(alg::AlgToSetupNode)
    # alg.masterprob.curnode = Nullable{Node}(node)
    # for prob in alg.pricingprobs
    #     prob.curnode = Nullable{Node}(node)
    # end
    resetPartialSolution(alg)
    return false
end

function resetMasterColumns(alg::AlgToSetupNode)
    const probinfo = alg.problemsetupinfo
    for varinfo in alg.probsetupinfo.suitablemastercolumnsinfo
        var = varinfo.variable
        if varinfo.status == Active || alg.isallcolumnsactive
            if var.status == Active && varinfo.cost != var.curcost
                push!(alg.varstochangecost, var)
            end
            if var.status == Inactive
                activatevariable(var)
            end
            applyvarinfo(varinfo)
        elseif varinfostatus == Inactive && var.status == Active
            deactivateVariable(var, Inactive)
        end
        var.infoisupdated = true
    end
        #TODO add what's missing from the last part handeling unsuitable columns
end

@hl type AlgToSetupRootNode <: AlgToSetupNode end

function resetconvexityconstraintsatroot(alg::AlgToSetupRootNode)
    for subprob in alg.pricingprobs
        if subprob.lbconvexitymasterconstr == -Inf
            deactivateconstraint(subprob.lbconvexitymasterconstr, Inactive)
        end
        if subprob.ubconvexitymasterconstr == Inf
            deactivateconstraint(subprob.ubconvexitymasterconstr, Inactive)
        end
    end
end

# function run(alg::AlgToSetupRootNode, node::Node)
function run(alg::AlgToSetupRootNode)
    # @callsuper probleminfeasible = AlgToSetupNode::run(node)

    resetConvexityConstraintsAtRoot(alg)
    resetMasterColumns(alg)
    #resetNonStabArtificialVariables(alg)

    updateFormulation(alg.masterprob)
    # alg.node = Nullable{Node}()
    return probleminfeasible
end
