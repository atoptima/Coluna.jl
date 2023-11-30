"Returns `true` if we can project a solution of `form` to the original formulation."
projection_is_possible(form) = false

############################################################################################
# Projection of Dantzig-Wolfe master on original formulation.
############################################################################################

projection_is_possible(master::Formulation{DwMaster}) = true

Base.isless(A::DynamicMatrixColView{VarId,VarId,Float64}, B::DynamicMatrixColView{VarId,VarId,Float64}) = cmp(A, B) < 0

function Base.cmp(A::DynamicMatrixColView{VarId,VarId,Float64}, B::DynamicMatrixColView{VarId,VarId,Float64})
    for (a, b) in zip(A, B)
        if !isequal(a, b)
            return isless(a, b) ? -1 : 1
        end
    end
    return 0 # no length for dynamic sparse vectors
end

function _assign_width!(cur_roll, col::Vector, width_to_assign)
    for i in 1:length(col)
        cur_roll[i] += col[i] * width_to_assign
    end
    return
end

function _assign_width!(cur_roll::Dict, col::DynamicMatrixColView, width_to_assign)
    for (id, val) in col
        if !haskey(cur_roll, id)
            cur_roll[id] = 0.0
        end
        cur_roll[id] += val * width_to_assign
    end
    return
end

_new_set_of_rolls(::Type{Vector{E}}) where {E} = Vector{Float64}[]
_new_roll(::Type{Vector{E}}, col_len) where {E} = zeros(Float64, col_len)
_roll_is_integer(roll::Vector{Float64}) = all(map(r -> abs(r - round(r)) <= Coluna.DEF_OPTIMALITY_ATOL, roll))

_new_set_of_rolls(::Type{DynamicMatrixColView{VarId,VarId,Float64}}) = Dict{VarId,Float64}[]
_new_roll(::Type{DynamicMatrixColView{VarId,VarId,Float64}}, _) = Dict{VarId,Float64}()
_roll_is_integer(roll::Dict{VarId,Float64}) = all(map(r -> abs(r - round(r)) <= Coluna.DEF_OPTIMALITY_ATOL, values(roll)))

function _mapping(columns::Vector{A}, values::Vector{B}; col_len::Int=10) where {A,B}
    p = sortperm(columns, rev=true)
    columns = columns[p]
    values = values[p]

    rolls = _new_set_of_rolls(eltype(columns))
    total_width_assigned = 0
    nb_roll_opened = 1 # roll is width 1
    cur_roll = _new_roll(eltype(columns), col_len)

    for (val, col) in zip(values, columns)
        cur_unassigned_width = val
        while cur_unassigned_width > 0
            width_to_assign = min(cur_unassigned_width, nb_roll_opened - total_width_assigned)
            _assign_width!(cur_roll, col, width_to_assign)
            cur_unassigned_width -= width_to_assign
            total_width_assigned += width_to_assign
            if total_width_assigned == nb_roll_opened
                push!(rolls, cur_roll)
                cur_roll = _new_roll(eltype(columns), col_len)
                nb_roll_opened += 1
            end
        end
    end
    return rolls
end

function _mapping_by_subproblem(columns::Dict{Int,Vector{A}}, values::Dict{Int,Vector{B}}) where {A,B}
    return Dict(
        uid => _mapping(cols, values[uid]) for (uid, cols) in columns
    )
end

_rolls_are_integer(rolls) = all(_roll_is_integer.(rolls))
_subproblem_rolls_are_integer(rolls_by_sp::Dict) = all(_rolls_are_integer.(values(rolls_by_sp)))

# removes information about continuous variables from rolls, as this information should be ignored when checking integrality
function _remove_continuous_vars_from_rolls!(rolls_by_sp::Dict, reform::Reformulation)
    for (uid, rolls) in rolls_by_sp
        spform = get_dw_pricing_sps(reform)[uid]
        for roll in rolls
            filter!(pair -> getcurkind(spform, pair.first) != Continuous, roll)
        end
    end
end

function _extract_data_for_mapping(sol::PrimalSolution{Formulation{DwMaster}})
    columns = Dict{Int,Vector{DynamicMatrixColView{VarId,VarId,Float64}}}()
    values = Dict{Int,Vector{Float64}}()
    master = getmodel(sol)
    reform = getparent(master)
    if isnothing(reform)
        error("Projection: master have the reformulation as parent formulation.")
    end
    dw_pricing_sps = get_dw_pricing_sps(reform)

    for (varid, val) in sol
        duty = getduty(varid)
        if duty <= MasterCol
            origin_form_uid = getoriginformuid(varid)
            spform = get(dw_pricing_sps, origin_form_uid, nothing)
            if isnothing(spform)
                error("Projection: cannot retrieve Dantzig-Wolfe pricing subproblem with uid $origin_form_uid")
            end
            column = @view get_primal_sol_pool(spform).solutions[varid, :]
            if !haskey(columns, origin_form_uid)
                columns[origin_form_uid] = DynamicMatrixColView{VarId,VarId,Float64}[]
                values[origin_form_uid] = Float64[]
            end
            push!(columns[origin_form_uid], column)
            push!(values[origin_form_uid], val)
        end
    end
    return columns, values
end

function _proj_cols_on_rep(sol::PrimalSolution{Formulation{DwMaster}}, extracted_cols, extracted_vals)
    projected_sol_vars = VarId[]
    projected_sol_vals = Float64[]

    for (varid, val) in sol
        duty = getduty(varid)
        if duty <= MasterPureVar
            push!(projected_sol_vars, varid)
            push!(projected_sol_vals, val)
        end
    end

    master = getmodel(sol)
    for spid in keys(extracted_cols)
        for (column, val) in Iterators.zip(extracted_cols[spid], extracted_vals[spid])
            for (repid, repval) in column
                if getduty(repid) <= DwSpPricingVar || getduty(repid) <= DwSpSetupVar ||
                   getduty(repid) <= MasterRepPricingVar || getduty(repid) <= MasterRepPricingSetupVar
                    mastrepvar = getvar(master, repid)
                    @assert !isnothing(mastrepvar)
                    mastrepid = getid(mastrepvar)
                    push!(projected_sol_vars, mastrepid)
                    push!(projected_sol_vals, repval * val)
                end
            end
        end
    end
    return PrimalSolution(master, projected_sol_vars, projected_sol_vals, getvalue(sol), FEASIBLE_SOL)
end

function proj_cols_on_rep(sol::PrimalSolution{Formulation{DwMaster}})
    columns, values = _extract_data_for_mapping(sol)
    projected_sol = _proj_cols_on_rep(sol, columns, values)
    return projected_sol
end

function proj_cols_is_integer(sol::PrimalSolution{Formulation{DwMaster}})
    columns, values = _extract_data_for_mapping(sol)
    projected_sol = _proj_cols_on_rep(sol, columns, values)
    rolls = _mapping_by_subproblem(columns, values)
    reform = getparent(getmodel(sol))
    _remove_continuous_vars_from_rolls!(rolls, reform)
    integer_rolls = _subproblem_rolls_are_integer(rolls)
    return isinteger(projected_sol) && integer_rolls
end

############################################################################################
# Projection of Benders master on original formulation.
############################################################################################

projection_is_possible(master::Formulation{BendersMaster}) = false

function proj_cols_on_rep(sol::PrimalSolution{Formulation{BendersMaster}})
    return sol
end
