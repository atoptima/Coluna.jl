struct SimpleBnP <: AbstractConquerStrategy end

function apply!(strategy::SimpleBnP, reform, node)
    colgen_rec = apply!(ColumnGeneration(), reform, node)
    if colgen_rec.proven_infeasible
        node.status.proven_infeasible = true
        return
    end
    ip_gap(colgen_rec.incumbents) <= 0 && return
    mip_rec = apply!(MasterIpHeuristic(), reform, node)
    return
end

struct BnPnPreprocess <: AbstractConquerStrategy end

function apply!(stragey::BnPnPreprocess, reform, node)
    prepr_rec = apply!(Preprocess(), reform, node)
    if prepr_rec.proven_infeasible
       node.status.proven_infeasible = true
       return
    end
    colgen_rec = apply!(ColumnGeneration(), reform, node)
    if colgen_rec.proven_infeasible
        node.status.proven_infeasible = true
        return
    end
    ip_gap(colgen_rec.incumbents) <= 0 && return
    mip_rec = apply!(MasterIpHeuristic(), reform, node)
    return
end
