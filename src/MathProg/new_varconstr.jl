# Methods for variables
getcurcost(form::Formulation, varid::VarId) = 0
setcurcost!(form::Formulation, varid::VarId, cost::Float64) = 0

getcurlb(form::Formulation, varid::VarId) = 0
setcurlb!(form::Formulation, varid::VarId, lb::Float64) = 0

getcurub(form::Formulation, varid::VarId) = 0
setcurub!(form::Formulation, varid::VarId, ub::Float64) = 0