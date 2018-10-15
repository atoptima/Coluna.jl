using Documenter, Coluna

makedocs(
    modules = [Coluna],
    format = :html,
    sitename = "Coluna",
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
    osname = "linux",
    julia = "0.7",
    deps   = nothing,
    make   = nothing,
)
