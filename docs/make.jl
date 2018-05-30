using Documenter, ESDL, ESDLPlots


makedocs(
    modules = [ESDL],
    clean   = false,
    format   = :html,
    sitename = "ESDL.jl",
    authors = "Fabian Gans",
    pages    = Any[ # Compat: `Any` for 0.4 compat
        "Home" => "index.md",
        "Manual" => Any[
            "thecube.md",
            "cube_access.md",
            "analysis.md",
            "plotting.md",
            "adding_new.md",
            "iotools.md"
        ]
        ]
)

deploydocs(
    #deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/CAB-LAB/ESDL.jl.git",
    julia  = "0.5",
    deps   = nothing,
    make   = nothing,
    target = "build"
)
