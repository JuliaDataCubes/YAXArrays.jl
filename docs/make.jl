using ImageMagick, Documenter, ESDL, ESDLPlots, Cairo, Fontconfig

makedocs(
    modules = [ESDL, ESDLPlots],
    clean   = false,
    format   = Documenter.HTML(),
    sitename = "ESDL.jl",
    authors = "Fabian Gans",
    pages    = Any[ # Compat: `Any` for 0.4 compat
        "Home" => "index.md",
        "Manual" => Any[
            "cube_access.md",
            "analysis.md",
            "plotting.md",
            "iotools.md"
        ],
        "Other functions" => "./lib/misc.md"
        ]
)

deploydocs(
    #deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/esa-esdl/ESDL.jl.git",
)
