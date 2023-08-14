using Documenter, Coluna, Literate, BlockDecomposition, Parameters, DocumenterMermaid

TUTORIAL_GAP = joinpath(@__DIR__, "src", "start", "start.jl")
TUTORIAL_CUTS = joinpath(@__DIR__, "src", "start", "cuts.jl")
TUTORIAL_PRICING = joinpath(@__DIR__, "src", "start", "pricing.jl")
TUTORIAL_IDENTICAL_SP = joinpath(@__DIR__, "src", "start", "identical_sp.jl")
TUTORIAL_CUSTOMDATA = joinpath(@__DIR__, "src", "start", "custom_data.jl")
TUTORIAL_INITCOLS = joinpath(@__DIR__, "src", "start", "initial_columns.jl")
TUTORIAL_ADVANCED = joinpath(@__DIR__, "src", "start", "advanced_demo.jl")
TUTORIAL_STORAGE_API = joinpath(@__DIR__, "src", "api", "storage.jl")

OUTPUT_GAP = joinpath(@__DIR__, "src", "start")
OUTPUT_CUTS = joinpath(@__DIR__, "src", "start")
OUTPUT_PRICING = joinpath(@__DIR__, "src", "start")
OUTPUT_IDENTICAL_SP = joinpath(@__DIR__, "src", "start")
OUTPUT_CUSTOMDATA = joinpath(@__DIR__, "src", "start")
OUTPUT_INITCOLS = joinpath(@__DIR__, "src", "start")
OUTPUT_ADVANCED = joinpath(@__DIR__, "src", "start")
OUTPUT_STORAGE_API = joinpath(@__DIR__, "src", "api")

Literate.markdown(TUTORIAL_GAP, OUTPUT_GAP, documenter=true)
Literate.markdown(TUTORIAL_CUTS, OUTPUT_CUTS, documenter=true)
Literate.markdown(TUTORIAL_PRICING, OUTPUT_PRICING, documenter=true)
Literate.markdown(TUTORIAL_IDENTICAL_SP, OUTPUT_IDENTICAL_SP, documenter=true)
Literate.markdown(TUTORIAL_CUSTOMDATA, OUTPUT_CUSTOMDATA, documenter=true)
Literate.markdown(TUTORIAL_INITCOLS, OUTPUT_INITCOLS, documenter=true)
Literate.markdown(TUTORIAL_ADVANCED, OUTPUT_ADVANCED, documenter=true)
Literate.markdown(TUTORIAL_STORAGE_API, OUTPUT_STORAGE_API, documenter=true)

makedocs(
    modules = [Coluna, BlockDecomposition],
    checkdocs = :exports,
    sitename = "Coluna.jl",
    authors = "Atoptima & contributors",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        collapselevel = 2,
        assets = ["assets/js/init.js"]
    ),
    strict = false,
    pages = Any[
        "Introduction"   => "index.md",
        "Tutorials"  => Any[
            "Getting Started" => Any[
                "Column generation" => joinpath("start", "start.md"),
                "Cut Generation" => joinpath("start", "cuts.md"),
                "Pricing callback" => joinpath("start", "pricing.md"),
                "Identical subproblems" => joinpath("start", "identical_sp.md"),
                "Custom data" => joinpath("start", "custom_data.md"),
                "Initial columns callback" => joinpath("start", "initial_columns.md")
            ],
            "Advanced tutorials" => Any[
                "Column Generation and Benders on Location Routing" => joinpath("start", "advanced_demo.md"),
                "Other classic problems" => joinpath("start", "other_pbs.md")
            ]
        ],
        "Manual" => Any[
            "Decomposition" => Any[
                "Decomposition paradigms" => joinpath("man", "decomposition.md"),
                "Setup decomposition using BlockDecomposition" => joinpath("man", "blockdecomposition.md")
            ],
            "Configuration" => joinpath("man", "config.md"),
            "Built-in algorithms" => joinpath("man", "algorithm.md"),
            "User-defined Callbacks"   => joinpath("man", "callbacks.md"),
        ],
        "API" => Any[
            "Algorithms" => joinpath("api", "algos.md"),
            "Benders" => joinpath("api", "benders.md"),
            "Branching" => joinpath("api", "branching.md"),
            "ColGen" => joinpath("api", "colgen.md"),
            "TreeSearch" => joinpath("api", "treesearch.md"),
            "Storage" => joinpath("api", "storage.md"),
        ],
        "Dynamic Sparse Arrays" => "dynamic_sparse_arrays.md",
        "Q&A" => "qa.md",
    ]
)

deploydocs(
    repo = "github.com/atoptima/Coluna.jl.git",
    push_preview = true
)
