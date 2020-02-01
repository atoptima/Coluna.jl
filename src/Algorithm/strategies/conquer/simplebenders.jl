# struct SimpleBenders <: AbstractConquerStrategy 
#     benderscutgen::BendersCutGeneration
# end
# SimpleBenders(;bendcutgen = BendersCutGeneration()) = SimpleBenders(bendcutgen)

# function apply!(strategy::SimpleBenders, reform, node)
#     benders_rec = apply!(strategy.benderscutgen, reform, node)
#     if benders_rec.proven_infeasible
#         node.status.proven_infeasible = true
#         return
#     end
#     #ip_gap(colgen_rec.incumbents) <= 0 && return
#     #mip_rec = apply!(MasterIpHeuristic, reform, node, strategy_rec, params)
#     return
# end
