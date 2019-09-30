struct SimpleBnP <: AbstractConquerStrategy 
    colgen::ColumnGeneration
    mastipheur::MasterIpHeuristic
end

function SimpleBnP(
    ;colgen = ColumnGeneration(), mastipheur = MasterIpHeuristic()
)
    return SimpleBnP(colgen, mastipheur)
end

function apply!(strategy::SimpleBnP, reform, node)
    colgen_rec = apply!(strategy.colgen, reform, node)
    if colgen_rec.proven_infeasible
        node.status.proven_infeasible = true
        return
    end
    ip_gap(colgen_rec.incumbents) <= 0 && return
    mip_rec = apply!(strategy.mastipheur, reform, node)
    return
end

struct BnPnPreprocess <: AbstractConquerStrategy 
    preprocess::Preprocess
    colgen::ColumnGeneration
    mastipheur::MasterIpHeuristic
end

function BnPnPreprocess(
    ;preprocess = Preprocess(), colgen = ColumnGeneration(), 
    mastipheur = MasterIpHeuristic()
)
    return BnPnPreprocess(preprocess, colgen, mastipheur)
end

function apply!(stragey::BnPnPreprocess, reform, node)
    prepr_rec = apply!(strategy.preprocess, reform, node)
    if prepr_rec.proven_infeasible
       node.status.proven_infeasible = true
       return
    end
    colgen_rec = apply!(strategy.colgen, reform, node)
    if colgen_rec.proven_infeasible
        node.status.proven_infeasible = true
        return
    end
    ip_gap(colgen_rec.incumbents) <= 0 && return
    mip_rec = apply!(strategy.mastipheur, reform, node)
    return
end
