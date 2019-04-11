
mutable struct Formulation{Duty <: AbstractFormDuty}  <: AbstractFormulation
    uid::FormId
    problem::AbstractProblem # Should be removed. Only kept here because of counters
    parent_formulation::Union{AbstractFormulation, Nothing} # master for sp, reformulation for master
    #moi_model::Union{MOI.ProblemLike, Nothing}
    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing}
    manager::FormulationManager
    obj_sense::ObjSense
    primal_inc_bound::Float64
    dual_inc_bound::Float64
    primal_solution_record::Union{PrimalSolution, Nothing}
    dual_solution_record::Union{DualSolution, Nothing}
    callback
end

function Formulation{D}(p::AbstractProblem;
                        parent_formulation = nothing,
                        obj_sense::ObjSense = Min,
                        primal_inc_bound::Float64 = Inf,
                        dual_inc_bound::Float64 = -Inf
                        ) where {D<:AbstractFormDuty}
    return Formulation{D}(
        getnewuid(p.form_counter), p, parent_formulation, nothing,
        FormulationManager(),
        obj_sense, primal_inc_bound, dual_inc_bound, nothing,
        nothing, nothing
    )
end

get_var(f::Formulation, id::VarId) = get_var(f.manager, id)

get_constr(f::Formulation, id::ConstrId) = get_constr(f.manager, id)

get_vars(f::Formulation) = get_vars(f.manager)

get_constrs(f::Formulation) = get_constrs(f.manager)

get_coefficient_matrix(f::Formulation) = get_coefficient_matrix(f.manager)

getuid(f::Formulation) = f.uid

getobjsense(f::Formulation) = f.obj_sense


function generatevarid(f::Formulation)
    return VarId(getnewuid(f.problem.var_counter))
end

function generateconstrid(f::Formulation)
    return ConstrId(getnewuid(f.problem.constr_counter))
end

function set_var!(f::Formulation,
                  name::String,
                  duty::Type{<:AbstractVarDuty};
                  cost::Float64 = 0.0,
                  lb::Float64 = 0.0,
                  ub::Float64 = Inf,
                  kind::VarKind = Continuous,
                  sense::VarSense = Positive,
                  moi_index::MoiVarIndex = MoiVarIndex())
    id = generatevarid(f)
    v_data = VarData(cost, lb, ub, kind, sense, true)
    v = Variable(id, name, duty; var_data = v_data, moi_index = moi_index)
    return add_var!(f, v)
end

add_var!(f::Formulation, var::Variable) = add_var!(f.manager, var)

clone_var!(dest::Formulation,
           src::Formulation,
           var::Variable) = clone_var!(dest.manager, src.manager, var)

function set_constr!(f::Formulation,
                     name::String,
                     duty::Type{<:AbstractConstrDuty};
                     rhs::Float64 = 0.0,
                     kind::ConstrKind = 0.0,
                     sense::ConstrSense = 0.0,
                     moi_index::MoiConstrIndex = MoiConstrIndex())
    id = generateconstrid(f)
    c_data = ConstrData(rhs, kind, sense, true)
    c = Constraint(id, name, duty; constr_data = c_data, moi_index = moi_index)
    return add_constr!(f, c)
end

add_constr!(f::Formulation, constr::Constraint) = add_constr!(f.manager, constr)

clone_constr!(dest::Formulation,
           src::Formulation,
           constr::Constraint) = clone_constr!(dest.manager, src.manager, constr)

function register_objective_sense!(f::Formulation, min::Bool)
    !min && error("Coluna does not support maximization yet.")
    return
end

function _show_obj_fun(io::IO, f::Formulation)
    print(io, getobjsense(f), " ")
    for (id, var) in filter(_explicit_, get_vars(f))
        name = getname(var)
        cost = getcost(get_cur_data(var))
        op = (cost < 0.0) ? "-" : "+" 
        print(io, op, " ", abs(cost), " ", name, " ")
    end
    println(io, " ")
    return
end

function _show_constraint(io::IO, f::Formulation, constr_id::ConstrId,
                          members::VarMembership)
    constr = get_constr(f, constr_id)
    constr_data = get_cur_data(constr)
    print(io, constr_id, " ", getname(constr), " : ")
    for (var_id, coeff) in members
        var = get_var(f, var_id)
        name = getname(var)
        op = (coeff < 0.0) ? "-" : "+"
        print(io, op, " ", abs(coeff), " ", name, " ")
    end
    if getsense(constr_data) == Equal
        op = "=="
    elseif getsense(constr_data) == Greater
        op = ">="
    else
        op = "<="
    end
    print(io, " ", op, " ", getrhs(constr_data))
    println(io, " (", getduty(constr) ,")")
    return
end

function _show_constraints(io::IO , f::Formulation)
    constrs = filter(
        x->(getduty(x) isa ExplicitDuty), rows(get_coefficient_matrix(f))
    )
    for (constr_id, members) in constrs
        _show_constraint(io, f, constr_id, members)
    end
    return
end

function _show_variable(io::IO, f::Formulation, var::Variable)
    var_data = get_cur_data(var)
    name = getname(var)
    lb = getlb(var_data)
    ub = getub(var_data)
    t = getkind(var_data)
    d = getduty(var)
    println(io, getid(var), " ", lb, " <= ", name, " <= ", ub, " (", t, " | ", d , ")")
end

function _show_variables(io::IO, f::Formulation)
    for (id, var) in filter(_explicit_, get_vars(f))
        _show_variable(io, f, var)
    end
end

function Base.show(io::IO, f::Formulation)
    println(io, "Formulation id = ", getuid(f))
    _show_obj_fun(io, f)
    _show_constraints(io, f)
    _show_variables(io, f)
    return
end
