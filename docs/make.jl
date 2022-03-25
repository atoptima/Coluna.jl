using Documenter, Coluna, Literate, BlockDecomposition

TUTORIAL_GAP = joinpath(@__DIR__, "src", "start", "start.jl")
TUTORIAL_CUTS = joinpath(@__DIR__, "src", "start", "cuts.jl")
TUTORIAL_PRICING = joinpath(@__DIR__, "src", "start", "pricing.jl")
TUTORIAL_CALLBACKS = joinpath(@__DIR__, "src", "man", "callbacks.jl")

OUTPUT_GAP = joinpath(@__DIR__, "src", "start")
OUTPUT_CUTS = joinpath(@__DIR__, "src", "start")
OUTPUT_PRICING = joinpath(@__DIR__, "src", "start")
OUTPUT_CALLBACKS = joinpath(@__DIR__, "src", "man")

Literate.markdown(TUTORIAL_GAP, OUTPUT_GAP, documenter=true)
Literate.markdown(TUTORIAL_CUTS, OUTPUT_CUTS, documenter=true)
Literate.markdown(TUTORIAL_PRICING, OUTPUT_PRICING, documenter=true)
Literate.markdown(TUTORIAL_CALLBACKS, OUTPUT_CALLBACKS, documenter=true)

makedocs(
    modules = [Coluna, BlockDecomposition],
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
        "Getting started"  => Any[
            "Column generation" => joinpath("start", "start.md"),
            "Valid inequalities" => joinpath("start", "cuts.md"),
            "Pricing callback" => joinpath("start", "pricing.md"),
        ],
        "Manual" => Any[
            "Decomposition" => joinpath("man", "decomposition.md"),
            "Configuration" => joinpath("man", "config.md"),
            "Algorithms" => joinpath("man", "algorithm.md"),
            "Callbacks"   => joinpath("man", "callbacks.md")
        ],
        "Q&A" => "qa.md"
    ]
)

deploydocs(
    repo = "github.com/atoptima/Coluna.jl.git",
    push_preview = true
)
