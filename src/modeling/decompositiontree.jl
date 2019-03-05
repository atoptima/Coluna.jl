abstract type Decomposition end
struct DantzigWolfe <: Decomposition end
struct Benders <: Decomposition end
struct CombinedBendersDanztigWolfe <: Decomposition end

abstract type Problem end
struct Master <: Problem end
abstract type Subproblem <: Problem end
struct Pricing <: Subproblem end
struct Separation <: Subproblem end

struct Annotation{T, P <: Problem, D <: Decomposition}
  problem::Type{P}
  decomposition::Type{D}
  axis_index_value::T
  unique_id::Int
  min_multiplicity::Int
  max_multiplicity::Int
end

# When you call a decomposition macro, it returns a pointer to the Decomposition
# node from where the decomposition has been performed.
# A decomposition node should contains : the master & a vector of subproblems
abstract type AbstractDecompositionNode end

struct DecompositionLeaf <: AbstractDecompositionNode
  parent::AbstractDecompositionNode
  problem::Annotation
  depth::Int
end

struct DecompositionNode{T, D <: Decomposition} <: AbstractDecompositionNode
  parent::AbstractDecompositionNode
  problem::Annotation
  depth::Int
  master::Annotation
  subproblems::Dict{T, AbstractDecompositionNode}
  identical_subproblems::Bool
end

abstract type AbstractRoot <: AbstractDecompositionNode end

struct EmptyDecomposition <: AbstractRoot end

struct DecompositionRoot{T} <: AbstractRoot
  decomposition::Dict{T, AbstractDecompositionNode}
end

struct DecompositionTree
  root::AbstractRoot
  nb_masters::Int
  nb_subproblems::Int
end

DecompositionTree() = return DecompositionTree(EmptyDecomposition(), 0, 0)

# The decomposition should be done on a leaf of the decomposition tree
function register_dantzig_wolfe_decomposition!(t::DecompositionTree, 
    l::DecompositionLeaf)
  println("\e[32m Register DW decomposition at leaf. \e[00m")
end

function register_dantzig_wolfe_decomposition!(t::DecompositionTree, 
    r::EmptyDecomposition)
  println("\e[32m Register DW decomposition at root. \e[00m")
end

function register_benders_decomposition!(t::DecompositionTree, 
    l::DecompositionLeaf)
  println("\e[32m Register B decomposition at leaf. \e[00m")
end

function register_benders_decomposition!(t::DecompositionTree,
    r::EmptyDecomposition)
  println("\e[32m Register B decomposition at root. \e[00m")
end

function register_benders_dantzig_wolfe_decomposition!(t::DecompositionTree,
    l::DecompositionLeaf)
  println("\e[32m Register BDW decomposition at leaf. \e[00m")
end

function register_benders_dantzig_wolfe_decomposition!(t::DecompositionTree,
    r::EmptyDecomposition)
  println("\e[32m Register BDW decomposition at root. \e[00m")
end