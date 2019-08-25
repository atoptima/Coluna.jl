function members_unit_tests()
    add_elems_in_matrix_tests(5, 5)
    add_elems_in_matrix_tests(10, 5)
    add_elems_in_matrix_tests(5, 10)
end

function create_variable(i)
    v_data = CL.VarData(
        ; cost = 10.0 * i, lb = -10.0, ub = 100.0, kind = CL.Continuous,
        sense = CL.Free, is_active = false, is_explicit = false
    )
    id = CL.Id{CL.Variable}(i, 1)
    v = CL.Variable(id, "fake_var_$i", CL.MasterPureVar; var_data = v_data)
    return v, id
end

function create_variables(nbvars)
    vars_list = Dict{CL.Id{CL.Variable}, CL.Variable}()
    ids_list = Vector{CL.Id{CL.Variable}}()
    for i in 1:nbvars
        v, id = create_variable(i)
        push!(ids_list, id)
        vars_list[id] = v
    end
    return vars_list, ids_list
end

function create_constraint(i)
    c_data = CL.ConstrData(
        ; rhs = -13.0 * i, kind = CL.Facultative, sense = CL.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )
    id = CL.Id{CL.Constraint}(i, 1)
    c = CL.Constraint(
        id, "fake_constr_$i", CL.MasterBranchOnOrigVarConstr; 
        constr_data = c_data
    )
    return c, id
end

function create_constraints(nbconstrs)
    constrs_list = Dict{CL.Id{CL.Constraint}, CL.Constraint}()
    ids_list = Vector{CL.Id{CL.Constraint}}()
    for i in 1:nbconstrs
        c, id = create_constraint(i)
        push!(ids_list, id)
        constrs_list[id] = c
    end
    return constrs_list, ids_list
end

function add_elems_in_matrix_tests(nbvars, nbconstrs)
    @assert nbvars >= 4 && nbconstrs >= 4
    col_elems, col_ids = create_variables(nbvars)
    row_elems, row_ids = create_constraints(nbconstrs)
    matrix = CL.MembersMatrix{Float64}(col_elems, row_elems)
    @test matrix[row_ids[1], col_ids[3]] == 0.0
    @test matrix[row_ids[3], col_ids[1]] == 0.0
    @test matrix[row_ids[nbconstrs], col_ids[nbvars]] == 0.0
    matrix[row_ids[3], col_ids[1]] = 1
    @test matrix[row_ids[3], col_ids[1]] == 1.0

    v, id = create_variable(nbvars + 100)
    matrix[row_ids[1], id] = 2.5
    @test matrix[row_ids[1], id] == 2.5

    c, id = create_constraint(nbconstrs + 100)
    matrix[id, col_ids[1]] = 2.0
    @test matrix[id, col_ids[1]] == 2.0
end