# Getters & setters for AbstractVcData

is_active(vc::AbstractVcData) = vc.is_active
is_explicit(vc::AbstractVcData) = vc.is_explicit
get_kind(vc::AbstractVcData) = vc.kind
get_sense(vc::AbstractVcData) = vc.sense
get_inc_val(vc::AbstractVcData) = vc.inc_val

set_inc_val!(vc::AbstractVcData, val::Float64) =  vc.inc_val = val
set_is_active!(vc::AbstractVcData, is_active::Bool) = vc.is_active = is_active
set_is_explicit!(vc::AbstractVcData, is_explicit::Bool) = vc.is_explicit = is_explicit
set_kind!(vc::AbstractVcData, kind) = vc.kind = kind
set_sense!(vc::AbstractVcData, sense) = vc.sense = sense


# Getters for AbstractVarConstr
# -> No setters because Variable and Constraint are immutable

get_id(vc::AbstractVarConstr) = vc.id
get_name(vc::AbstractVarConstr) = vc.name
get_duty(vc::AbstractVarConstr) = vc.duty
get_initial_data(vc::AbstractVarConstr) = vc.initial_data
get_cur_data(vc::AbstractVarConstr) = vc.cur_data
get_moi_record(vc::AbstractVarConstr) = vc.moi_record

# Helpers for getters  and stter that acces fields in a level
# under Variable or Constraint

# Variable

# -> Initial
get_init_cost(vc::AbstractVarConstr) = vc.initial_data.cost
get_init_lower_bound(vc::AbstractVarConstr) = vc.initial_data.lower_bound
get_init_upper_bound(vc::AbstractVarConstr) = vc.initial_data.upper_bound
set_init_cost!(vc::AbstractVarConstr, cost::Float64) = vc.initial_data.cost
set_init_lower_bound!(vc::AbstractVarConstr, lb::Float64) = vc.initial_data.lower_bound = lb
set_init_upper_bound!(vc::AbstractVarConstr, ub::Float64) = vc.initial_data.upper_bound = ub
# -> Current
get_cur_cost(vc::AbstractVarConstr) = vc.cur_data.cost
get_cur_lower_bound(vc::AbstractVarConstr) = vc.cur_data.lower_bound
get_cur_upper_bound(vc::AbstractVarConstr) = vc.cur_data.upper_bound
set_cur_cost!(vc::AbstractVarConstr, cost::Float64) = vc.cur_data.cost
set_cur_lower_bound!(vc::AbstractVarConstr, lb::Float64) = vc.cur_data.lower_bound = lb
set_cur_upper_bound!(vc::AbstractVarConstr, ub::Float64) = vc.cur_data.upper_bound = ub

# Constraint

# -> Initial
get_cur_rhs(vc::AbstractVarConstr) = vc.cur_data.rhs
set_cur_rhs!(vc::AbstractVarConstr, rhs::Float64) = vc.cur_data.rhs = rhs
# -> Current
get_init_rhs(vc::AbstractVarConstr) = vc.initial_data.rhs
set_init_rhs!(vc::AbstractVarConstr, rhs::Float64) = vc.initial_data.rhs = rhs


# AbstractVarConstr

get_uid(vc::AbstractVarConstr) = get_uid(vc.id)
get_form(vc::AbstractVarConstr) = getformuid(vc.id)

# -> Initial
get_init_kind(vc::AbstractVarConstr) = vc.initial_data.kind
get_init_sense(vc::AbstractVarConstr) = vc.initial_data.sense
get_init_inc_val(vc::AbstractVarConstr) = vc.initial_data.inc_val
get_init_is_active(vc::AbstractVarConstr) = vc.initial_data.is_active
get_init_is_explicit(vc::AbstractVarConstr) = vc.initial_data.is_explicit
set_init_kind(vc::AbstractVarConstr, kind) = vc.initial_data.kind = kind
set_init_sense(vc::AbstractVarConstr, sense) = vc.initial_data.sense = sense
set_init_inc_val(vc::AbstractVarConstr, inc_val::Float64) = vc.initial_data.inc_val = inc_val
set_init_is_active(vc::AbstractVarConstr, is_active::Bool) = vc.initial_data.is_active = is_active
set_init_is_explicit(vc::AbstractVarConstr, is_explicit::Bool) = vc.initial_data.is_explicit = is_explicit
# -> Current
get_cur_kind(vc::AbstractVarConstr) = vc.cur_data.kind
get_cur_sense(vc::AbstractVarConstr) = vc.cur_data.sense
get_cur_inc_val(vc::AbstractVarConstr) = vc.cur_data.inc_val
get_cur_is_active(vc::AbstractVarConstr) = vc.cur_data.is_active
get_cur_is_explicit(vc::AbstractVarConstr) = vc.cur_data.is_explicit
set_cur_kind(vc::AbstractVarConstr, kind) = vc.cur_data.kind = kind
set_cur_sense(vc::AbstractVarConstr, sense) = vc.cur_data.sense = sense
set_cur_inc_val(vc::AbstractVarConstr, inc_val::Float64) = vc.cur_data.inc_val = inc_val
set_cur_is_active(vc::AbstractVarConstr, is_active::Bool) = vc.cur_data.is_active = is_active
set_cur_is_explicit(vc::AbstractVarConstr, is_explicit::Bool) = vc.cur_data.is_explicit = is_explicit
