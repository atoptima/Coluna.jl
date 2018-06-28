type Node
    # params::Parameters
    parent::Node
    children::Vector{Node}
    depth::Int
    prunedattreatnodestart::Bool
    estimatedsubtreesize::Float
    subtreesize::Int

    nodeinclpdualbound::Float
    nodeincipdualbound::Float
    nodeinclpprimalbound::Float
    nodeincipprimalbound::Float

    subtreedualbound::Float

    dualboundisupdated::Bool
    ipprimalboundisupdated::Bool

    nodeincipprimalsol::Solution
    localfixedsolution::Solution

    evalendtime::Int
    treatorder::Int

    infeasible::Bool
    evaluated::Bool
    treated::Bool

    problemandevalalginfosaved::Bool
    solutionvarinfolist::Solution ## More information than only ::Solution
    problemsetupinfo::ProblemSetupInfo
    # nodeevalinfo::NodeEvalInfo

    # generatechildreninfo::GenerateChildrenNodesInfo
    # branchingevalinfo::BranchingEvaluationInfo #used to update the branching history after this node being evaluated
    strongbranchphasenumber::Int
    strongbranchnodenumber::Int

    algtosetupnode::AlgToSetupNode
    # algtopreprocessnode::AlgToPreprocessNode
    # algtoevalnode::AlgToEvalNode
    algtosetdownnode::AlgToSetdownNode
    # algtoprimalheurinnode::Vector{AlgToPrimalHeurInNode}
    # algtogeneratechildrennodes::AlgToGenerateChildrenNodes

end
