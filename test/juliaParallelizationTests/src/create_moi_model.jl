## This file is used to create moi_models that simulate the solvers
## The functions here may be used in several examples
###################################################################
@everywhere using MathOptInterface
@everywhere const MOI = MathOptInterface
@everywhere const MOIU = MathOptInterface.Utilities
@everywhere using GLPK
@everywhere using Cbc

@everywhere @MOIU.model ModelForCachingOptimizer (MOI.ZeroOne, MOI.Integer) (MOI.EqualTo, MOI.GreaterThan, MOI.LessThan, MOI.Interval) () () (MOI.SingleVariable,) (MOI.ScalarAffineFunction,) () ()

@everywhere function create_model(moi_model::MOI.ModelLike, data::SolverData)
    nb_vars = data.n_vars
    vars = MOI.add_variables(moi_model, nb_vars)
    wheights = rand(nb_vars)
    capacity = sum(wheights) - 0.1

    for var in vars
        ci = MOI.add_constraint(moi_model, MOI.SingleVariable(var), MOI.ZeroOne())
    end

    ci = MOI.add_constraint(moi_model, MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(wheights, vars), 0.0), MOI.LessThan(capacity))

    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}.(ones(nb_vars), vars), 0.0)
    MOI.set(moi_model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),f)
    MOI.set(moi_model, MOI.ObjectiveSense(), MOI.MaxSense)
end    

@everywhere function create_moi_model_with_glpk(data::SolverData)
    moi_model = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(), GLPK.Optimizer())
    create_model(moi_model, data)
    return moi_model
end

@everywhere function create_moi_model_with_cbc(data::SolverData)

    moi_model = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(), Cbc.CbcOptimizer())
    create_model(moi_model, data)
    return moi_model
end

@everywhere function create_moi_model_with_glpk(container::Vector{SolverData})
    return create_moi_model_with_glpk(pop!(container))
end

@everywhere function create_moi_model_with_glpk()
    return create_moi_model_with_glpk(data)
end

@everywhere function fill_data(data_from_master::SolverData)
    data.name = data_from_master.name
    data.graph = data_from_master.graph
    data.n_vars = data_from_master.n_vars
end


@everywhere function put_data_to_container(data::SolverData, container_name::Symbol)
    push!(eval(container_name), data)
end

@everywhere function create_and_put_solver_to_container(data::SolverData, container_name::Symbol)
    push!(eval(container_name), create_moi_model_with_glpk(data))
end


