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
        "Introduction"   => "introduction.md",
        "Basic Example"   => "basic.md",
    ]
)

deploydocs(
    repo = "github.com/atoptima/Coluna.jl.git",
    target = "build",
)
