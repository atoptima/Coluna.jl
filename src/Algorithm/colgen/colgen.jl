struct ColGenContext <: AbstractColGenContext

end

###############################################################################
# Sequence of phases
###############################################################################
struct ColunaColGenPhaseIterator <: AbstractColGenPhaseIterator end

"""
Phase 1 sets the cost of variables to 0 except for artifical variables.
The goal is to find a solution to the master LP problem that has no artificial variables.
"""
struct ColGenPhase1 <: AbstractColGenPhase end


"""
Phase 2 solves the master LP without artificial variables.
To starts, it requires a set of columns that forms a feasible solution to the LP master.
This set is found with phase 1.
"""
struct ColGenPhase2 <: AbstractColGenPhase end

"""
Phase 3 is a mix of phase 1 and phase 2.
It sets a very large cost to artifical variable to force them to be removed from the master 
LP solution.
If the final master LP solution contains artifical variables either the master is infeasible
or the cost of artificial variables is not large enough. Phase 1 must be run.
"""
struct ColGenPhase3 <: AbstractColGenPhase end

# Implementation of ColGenPhase interface
## Implementation of `initial_phase`.
initial_phase(::ColunaColGenPhaseIterator) = ColGenPhase3()

## Implementation of `next_phase`.
function next_phase(::ColunaColGenPhaseIterator, ::ColGenPhase1, ctx)
    # If master LP solution has no artificial vars, it means that the phase 1 has succeeded.
    # We have a set of columns that forms a feasible solution to the LP master and we can 
    # thus start phase 2.
    if !colgen_mast_lp_sol_has_art_vars(ctx)
        return ColGenPhase2()
    end
    return nothing
end

function next_phase(::ColunaColGenPhaseIterator, ::ColGenPhase2, ctx)
    # The phase 2 is always the last phase of the column generation algorithm.
    # It means the algorithm converged or hit a user limit.
    return nothing
end

function next_phase(::ColunaColGenPhaseIterator, ::ColGenPhase3, ctx)
    # Master LP solution has artificial vars.
    if colgen_mast_lp_sol_has_art_vars(ctx)
        return ColGenPhase1()
    end
    return nothing
end

## Methods used in the implementation and that we should mock in tests.
function colgen_mast_lp_sol_has_art_vars(ctx::ColGenContext)

end

## Implementatation of `setup_reformulation!`
## Phase 1 => non-artifical variables have cost equal to 0
function setup_reformulation!(reform, ::ColGenPhase1)
    master = getmaster(reform)
    for (varid, _) in getvars(master)
        if !isanArtificialDuty(getduty(varid))
            setcurcost!(master, varid, 0.0)
        end
    end
    return
end

## Phase 2 => deactivate artifical variables and make sure that the cost of non-artifical
## variables is correct.
function setup_reformulation!(reform, ::ColGenPhase2)
    master = getmaster(reform)
    for (varid, var) in getvars(master)
        if isanArtificialDuty(getduty(varid))
            deactivate!(master, varid)
        else
            setcurcost!(master, varid, getperencost(master, var))
        end
    end
    return
end

## Phase 3 => make sure artifical variables are active and cost is correct.
function setup_reformulation!(reform, ::ColGenPhase3)
    master = getmaster(reform)
    for (varid, var) in getvars(master)
        if isanArtificialDuty(getduty(varid))
            activate!(master, varid)
        end
        setcurcost!(master, varid, getperencost(master, var))
    end
    return
end

######### Column generation

# Placeholder methods:  

before_colgen_iteration(::ColGenContext, _, _) = nothing
after_colgen_iteration(::ColGenContext, _, _, _) = nothing


######### Column generation iteration
