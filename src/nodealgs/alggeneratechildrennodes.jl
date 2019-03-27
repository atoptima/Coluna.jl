# @hl mutable struct AlgToGenerateChildrenNodes <: AlgLike
#     depth::Int
#     extended_problem::Reformulation
# end

# function AlgToGenerateChildrenNodesBuilder(depth::Int, problem::Reformulation)
#     return (depth, problem)
# end

# abstract type RuleForUsualBranching end
# struct MostFractionalRule <: RuleForUsualBranching end
# struct LeastFractionalRule <: RuleForUsualBranching end

# @hl mutable struct UsualBranchingAlg <: AlgToGenerateChildrenNodes
#     rule::RuleForUsualBranching
#     generated_branch_constraints::Vector{MasterBranchConstr}
# end

# function UsualBranchingAlgBuilder(depth::Int, problem::Reformulation)
#     return tuplejoin(AlgToGenerateChildrenNodesBuilder(depth, problem),
#         MostFractionalRule(), MasterBranchConstr[])
# end

# function get_var_according_to_rule(rule::MostFractionalRule,
#         vars::Vector{Pair{T, Float64}}) where T <: Variable
#     best_var_val = vars[1]
#     best_frac = fract_part(best_var_val.second)
#     for var_val in vars
#         if fract_part(var_val.second) > best_frac
#             best_var_val = var_val
#             best_frac = fract_part(var_val.second)
#         end
#     end
#     return best_var_val.first, best_var_val.second
# end

# function retrieve_candidate_vars(alg::AlgToGenerateChildrenNodes,
#         var_val_map::Dict{Variable, Float64})

#     # find the fractional pure variables and aggregate the column variable
#     # values into subproblem variables
#     frac_master_vars = Pair{Variable, Float64}[]
#     subprob_vars = Dict{Variable, Float64}()
#     for var_val in var_val_map
#         if typeof(var_val.first) <: MasterVar
#             if !is_value_integer(var_val.second,
#                     alg.extended_problem.params.mip_tolerance_integrality)
#                 push!(frac_master_vars, Pair(var_val.first, var_val.second))
#             end
#         elseif typeof(var_val[1]) <: MasterColumn
#             for sp_var_val in var_val[1].solution.var_val_map
#                 val = var_val[2] * sp_var_val[2]
#                 if haskey(subprob_vars,sp_var_val[1])
#                     subprob_vars[sp_var_val[1]] += val
#                 else
#                     subprob_vars[sp_var_val[1]] = val
#                 end
#             end
#         end
#     end

#     # extract only the subproblem variables with fractional values in master
#     frac_subprob_vars = Pair{SubprobVar, Float64}[]
#     for sp_var_val in subprob_vars
#         if !is_value_integer(sp_var_val[2],
#                 alg.extended_problem.params.mip_tolerance_integrality)
#             push!(frac_subprob_vars, sp_var_val)
#         end
#     end

#     return vcat(frac_master_vars, frac_subprob_vars)
# end

# function generate_branch_constraint(alg::AlgToGenerateChildrenNodes,
#         depth::Int, var_to_branch::Variable, sense::Char, rhs::Float64)
#     extended_problem = alg.extended_problem
#     constr = MasterBranchConstrConstructor(
#         extended_problem.counter,
#         string("branch_",var_to_branch.name,"_",sense, "_", depth),
#         rhs, sense, depth, var_to_branch
#     )
#     # if extended_problem.params.node_eval_mode == SimplexCg
#     #     attach_art_var(extended_problem.art_var_manager,
#     #                    extended_problem.master_problem, constr)
#     # end
#     push!(alg.generated_branch_constraints, constr)
#     @logmsg LogLevel(-4) string(
#         "Generated branching constraint with reference ",
#         branch_constr.vc_ref)
# end

# function generate_children(node::Node, alg::AlgToGenerateChildrenNodes)
#     for constr in alg.generated_branch_constraints
#         new_node = NodeWithParent(alg.extended_problem, node)
#         new_node.depth = node.depth + 1
#         push!(new_node.local_branching_constraints, constr)
#         push!(node.children, new_node)
#     end
# end

# function perform_usual_branching(alg::AlgToGenerateChildrenNodes,
#         frac_vars::Vector{Pair{T, Float64}}) where T <: Variable

#     var_to_branch, val = get_var_according_to_rule(alg.rule, frac_vars)
#     @logmsg LogLevel(-4) string("Chosen variable to branch: ",
#         var_to_branch.name, ". With value: ", val, ". fract_part = ",
#         fract_part(val))
#     generate_branch_constraint(alg, alg.depth, var_to_branch, 'G', ceil(val))
#     generate_branch_constraint(alg, alg.depth, var_to_branch, 'L', floor(val))

# end

# function run(alg::UsualBranchingAlg, sol_to_branch::PrimalSolution)
#     @timeit to(alg) "Branching" begin

#     @logmsg LogLevel(-4) "Generating children..."
#     frac_vars = retrieve_candidate_vars(alg, sol_to_branch.var_val_map)

#     if isempty(frac_vars)
#         @logmsg LogLevel(0) string("No child nodes were generated.")
#         return true
#     end
#     perform_usual_branching(alg, frac_vars)
#     @logmsg LogLevel(0) string("Generated 2 child nodes.")

#     end
#     return false
# end
