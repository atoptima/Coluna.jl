struct Preprocess <: AbstractAlgorithm end

mutable struct PreprocessData
    depth::Int
    reformulation::Reformulation # should handle reformulation & formulation
    constr_in_stack::Dict{ConstrId,Bool}
    stack::DS.Stack{Constraint}
    var_local_master_membership::Dict{VarId,Vector{Tuple{Constraint,Float64}}}
    var_local_sp_membership::Dict{VarId,Vector{Tuple{Constraint,Float64}}}
    cur_min_slack::Dict{ConstrId,Float64}
    cur_max_slack::Dict{ConstrId,Float64}
    nb_inf_sources_for_min_slack::Dict{ConstrId,Int}
    nb_inf_sources_for_max_slack::Dict{ConstrId,Int}
    preprocessed_constrs::Vector{Constraint}
    preprocessed_vars::Vector{Variable}
    cur_sp_bounds::Vector{Tuple{Int,Int}}
    printing::Bool
end

function PreprocessData(depth::Int, reformulation::Reformulation)
     cur_sp_bounds = Vector{Tuple{Int,Int}}()
#     for sp_ref in 1:length(extended_problem.pricing_vect)
#        push!(cur_sp_bounds, get_sp_convexity_bounds(extended_problem, sp_ref))
#    end
     return PreprocessData(depth, reformulation, 
             Dict{ConstrId,Bool}(), 
             DS.Stack{Constraint}(), 
             Dict{VarId,Vector{Tuple{Constraint,Float64}}}(),
             Dict{VarId,Vector{Tuple{Constraint,Float64}}}(),
             Dict{ConstrId,Float64}(),
             Dict{ConstrId,Float64}(), 
             Dict{ConstrId,Int}(),
             Dict{ConstrId,Int}(), 
             Constraint[], 
             Variable[],
             cur_sp_bounds,
             false)
end

struct PreprocessRecord <: AbstractAlgorithmRecord
     infeasible::Bool
end

function prepare!(::Type{Preprocess}, form, node, strategy_rec, params)
    @logmsg LogLevel(0) "Prepare preprocess node"
    return
end

function run!(::Type{Preprocess}, formulation, node, strategy_rec, parameters)
    @logmsg LogLevel(0) "Run preprocess node"

    alg_data = PreprocessData(node.depth, formulation)
    if initialize_constraints(alg_data)
         return PreprocessRecord(true) 
    end

#     infeas = propagation(alg) 
#     if alg.printing
#         print_preprocessing_list(alg)
#     end
#     if !infeas
#         apply_preprocessing(alg)
#     end
#     return infeas
#
    # Record
    return PreprocessRecord(false) 
end

function initialize_constraints(alg_data::PreprocessData)
    # Contains the constraints to start propagation
    constrs_to_stack = Constraint[]

    #master constraints
    master = getmaster(alg_data.reformulation)
    master_coef_matrix = getcoefmatrix(master)
    for (constr_id, constr) in filter(_active_explicit_, getconstrs(master))
        if getduty(constr) != MasterConvexityConstr
            initialize_constraint(alg_data, constr, master)
            push!(constrs_to_stack, constr)
	end
    end

    #subproblem constraints
    for subprob in alg_data.reformulation.dw_pricing_subprs 
        for (constr_id, constr) in filter(_active_explicit_, getconstrs(subprob))
            initialize_constraint(alg_data, constr, subprob)
            push!(constrs_to_stack, constr)
	end
    end

     # Adding constraints to stack
    for constr in constrs_to_stack
        if (update_min_slack(alg_data, constr, false, 0.0) 
            || update_max_slack(alg_data, constr, false, 0.0))
            return true
        end
    end

    return false
 end

function initialize_constraint(alg_data::PreprocessData, constr::Constraint, form::Formulation)
    alg_data.constr_in_stack[constr.id] = false
    update_local_membership(alg_data, constr, constr.duty, form)
    alg_data.nb_inf_sources_for_min_slack[constr.id] = 0
    alg_data.nb_inf_sources_for_max_slack[constr.id] = 0     
    compute_min_slack(alg_data, constr, form)
    compute_max_slack(alg_data, constr, form)
#     if alg.printing
#         print_constr(alg, constr)
#     end
end

function update_local_membership(alg_data::PreprocessData, 
	                         constr::Constraint, 
	                         duty::Type{<:AbstractMasterConstr},
                                 form::Formulation)
     coef_matrix = getcoefmatrix(form)
     for (var_id, var_coef) in coef_matrix[constr.id,:]
        var = getvar(form, var_id)
        if _rep_of_orig_var_(var)
           if !haskey(alg_data.var_local_master_membership, var_id)
               alg_data.var_local_master_membership[var_id] = [(constr, var_coef)]
           else
               push!(alg_data.var_local_master_membership[var_id], (constr, var_coef))
           end
	end
     end
