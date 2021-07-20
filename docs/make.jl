using Documenter, Coluna, Literate, BlockDecomposition

TUTORIAL = joinpath(@__DIR__, "src", "start", "start.jl")
OUTPUT = joinpath(@__DIR__, "src", "start")

Literate.markdown(TUTORIAL, OUTPUT, documenter = true)

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
