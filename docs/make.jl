using Documenter, Coluna

makedocs(
    modules = [Coluna],
    sitename = "Coluna",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    pages    = Any[
        "Home"   => "index.md",
        "Installation"   => "installation.md",
        "Quick start"   => "start.md"
    ]
)

deploydocs(
    repo = "github.com/atoptima/Coluna.jl.git",
    target = "build",
)
