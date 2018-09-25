function create_array_of_vars(n::Int)
    vars = CL.Variable[]
    vc_counter = CL.VarConstrCounter(0)
    for i in 1:n
        var = CL.Variable(vc_counter, string("var_", i), 1.0, 'P', 'B',
                          's', 'U', 2.0, 0.0, 1.0)
        push!(vars, var)
    end
    return vars
end

