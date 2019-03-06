abstract type Decomposition end
struct NoDecomposition <: Decomposition end
struct DantzigWolfe <: Decomposition end
struct Benders <: Decomposition end
struct CombinedBendersDanztigWolfe <: Decomposition end

abstract type Problem end
struct Original <: Problem end
struct Master <: Problem end
abstract type Subproblem <: Problem end
struct Pricing <: Subproblem end
struct Separation <: Subproblem end

# When you call a decomposition macro, it returns a pointer to the Decomposition
# node from where the decomposition has been performed.
# A decomposition node should contains : the master & a vector of subproblems
abstract type AbstractDecompositionNode end

mutable struct DecompositionTree
  root::AbstractDecompositionNode
  nb_masters::Int
  nb_subproblems::Int
  current_uid::Int
  function DecompositionTree(axis, init_dec::Decomposition)
    t = new()
    t.nb_masters = 0
    t.nb_subproblems = 0
    t.current_uid = 0
    r = DecompositionRoot(t, axis, init_dec)
    t.root = r
    return t
  end
end

function generateannotationid(tree)
  tree.current_uid += 1
  return tree.current_uid
end

struct Annotation{T, P <: Problem, D <: Decomposition}
  problem::Type{P}
  decomposition::Type{D}
  axis_index_value::T
  unique_id::Int
  min_multiplicity::Int
  max_multiplicity::Int
end

OriginalAnnotation() = Annotation(Original, NoDecomposition, 0, 0, 1, 1)

function MasterAnnotation(tree::DecompositionTree, d::D) where {D <: Decomposition}
  uid = generateannotationid(tree)
  return Annotation{Int, Master, D}(Master, D, 0, uid, 1, 1)
end

function Annotation(tree::DecompositionTree, p::P, d::D, v::T) where {P <: Problem, D <: Decomposition, T}
  uid = generateannotationid(tree)
  return Annotation{T, P, D}(P, D, v, uid, 1, 1)
end

function Annotation(tree::DecompositionTree, p::P, d::D, v::T, minmult::Int, maxmult::Int)  where {P <: Problem, D <: Decomposition, T}
  uid = generateannotationid(tree)
  return Annotation{T, P, D}(P, D, v, uid, minmult, maxmult)
end

struct DecompositionLeaf <: AbstractDecompositionNode
  tree::DecompositionTree # Keep a ref to DecompositionTree because it contains general data
  parent::AbstractDecompositionNode
  problem::Annotation
  depth::Int
end

struct DecompositionNode{T} <: AbstractDecompositionNode
  tree::DecompositionTree
  parent::AbstractDecompositionNode
  problem::Annotation
  depth::Int
  # Children (decomposition performed on this node)
  master::Annotation
  subproblems::Dict{T, AbstractDecompositionNode}
  identical_subproblems::Bool
end

struct DecompositionRoot{T} <: AbstractDecompositionNode
  tree::DecompositionTree
  # Current Node
  problem::Annotation
  # Children (decomposition performed on this node)
  master::Annotation
  subproblems::Dict{T, AbstractDecompositionNode}
end

annotation(n::AbstractDecompositionNode) = n.problem

function DecompositionRoot(t::DecompositionTree, a::DecompositionAxis{T, V}, init_dec::Decomposition) where {T, V <: AbstractArray{T}}
  problem = OriginalAnnotation()
  master = MasterAnnotation(t, init_dec)
  empty_dict = Dict{T, AbstractDecompositionNode}()
  return DecompositionRoot{T}(t, problem, master, empty_dict)
end

hasdecompositiontree(model::JuMP.Model) = haskey(model.ext, :decomposition_tree)

function _set_decomposition_tree_!(model::JuMP.Model, axis, init_dec::Decomposition)
  if !hasdecompositiontree(model)
    model.ext[:decomposition_tree] = DecompositionTree(axis, init_dec)
  else
    error("Cannot decompose twice at the same level.")
  end
  return
end
_set_decomposition_tree_!(n::AbstractDecompositionNode, axis, init_dec::Decomposition) = return
_get_tree_(n::AbstractDecompositionNode) = n.tree
_get_tree_(m::JuMP.Model) = m.ext[:decomposition_tree]
_get_node_(n::AbstractDecompositionNode) = n
_get_node_(m::JuMP.Model) = _get_tree_(m).root

# The decomposition should be done on a leaf of the decomposition tree
function register_dantzig_wolfe_decomposition!(t::DecompositionTree, 
    l::DecompositionLeaf)
  error("Coluna does not support nested decomposition yet.")
end

function register_dantzig_wolfe_decomposition!(tree::DecompositionTree, 
    root::DecompositionRoot, axis::Coluna.DecompositionAxis)
  for id in axis
    annotation = Annotation(tree, Pricing(), DantzigWolfe(), id)
    get!(root.subproblems, id, DecompositionLeaf(tree, root, annotation, 1))
  end
  return root
end

function register_benders_decomposition!(t::DecompositionTree, 
    l::DecompositionLeaf)
  error("Coluna does not support Benders decomposition yet.")
end

function register_benders_decomposition!(t::DecompositionTree,
    r::DecompositionRoot)
  error("Coluna does not support Benders decomposition yet.")
end

macro dantzig_wolfe_decomposition(args...)
  dec_root, name, axis = args
  exp = quote 
    Coluna._set_decomposition_tree_!($dec_root, $axis, Coluna.DantzigWolfe())
    $name = Coluna.register_dantzig_wolfe_decomposition!(Coluna._get_tree_($dec_root), Coluna._get_node_($dec_root), $axis)
  end
  return esc(exp)
end

function Base.show(io::IO, r::DecompositionRoot)
  print(io, "DecompositionRoot - ")
  show(io, r.master)
  print(io,  " with ")
  print(io, length(r.subproblems))
  println(io, " subproblems :")
  for (key, node) in r.subproblems
    print(io, "\t ")
    print(io, key)
    print(io, " => ")
    show(io, annotation(node))
    println(io, " ")
  end
  return
end

function Base.show(io::IO, a::Annotation)
  print(io, "Annotation(")
  print(io, a.problem)
  print(io, ", ")
  print(io, a.decomposition)
  print(io, ", ")
  print(io, a.min_multiplicity)
  print(io, " <= multiplicity <= ")
  print(io, a.max_multiplicity)
  print(io, ", ")
  print(io, a.unique_id)
  print(io, ")")
  return
end
