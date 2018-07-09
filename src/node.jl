type Node
    params::Params
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
    
    problemsetupinfo::ProblemSetupInfo
    evalinfo::EvalInfo
    childrengenerationinfo::ChildrenGenerationInfo
    branchingevalinfo::BranchingEvaluationInfo #for branching history
    
    problemandevalalginfosaved::Bool
    solutionvarinfolist::Solution # More information than only ::Solution
    strongbranchphasenumber::Int
    strongbranchnodenumber::Int

    algtosetupnode::AlgToSetupNode
    algtopreprocessnode::AlgToPreprocessNode
    algtoevalnode::AlgToEvalNode
    algtosetdownnode::AlgToSetdownNode
    algtoprimalheurinnodevect::Vector{AlgToPrimalHeurInNode}
    algtogeneratechildrennodes::AlgToGenerateChildrenNodes
end

function Node(model, dualbound, problemsetupinfo, evalinfo;
    algtosetupnode = AlgToSetupNode(),
    algtopreprocessnode = AlgToPreprocessNode(),
    algtoevalnode = AlgToEvalNode(),
    algtosetdownnode = AlgToSetdownNode(),
    algtoprimalheurinnodevect = AlgToPrimalHeurInNode[],
    algtogeneratechildrennodes = AlgToGenerateChildrenNodes())

return Node(
    model.params,
    this,
    Node[],
    0
    false
    typemax(Int),
    -1,
    dualbound,
    dualbound,
    model.primalincbound,
    model.primalincbound,
    dualbound,
    false,
    false,
    Solution(),
    Solution(),
    -1,
    -1,
    false,
    false,
    false,
    problemsetupinfo,
    evalinfo,
    childrengenerationinfo(),
    branchingevalinfo(),
    false,
    Solution(),
    0,
    -1,
    algtosetupnode,
    algtopreprocessnode,
    algtoevalnode,
    algtosetdownnode,
    algtoprimalheurinnodevect,
    algtogeneratechildrennodes)
end

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

problemsetupinfo::ProblemSetupInfo
evalinfo::EvalInfo
childrengenerationinfo::ChildrenGenerationInfo
branchingevalinfo::BranchingEvaluationInfo #for branching history

problemandevalalginfosaved::Bool
solutionvarinfolist::Solution # More information than only ::Solution
strongbranchphasenumber::Int
strongbranchnodenumber::Int

algtosetupnode::AlgToSetupNode
algtopreprocessnode::AlgToPreprocessNode
algtoevalnode::AlgToEvalNode
algtosetdownnode::AlgToSetdownNode
algtoprimalheurinnodevect::Vector{AlgToPrimalHeurInNode}
algtogeneratechildrennodes::AlgToGenerateChildrenNodes    

function exittreatment(node::Node)::Void    
    # No need for deleting. I prefer deleting the node and storing the info 
    # needed for printing the tree in a different light structure (for now)
    # later we can use Nullable for big data such as XXXInfo of node

    node.evaluated = true
    node.treated = true
end

function evaluation(node::Node, globaltreatorder::Int, incprimalbound::Float)::Bool
    node.treatorder = globaltreatorder
    node.nodeincipprimalbound = incprimalbound
    node.ipprimalboundisupdated = false
    node.dualboundisupdated = false
    
    if run(algtosetupnode, node)
        run(algtosetdownnode)
        markinfeasibleandexittreatment(node); return true
    end
    
    if run(algtopreprocessnode, node)
        run(algtosetdownnode)
        markinfeasibleandexittreatment(node); return true
    end
    
    if setup(algtoevalnode, node)
        setdown(algtoevalnode)
        run(algtosetdownnode)
        markinfeasibleandexittreatment(node); return true
    end    
    node.evaluated = true
    
    #the following should be also called after the heuristics.
    if algtoevalnode.isalgincipprimalboundupdated
        recordipprimalsolandupdateipprimalbound(algtoevalnode)
    end
    
    nodeinclpprimalbound = algtoevalnode.alginclpprimalbound
    updatenodedualbounds(node, algtoevalnode.alginclpdualbound, 
                         algtoevalnode.algincipdualbound)

    if isconquered(node)
        setdown(algtoevalnode)
        run(algtosetdownnode)
        storebranchingevaluationinfo()
        exittreatment(node); return true
    elseif false # _evalAlgPtr->subProbSolutionsEnumeratedToMIP() && runEnumeratedMIP()
        setdown(algtoevalnode)
        run(algtosetdownnode)
        storebranchingevaluationinfo()
        markinfeasibleandexittreatment(); return true
    end

    if !node.problemandevalalginfosaved
        saveproblemandevalalginfo(node)
    end
    
    setdown(algtoevalnode)
    run(algtosetdownnode)    
    storebranchingevaluationinfo()    
    return true;
end

function treat(node::Node, globaltreatorder::Int, incprimalbound::Float)::Bool
    # In strong branching, part I of treat (setup, preprocessing and solve) is 
    # separated from part II (heuristics and children generation).
    # Therefore, treat() can be called two times, one inside strong branching, 
    # second inside the branch-and-price tree. Thus, variables _solved 
    # is used to know whether part I has already been done or not.
    
    if !node.evaluated
        if !evaluation(node, globaltreatorder, incprimalbound)
            return false
        end
    else
        if incprimalbound <= nodeincipprimalbound 
            nodeincipprimalbound = incprimalbound
            ipprimalboundisupdated = false
        end
    end
    
    if treated 
        return true
    end
    
    for alg in node.algtoprimalheurinnodevect
        run(alg, node, globaltreatorder)        
        # TODO put node bound updates from inside heuristics and put it here.
        if isconquered(node)
            exittreatment(node); return true
        end        
    end
    
    # the generation child nodes algorithm fills the sons
    if setup(node.algtogeneratechildrennodes, node)
        setdown(node.algtogeneratechildrennodes)
        exittreatment(node); return true
    end

    run(node.algtogeneratechildrennodes, globaltreatorder)
    setdown(node.algtogeneratechildrennodes)

    exitTreatment(node); return true
end


