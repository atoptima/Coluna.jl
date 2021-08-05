using Documenter, Coluna, Literate, BlockDecomposition

TUTORIAL_GAP = joinpath(@__DIR__, "src", "start", "start.jl")
TUTORIAL_CALLBACKS = joinpath(@__DIR__, "src", "man", "callbacks.jl")

OUTPUT_GAP = joinpath(@__DIR__, "src", "start")
OUTPUT_CALLBACKS = joinpath(@__DIR__, "src", "man")

Literate.markdown(TUTORIAL_GAP, OUTPUT_GAP, documenter=true)
Literate.markdown(TUTORIAL_CALLBACKS, OUTPUT_CALLBACKS, documenter=true)

makedocs(
    modules = [Coluna],
    checkdocs = :exports,
    sitename = "Coluna User Guide",
    authors = "Atoptima & contributors",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        collapselevel = 1
    ),
    strict = false,
    pages = Any[
        "Introduction"   => "index.md",
        "Getting started"   => joinpath("start", "start.md"),
        "Manual" => Any[
            "Decomposition" => joinpath("man", "decomposition.md"),
            "Algorithms" => joinpath("man", "algorithm.md"),
            "Callbacks"   => joinpath("man", "callbacks.md")
        ]
    ]
)

deploydocs(
    repo = "github.com/atoptima/Coluna.jl.git",
    push_preview = true
)
