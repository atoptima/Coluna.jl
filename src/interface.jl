############################################################################################
# Algorithm API
############################################################################################
module APITMP 

"Supertype for algorithms parameters."
abstract type AbstractAlgorithm end

"""
Contains the definition of the problem tackled by the tree search algorithm and how the
nodes and transitions of the tree search space will be explored.
"""
abstract type AbstractSearchSpace end

"Algorithm that chooses next node to evaluated in the tree search algorithm."
abstract type AbstractExploreStrategy end

"A subspace obtained by successive divisions of the search space."
abstract type AbstractNode end

export AbstractAlgorithm, AbstractSearchSpace, AbstractExploreStrategy, AbstractNode

end

