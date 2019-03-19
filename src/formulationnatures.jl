
    

struct NoSubproblem <: AbstractSubproblems end

struct LazySeparationSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct UserSeparationSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct BlockGenSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct BendersSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct DantzigWolfeSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct HybdridSubproblems <: AbstractSubproblems
    subproblems::Vector{AbstractSubproblems}
end
