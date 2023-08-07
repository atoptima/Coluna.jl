"""
Precompute information to speed-up calculation of right-hand side of benders subproblems.
We extract the following information from the subproblems:
- `a` contains the perenial rhs of all subproblem constraints;
- `A` is a submatrix of the subproblem coefficient matrix that involves only first stage variables.
"""
struct RhsCalculationHelper
    rhs::Dict{FormId, SparseVector{Float64,ConstrId}}
    T::Dict{FormId, DynamicSparseMatrix{ConstrId,VarId,Float64}}
end

function _add_subproblem!(rhs, T, spid, sp)
    @assert !haskey(rhs, spid) && !haskey(T, spid)
    constr_ids = ConstrId[]
    constr_rhs = Float64[]
    for (constr_id, constr) in getconstrs(sp)
        if iscuractive(sp, constr) && isexplicit(sp, constr)
            push!(constr_ids, constr_id)
            push!(constr_rhs, getperenrhs(sp, constr_id))
        end 
    end
    rhs[spid] = sparsevec(constr_ids, constr_rhs, Coluna.MAX_NB_ELEMS)
    T[spid] = _submatrix(
        sp,
        (_, constr_id, _) -> getduty(constr_id) <= BendSpTechnologicalConstr,
        (_, var_id, _) -> getduty(var_id) <= BendSpFirstStageRepVar
    )
    return
end

function RhsCalculationHelper(reform)
    rhs = Dict{FormId, SparseVector{Float64,ConstrId}}()
    T = Dict{FormId, DynamicSparseMatrix{ConstrId,VarId,Float64}}()
    for (spid, sp) in get_benders_sep_sps(reform)
        _add_subproblem!(rhs, T, spid, sp)
    end
    return RhsCalculationHelper(rhs, T)
end