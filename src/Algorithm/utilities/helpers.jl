############################################################################################
#
############################################################################################

is_cont_var(form, var_id) = getperenkind(form, var_id) == Continuous
is_int_val(val, tol) = abs(round(val) - val) < tol
dist_to_int(val) = min(val - floor(val), ceil(val) - val)

############################################################################################
# Iterate over variables and constraints
############################################################################################

# We need to inject the formulation in the filter function to retrieve variables & constraints
# data & filter on them.
# This has the same cost of doing a for loop but it allows separation of data manipulation
# and algorithmic logic that were mixed together in the body of the for loop.
filter_collection(filter, form, collection) = 
    Iterators.filter(filter, Iterators.zip(Iterators.cycle(Ref(form)), collection))

filter_vars(filter, form) = filter_collection(filter, form, getvars(form))
filter_constrs(filter, form) = filter_collection(filter, form, getconstrs(form))

# Predefined filters (two cases: pair and tuple):
active_and_explicit((form, key_val)) = iscuractive(form, first(key_val)) && isexplicit(form, first(key_val))
active_and_explicit((form, (id, _))) = iscuractive(form, id) && isexplicit(form, id)

duty((_, (id, _))) = getduty(id)

combine(op, args, functions...) = Iterators.mapreduce(f -> f(args...), op, functions)