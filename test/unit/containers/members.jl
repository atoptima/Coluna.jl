function members_unit()
    # add_elems_in_matrix_tests(5, 5)
    # add_elems_in_matrix_tests(10, 5)
    # add_elems_in_matrix_tests(5, 10)
    # doc_tests()
end

function create_variable(i)
    v_data = ClF.VarData(
        ; cost = 10.0 * i, lb = -10.0, ub = 100.0, kind = ClF.Continuous,
        sense = ClF.Free, is_active = false, is_explicit = false
    )
    id = ClF.Id{ClF.Variable}(ClF.MasterPureVar, i, 1)
    v = ClF.Variable(id, "fake_var_$i"; var_data = v_data)
    return v, id
end

function create_variables(nbvars)
    vars_list = Dict{ClF.Id{ClF.Variable}, ClF.Variable}()
    ids_list = Vector{ClF.Id{ClF.Variable}}()
    for i in 1:nbvars
        v, id = create_variable(i)
        push!(ids_list, id)
        vars_list[id] = v
    end
    return vars_list, ids_list
end

function create_constraint(i)
    c_data = ClF.ConstrData(
        ; rhs = -13.0 * i, kind = ClF.Facultative, sense = ClF.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )
    id = ClF.Id{ClF.Constraint}(ClF.MasterBranchOnOrigVarConstr, i, 1)
    c = ClF.Constraint(
        id, "fake_constr_$i"; 
        constr_data = c_data
    )
    return c, id
end

function create_constraints(nbconstrs)
    constrs_list = Dict{ClF.Id{ClF.Constraint}, ClF.Constraint}()
    ids_list = Vector{ClF.Id{ClF.Constraint}}()
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
    matrix = ClF.OldMembersMatrix{Float64}(col_elems, row_elems)
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
    return
end

function doc_tests()
    # MembersVector
    variables = Dict{Int, String}(1 => "x_1", 2 => "x_2", 3 => "x_3", 10 => "y")
    vector = ClF.MembersVector{Float64}(variables)
    vector[1] = 1
    vector[3] = 1/2
    vector[10] = 2.5
    vector[1] = 0
    @test vector[1] == 0.0
    @test vector[10] == 2.5
    @test vector[11] == 0.0
    @test reduce(+, vector) == 3.0
    vector[8] = 15 
    @test ClF.is_consistent(vector) == false
    @test_throws KeyError ClF.getelement(vector, 8)
    @test vector[8] == 15
    variables[8] = "z_0"
    @test ClF.getelement(vector, 8) == "z_0"
    @test ClF.is_consistent(vector) == true
    for (key, record) in Iterators.filter(element -> element[1] == 'x', vector)
        varname = ClF.getelement(vector, key)
        @test varname == "x_3"
    end

    # OldMembersMatrix
    variables = Dict{Int, String}(1 => "x_1", 2 => "x_2", 3 => "x_3", 10 => "y_1", 11 => "y_2")
    constraints = Dict{Char, String}('a' => "constr_1", 'b' => "constr_2", 'c' => "constr_3" , 'e' => "bounds_1")
    matrix = ClF.OldMembersMatrix{Float64}(variables, constraints)
    matrix['a', 1] = 2
    matrix['a', 11] = 5
    matrix['b', 3] = 2.5
    matrix['b', 11] = 10
    matrix['c', 2] = -1
    matrix['c', 10] = 42
    matrix['e', 3] = 13/7
    @test matrix['a', 1] == 2
    @test matrix['z', 42] == 0
    matrix['a', 2] += 100
    @test matrix['a', 2] == 100
    matrix['d', 1] = 2 # No constraints with id `d`
    @test ClF.is_consistent(matrix) == false
    constraints['d'] = "bounds_2"
    @test ClF.is_consistent(matrix) == true
    return 
end