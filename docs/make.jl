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
