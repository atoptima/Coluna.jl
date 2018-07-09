@enum(SEARCHSTRATEGY,BestDualBoundThanDF,DepthFirstWithWorseBound, 
BestLpBound, DepthFirstWithBetterBound)

type Model
    params::Params
    counter::VarConstrCounter
    masterprob::Problem
    pricingprobs::Vector{Problem}
    pricingbounds::Vector{Tuple{Int,Int}} # (lb,ub) on the numcolumns 
    solution::Solution
    primalincbound::Float
    dualincbound::Float
    subtreesizebydepth::Int
end

function createrootnode(model::Model)::Node
    params = model.params
    problemsetupinfo = ProblemSetupInfo(0)    
    stabinfo  = StabilizationInfo(model.masterprob, params)
    masterlpbasis = LpBasisRecord("Basis0")
    nodeevalinfo = ColGenEvalInfo(stabinfo, masterlpbasis, Inf)

    return Node(model, model.dualincbound, problemsetupinfo, nodeevalinfo)
end

function solve(model::Model)::Solution   
    params = model.params
    globalnodestreatorder = 0
    thissearchtreetreatednodesnumber = 0
    curnode = createrootnode(model)
    baptreatorder = 1 # usefull only for printing only

    thissearchtreetreatednodesnumber += 1
    while !isempty(searchtree) && 
            thissearchtreetreatednodesnumber < params.maxnbofbbtreenodetreated
            
        isprimarytreenode = isempty(secondarysearchtree)
        curnodesolvedbefore = issolved(curnode)

        if preparenodefortreatment(curnode, globalnodestreatorder,
             thissearchtreetreatednodesnumber-1)

            printinfobeforesolvingnode(searchtree.size() +
                ((thisisprimarytreenode) ? 1 : 0), secondarysearchtree.size() +
                ((thisisprimarytreenode) ? 0 : 1))

            if !curnodesolvedbefore
                branchandpriceorder(curnode, baptreatorder)
                baptreatorder += 1
                niceprint(curnode, true)
            end

            if !treat(curnode, globalnodestreatorder, primalincbound)
                println("error: branch-and-price is interrupted")
                break
            end

            # the output of the treated node are the generated child nodes and 
            # possibly the updated bounds and the
            # updated solution, we should update primal bound before dual one
            # as the dual bound will be limited by the primal one
            if curnode.primalboundisupdated
                updateprimalincsolution(model, curnode.nodeincipprimalsol)
            end

            if curnode.dualboundisupdated
                updatecurvaliddualbound(model, curnode)
            end

            for childnode in curnode.children
                push!(baptreenodes, childnode)
                if childnode.dualboundisupdated
                   updatecurvaliddualbound(model, childnode)
                end
                if length(searchtree) < params.opennodeslimit
                   enqueue(searchtree, childnode)
                else
                   enqueue(secondarysearchtree, childnode)
                end
            end
        end

        if isempty(curnode.children)
            calculatesubtreesize(curnode, model.subtreesizebydepth);
        end
    end
end
