using Documenter
using DocumenterVitepress
using YAXArrays

makedocs(; sitename="YAXArrays.jl", 
    authors="Fabian Gans et al.",
    modules=[YAXArrays],
    checkdocs=:all,
    format=DocumenterVitepress.MarkdownVitepress(
        repo = "github.com/JuliaDataCubes/YAXArrays.jl", # this must be the full URL!
        devbranch = "main",
        devurl = "dev";
    ),
    draft=false,
    source="src",
    build= "build",
    )
# To edit the sidebar, you must edit `docs/src/.vitepress/config.mts`.

DocumenterVitepress.deploydocs(; 
    repo="github.com/JuliaDataCubes/YAXArrays.jl.git", # this must be the full URL!
    target=joinpath(@__DIR__, "build"),
    branch = "gh-pages",
    devbranch="main",
    push_preview = true
)