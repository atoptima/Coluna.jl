"Returns `true` if we can project a solution of `form` to the original formulation."
projection_is_possible(form) = false

############################################################################################
# Projection of Dantzig-Wolfe master on original formulation.
############################################################################################

projection_is_possible(master::Formulation{DwMaster}) = true

Base.isless(A::DynamicMatrixColView{VarId, VarId, Float64}, B::DynamicMatrixColView{VarId, VarId, Float64}) = cmp(A, B) < 0

function Base.cmp(A::DynamicMatrixColView{VarId, VarId, Float64}, B::DynamicMatrixColView{VarId, VarId, Float64})
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

_new_set_of_rolls(::Type{DynamicMatrixColView{VarId, VarId, Float64}}) = Dict{VarId, Float64}[]
_new_roll(::Type{DynamicMatrixColView{VarId, VarId, Float64}}, col_len) = Dict{VarId, Float64}()

function _mapping(columns::Vector{A}, values::Vector{B}, col_len::Int) where {A,B}
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



function _extract_data_for_mapping(sol::PrimalSolution{Formulation{DwMaster}})
    columns = DynamicMatrixColView{VarId, VarId, Float64}[]
    values = Float64[]
    master = getmodel(sol)
    for (varid, val) in sol
        duty = getduty(varid)
        if duty <= MasterCol
            origin_form_uid = getoriginformuid(varid)
            spform = get_dw_pricing_sps(master.parent_formulation)[origin_form_uid]
            column = @view get_primal_sol_pool(spform)[varid,:]
            push!(columns, column)
            push!(values, val)
        end
    end

    col_len = 0
    for (var_id, _) in getvars(master)
        if getduty(var_id) <= DwSpPricingVar || getduty(var_id) <= DwSpSetupVar
           col_len += 1
        end
    end
    return columns, values, col_len
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
    for (column, val) in Iterators.zip(extracted_cols, extracted_vals)
        for (repid, repval) in column
            if getduty(repid) <= DwSpPricingVar || getduty(repid) <= DwSpSetupVar
                mastrepid = getid(getvar(master, repid))
                push!(projected_sol_vars, mastrepid)
                push!(projected_sol_vals, repval * val)
            end
        end
    end
    return PrimalSolution(master, projected_sol_vars, projected_sol_vals, getvalue(sol), FEASIBLE_SOL)
end

function proj_cols_on_rep(sol::PrimalSolution{Formulation{DwMaster}})
    columns, values, col_len = _extract_data_for_mapping(sol)
    projected_sol = _proj_cols_on_rep(sol, columns, values)
    println("\e[34m ~~~~~world starts here ~~~~~~~ \e[00m]")
    rolls = _mapping(columns, values, col_len)
    @show rolls
    return projected_sol
end

############################################################################################
# Porjection of Benders master on original formulation.
############################################################################################

projection_is_possible(master::Formulation{BendersMaster}) = false

function proj_cols_on_rep(sol::PrimalSolution, master::Formulation{BendersMaster})
    return sol
end
