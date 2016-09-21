using Documenter, CABLAB


makedocs(
    modules = [CABLAB],
    clean   = false,
    format   = Documenter.Formats.HTML,
    sitename = "CABLAB.jl",
    pages    = Any[ # Compat: `Any` for 0.4 compat
        "Home" => "index.md",
        "Manual" => Any[
            "thecube.md",
            "cube_access.md",
            "analysis.md",
            "plotting.md",
            "adding_new.md",
        ]
        ]
)

deploydocs(
    #deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/CAB-LAB/CABLAB.jl.git",
    julia  = "0.4",
    deps   = nothing,
    target = nothing
)
