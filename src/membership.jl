const VcMemberDict{S} = PerIdDict{S,Float64}
const VarMemberDict = VcMemberDict{VarState}
const ConstrMemberDict = VcMemberDict{ConstrState}

"""
    Memberships

    Doc to do
"""
struct Memberships
    var_to_constr_members    ::PerIdDict{VarState, ConstrMemberDict}
    constr_to_var_members    ::PerIdDict{ConstrState, VarMemberDict}
    var_to_partialsol_members::PerIdDict{VarState, VarMemberDict}
    partialsol_to_var_members::PerIdDict{VarState, VarMemberDict}
    var_to_expression_members::PerIdDict{VarState, VarMemberDict}
    expression_to_var_members::PerIdDict{VarState, VarMemberDict}
end

function Memberships()
    return Memberships(PerIdDict{VarState, ConstrMemberDict}(),
                       PerIdDict{ConstrState, VarMemberDict}(), 
                       PerIdDict{VarState, VarMemberDict}(), 
                       PerIdDict{VarState, VarMemberDict}(), 
                       PerIdDict{VarState, VarMemberDict}(), 
                       PerIdDict{VarState, VarMemberDict}())
end

# Getters
function _get_members_(d::Dict{Id{S1}, VcMemberDict{S2}}, id::Id{S1}
        ) where {S1<:AbstractState,S2<:AbstractState}
    haskey(d, id) && return d[id]
    error("""Cannot retrieve $id in membership.
             >> $d
          """)
end

function get_var_members_of_constr(m::Memberships, id::Id{ConstrState}) 
    _get_members_(m.constr_to_var_members, id)
end

function get_constr_members_of_var(m::Memberships, id::Id{VarState})
    _get_members_(m.var_to_constr_members, id)
end

function get_var_members_of_expression(m::Memberships, id::Id{VarState}) 
    _get_members_(m.expression_to_var_members, id)
end

# "Adders"
function _init_members_!(d::Dict{Id{S1}, VcMemberDict{S2}}, id::Id{S1}
        ) where {S1<:AbstractState,S2<:AbstractState}
    if !haskey(d, id)
        d[id] = VcMemberDict{S2}()
    end
    return
end

function _add_coeff_!(d1::Dict{Id{S1}, VcMemberDict{S2}}, id1::Id{S1}, 
        d2::Dict{Id{S3}, VcMemberDict{S4}}, id2::Id{S4}, val::Float64
        ) where {S1,S2,S3,S4}
    _init_members_!(d1, id1)
    d1[id1][id2] += val
    _init_members_!(d2, id2)
    d2[id2][id1] += val
    return
end

function add_constr_members_of_var!(m::Memberships, var_id::Id, 
        constr_id::Id, coef::Float64)
    _add_coeff_!(
            m.var_to_constr_members, var_id, m.constr_to_var_members, 
            constr_id, coef
    )
end

function add_var_members_of_partialsol!(m::Memberships, ps_var_id::Id, 
        var_id::Id, coef::Float64)
    _add_coeff_!(
            m.partialsol_to_var_members, ps_var_id, m.var_to_partialsol_members,
            ps_var_id, coef
    )
end

function add_partialsol_members_of_var!(m::Memberships, var_id::Id, 
        ps_var_id::Int, coef::Float64)
    _add_coeff_!(
            m.var_to_partialsol_members, var_id, m.partialsol_to_var_members,
            ps_var_id, coef
    )
end

# Setters
function _set_membership_!(d1::Dict{Id{S1}, VcMemberDict{S2}}, id1::Id{S1}, 
            d2::Dict{Id{S3}, VcMemberDict{S4}}, membership
        ) where {S1,S2,S3,S4}
    d1[id1] = membership
    for (id2, val) in membership
        _init_members_!(d2, id2)
        d2[id2][id1] = val
    end
    return
end

function set_constr_members_of_var!(m::Memberships, var_id::Id, 
        new_membership::ConstrMemberDict) 
    _set_membership_!(
        m.var_to_constr_members, var_id, m.constr_to_var_members, new_membership
    )
end

function set_var_members_of_constr!(m::Memberships, constr_id::Id, 
        new_membership::VarMemberDict) 
    _set_membership_!(
        m.constr_to_var_members, constr_id, m.var_to_constr_members, 
        new_membership
    )
end

function set_partialsol_members_of_var!(m::Memberships, ps_var_id::Id, 
        new_membership::VarMemberDict) 
    _set_membership_!(
        m.partialsol_to_var_members, ps_var_id, m.var_to_partialsol_members,
        new_membership
    )
end

function set_var_members_of_partialsol!(m::Memberships, var_id::Id, 
        new_membership::VarMemberDict) 
    _set_membership_!(
        m.var_to_partialsol_members, var_id, m.partialsol_to_var_members,
        new_membership
    )
end

function set_variable!(m::Memberships, var_id::Id)
    _init_members_!(m.var_to_constr_members, var_id)
    return
end

function set_variable!(m::Memberships, var_id::Id, membership::ConstrMemberDict)
    _init_members_!(m.var_to_constr_members, var_id)
    set_constr_members_of_var!(m, var_id, membership)
    return
end

function set_constraint!(m::Memberships, constr_id::Id)
    _init_members_!(m.constr_to_var_members, constr_id)
    return
end

function set_constraint!(m::Memberships, constr_id::Id, 
        membership::VarMemberDict)
    _init_members_!(m.constr_to_var_members, constr_id)
    set_var_members_of_constr!(m, constr_id, membership)
    return
end

# function check_if_exists(dict::Dict{Id, VcMemberDict{S}},
#     membership::VcMemberDict{S}) where {S}
#     for (id, m) in dict
#         if (m == membership)
#             return id
#         end
#     end
#     return 0
# end
