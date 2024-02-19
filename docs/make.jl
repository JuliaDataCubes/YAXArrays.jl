using Documenter
using DocumenterVitepress
# add https://github.com/LuxDL/DocumenterVitepress.jl.git
# add DimensionalData#main
using YAXArrays

makedocs(; sitename="YAXArrays.jl", 
    authors="Fabian Gans et al.",
    modules=[YAXArrays],
    warnonly = true,
    checkdocs=:all,
    format=DocumenterVitepress.MarkdownVitepress(),
    draft=false,
    source="src",
    build=joinpath(@__DIR__, "build")
    )

# To edit the sidebar, you must edit `docs/src/.vitepress/config.mts`.

# We manually obtain the Documenter deploy configuration,
# so we can use it to set Vitepress's settings.
# TODO: make this better / encapsulate it in `makedocs`
# so the user does not need to know!
deploy_config = Documenter.auto_detect_deploy_system()
deploy_decision = Documenter.deploy_folder(
    deploy_config;
    repo="github.com/JuliaDataCubes/YAXArrays.jl.git", # this must be the full URL!
    devbranch="master",
    devurl = "dev",
    push_preview=true,
)

# VitePress relies on its config file in order to understand where files will exist.
# We need to modify this file to reflect the correct base URL, however, Documenter
# only knows about the base URL at the time of deployment.

# So, after building the Markdown, we need to modify the config file to reflect the
# correct base URL, and then build the VitePress site.
folder = deploy_decision.subfolder
println("Deploying to $folder")
vitepress_config_file = joinpath(@__DIR__, "build", ".vitepress", "config.mts")
config = read(vitepress_config_file, String)
new_config = replace(
    config, 
    "base: 'REPLACE_ME_WITH_DOCUMENTER_VITEPRESS_BASE_URL_WITH_TRAILING_SLASH'" => "base: '/YAXArrays.jl/$(folder)$(isempty(folder) ? "" : "/")'"
)
write(vitepress_config_file, new_config)

# Build the docs using `npm` - we are assuming it's installed here!
haskey(ENV, "CI") && begin
    cd(@__DIR__) do
        run(`npm run docs:build`)
    end
    touch(joinpath(@__DIR__, "build", ".vitepress", "dist", ".nojekyll"))
end

deploydocs(; 
    repo="github.com/JuliaDataCubes/YAXArrays.jl.git", # this must be the full URL!
    target="build/.vitepress/dist", # this is where Vitepress stores its output
    branch = "gh-pages",
    devbranch="master",
    push_preview = true
)