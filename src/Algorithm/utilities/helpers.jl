is_cont_var(form, var_id) = getperenkind(form, var_id) == Continuous
is_int_val(val, tol) = abs(round(val) - val) < tol