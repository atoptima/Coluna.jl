@MOIU.model ModelForCachingOptimizer (ZeroOne, Integer) (EqualTo, GreaterThan, LessThan, Interval) () () (SingleVariable,) (ScalarAffineFunction,) () ()

function build_coluna_model(n_items::Int, nb_bins::Int,
                            profits::Vector{Float64}, weights::Vector{Float64},
                            binscap::Vector{Float64})

    ### Model constructors
    model = CL.ModelConstructor()
    params = model.params
    callback = model.callback
    extended_problem = model.extended_problem
    counter = model.extended_problem.counter
    master_problem = extended_problem.master_problem
    model.problemidx_optimizer_map[master_problem.prob_ref] = GLPK.Optimizer()
    CL.set_model_optimizers(model)

    knap_constrs = CL.MasterConstr[]
    for i in 1:nb_bins
        @show typeof(binscap[i])
        constr = CL.MasterConstr(master_problem.counter,
            string("knapConstr_", i), binscap[i], 'L', 'M', 's')
        push!(knap_constrs, constr)
        CL.add_constraint(master_problem, constr)
    end

    cover_constrs = CL.MasterConstr[]
    for j in 1:n_items
        constr = CL.MasterConstr(master_problem.counter,
            string("CoverCons_", j), 1.0, 'L', 'M', 's')
        push!(cover_constrs, constr)
        CL.add_constraint(master_problem, constr)
    end

    x_vars = Vector{Vector{CL.MasterVar}}()
    for j in 1:n_items
        x_vec = CL.MasterVar[]
        for i in 1:nb_bins
            x_var = CL.MasterVar(master_problem.counter, string("x(", j, ",", i, ")"),
                profits[j], 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)
            push!(x_vec, x_var)
            CL.add_variable(master_problem, x_var)
            CL.add_membership(master_problem, x_var, cover_constrs[j], 1.0)
            CL.add_membership(master_problem, x_var, knap_constrs[i], weights[j])
        end
        push!(x_vars, x_vec)
    end

    return model
end
