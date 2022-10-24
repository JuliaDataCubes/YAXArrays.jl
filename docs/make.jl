using YAXArrays, Documenter, DocumenterMarkdown

deployconfig = Documenter.auto_detect_deploy_system()
Documenter.post_status(deployconfig; type="pending", repo="github.com/JuliaDataCubes/YAXArrays.jl.git")

makedocs(
    modules = [YAXArrays],
    clean   = true,
    doctest=true,
    #format   = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    sitename = "YAXArrays.jl",
    authors = "Fabian Gans et al.",
      strict=[
          :doctest,
          :linkcheck,
          :parse_error,
          :example_block,
          # Other available options are
          # :autodocs_block, :cross_references, :docs_block, :eval_block, :example_block,
          # :footnote, :meta_block, :missing_docs, :setup_block
      ], checkdocs=:all, format=Markdown(), draft=false,
      build=joinpath(@__DIR__, "docs")
)

deploydocs(; repo="github.com/JuliaDataCubes/YAXArrays.jl.git", push_preview=true,
           deps=Deps.pip("mkdocs", "pygments", "python-markdown-math", "mkdocs-material",
                         "pymdown-extensions", "mkdocstrings", "mknotebooks",
                         "pytkdocs_tweaks", "mkdocs_include_exclude_files", "jinja2", "mkdocs-video"),
           make=() -> run(`mkdocs build`), target="site", devbranch="master")
