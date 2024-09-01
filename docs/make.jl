using Documenter
using DocumenterVitepress
using YAXArrays

makedocs(; sitename="YAXArrays.jl", 
    authors="Fabian Gans et al.",
    modules=[YAXArrays],
    warnonly = true, # error due to [select page](./UserGuide/select) check
    checkdocs=:all,
    format=DocumenterVitepress.MarkdownVitepress(
        repo = "github.com/JuliaDataCubes/YAXArrays.jl", # this must be the full URL!
        devbranch = "master",
        devurl = "dev";
    ),
    draft=false,
    source="src",
    build= "build",
    )
# To edit the sidebar, you must edit `docs/src/.vitepress/config.mts`.

deploydocs(; 
    repo="github.com/JuliaDataCubes/YAXArrays.jl.git", # this must be the full URL!
    target="build", # this is where Vitepress stores its output
    branch = "gh-pages",
    devbranch="master",
    push_preview = true
)