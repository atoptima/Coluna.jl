using Profile, PProf
using Coluna

using GLPK, ColunaDemos, JuMP, BlockDecomposition

function gap_toy_instance()
    data = ColunaDemos.GeneralizedAssignment.data("play2.txt")

    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => Coluna.Params(solver = Coluna.Algorithm.BranchCutAndPriceAlgorithm(
            branchingtreefile = "playgap.dot"
        )),
        "default_optimizer" => GLPK.Optimizer
    )

    model, x, dec = ColunaDemos.GeneralizedAssignment.model(data, coluna)
    BlockDecomposition.objectiveprimalbound!(model, 100)
    BlockDecomposition.objectivedualbound!(model, 0)

    JuMP.optimize!(model)
end


function gap_strong_branching()
    println("\e[45m gap strong branching \e[00m")
    data = ColunaDemos.GeneralizedAssignment.data("mediumgapcuts3.txt")

    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => Coluna.Params(
            solver = Coluna.Algorithm.BranchCutAndPriceAlgorithm(
                maxnumnodes = 300,
                colgen_stabilization = 1.0,
                colgen_cleanup_threshold = 150,
                stbranch_phases_num_candidates = [10, 3, 1],
                stbranch_intrmphase_stages = [(userstage=1, solverid=1, maxiters=2)]
            )
        ),
        "default_optimizer" => GLPK.Optimizer
    )

    model, x, dec = ColunaDemos.GeneralizedAssignment.model(data, coluna)

    # we increase the branching priority of variables which assign jobs to the first two machines
    for machine in 1:2
        for job in data.jobs
            BlockDecomposition.branchingpriority!(x[machine,job], 2)
        end
    end  

    BlockDecomposition.objectiveprimalbound!(model, 2000.0)
    BlockDecomposition.objectivedualbound!(model, 0.0)

    JuMP.optimize!(model)
end

function gap_big_instance()
    data = ColunaDemos.GeneralizedAssignment.data("mediumgapcuts1.txt")

    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => Coluna.Params(solver = Coluna.Algorithm.BranchCutAndPriceAlgorithm(
            maxnumnodes=5
        )
        ),
        "default_optimizer" => GLPK.Optimizer
    )

    model, x, dec = ColunaDemos.GeneralizedAssignment.model(data, coluna)
    #BlockDecomposition.objectiveprimalbound!(model, 100)
    #BlockDecomposition.objectivedualbound!(model, 0)

    JuMP.optimize!(model)
end


#gap_toy_instance()
#gap_strong_branching()
gap_big_instance()

Profile.clear()
Profile.init(; n = 10^6, delay = 0.005)
#@profile gap_toy_instance()
#@profile gap_strong_branching()
@profile gap_big_instance()
pprof()
readline()

# Collect an allocation profile
#Profile.Allocs.@profile gap_big_instance()

# Export pprof allocation profile and open interactive profiling web interface.
#PProf.Allocs.pprof()
#readline()