end

function update_local_membership(alg_data::PreprocessData, 
	                         constr::Constraint, 
	                         duty::Type{<:AbstractDwSpConstr},
                                 form::Formulation)
    coef_matrix = getcoefmatrix(form)
    for (var_id, var_coef) in coef_matrix[constr.id,:]
        var = getvar(form, var_id)
        if getduty(var) == DwSpPricingVar
            if !haskey(alg_data.var_local_sp_membership, var_id)
                alg_data.var_local_sp_membership[var_id] = [(constr, var_coef)]
            else
                push!(alg_data.var_local_sp_membership[var_id], (constr, var_coef))
            end
	end
     end
end

function compute_min_slack(alg_data::PreprocessData, 
	                   constr::Constraint, 
                           form::Formulation)
    slack = getrhs(getcurdata(constr))
    if constr.duty <:AbstractMasterConstr
       var_filter = _rep_of_orig_var_ 
    else
       var_filter = (var -> (var.duty == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (var_id, coef) in coef_matrix[constr.id,:]
         var = getvar(form, var_id)
         if !var_filter(var) 
             continue
         end
         if coef > 0
             cur_ub = getub(getcurdata(var))
             if cur_ub == Inf
                 alg_data.nb_inf_sources_for_min_slack[constr.id] += 1
             else
                 slack -= coef*cur_ub
             end
         else
             cur_lb = getlb(getcurdata(var))
             if cur_lb == -Inf
                 alg_data.nb_inf_sources_for_min_slack[constr.id] += 1
             else
                 slack -= coef*cur_lb
             end
         end
     end
     alg_data.cur_min_slack[constr.id] = slack
end

function compute_max_slack(alg_data::PreprocessData, 
	                   constr::Constraint, 
                           form::Formulation)
    slack = getrhs(getcurdata(constr))
    if constr.duty <:AbstractMasterConstr
       var_filter = _rep_of_orig_var_ 
    else
       var_filter = (var -> (var.duty == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (var_id, coef) in coef_matrix[constr.id,:]
         var = getvar(form, var_id)
         if !var_filter(var) 
             continue
         end
         if coef > 0
             cur_lb = getlb(getcurdata(var))
             if cur_lb == -Inf
                 alg_data.nb_inf_sources_for_max_slack[constr.id] += 1
             else
                 slack -= coef*cur_lb
             end
         else
             cur_ub = getub(getcurdata(var))
             if cur_ub == Inf
                 alg_data.nb_inf_sources_for_max_slack[constr.id] += 1
             else
                 slack -= coef*cur_ub
             end
         end
     end
     alg_data.cur_max_slack[constr.id] = slack
 end

function update_max_slack(alg_data::PreprocessData,
	                  constr::Constraint, 
                          var_was_inf_source::Bool,
			  delta::Float64)
    alg_data.cur_max_slack[constr.id] += delta
    if var_was_inf_source
        alg_data.nb_inf_sources_for_max_slack[constr.id] -= 1
    end

    nb_inf_sources = alg_data.nb_inf_sources_for_max_slack[constr.id]
    sense = getsense(getcurdata(constr))
    if nb_inf_sources == 0
        if sense != Greater && alg_data.cur_max_slack[constr.id] < 0
            return true
        elseif sense == Greater && alg_data.cur_max_slack[constr.id] <= 0
            #add_to_preprocessing_list(alg, constr)
            return false
        end
     end
     if nb_inf_sources <= 1
         if sense != Greater
             add_to_stack(alg_data, constr)
         end
     end
     return false
end

function update_min_slack(alg_data::PreprocessData,
	                  constr::Constraint, 
                          var_was_inf_source::Bool,
			  delta::Float64)
    alg_data.cur_min_slack[constr.id] += delta
    if var_was_inf_source
        alg_data.nb_inf_sources_for_min_slack[constr.id] -= 1
    end

    nb_inf_sources = alg_data.nb_inf_sources_for_min_slack[constr.id]
    sense = getsense(getcurdata(constr))
    if nb_inf_sources == 0
        if sense != Less && alg_data.cur_min_slack[constr.id] > 0
            return true
        elseif sense == Less && alg_data.cur_min_slack[constr.id] >= 0
            #add_to_preprocessing_list(alg, constr)
            return false
        end
    end
    if nb_inf_sources <= 1
        if sense != Less
            add_to_stack(alg_data, constr)
        end
    end
    return false
end

function add_to_stack(alg_data::PreprocessData, constr::Constraint)
    if !alg_data.constr_in_stack[constr.id]
        push!(alg_data.stack, constr)
        alg_data.constr_in_stack[constr.id] = true
    end
end
      
