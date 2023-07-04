using Documenter, DocumenterMarkdown
using Literate

get_example_path(p) = joinpath(@__DIR__, ".", "examples", p)
OUTPUT = joinpath(@__DIR__, "src", "examples", "generated")

folders = readdir(joinpath(@__DIR__, ".", "examples"))
setdiff!(folders, [".DS_Store", "tos_O1_2001-2002.nc"])
#setdiff!(folders, ["cheat_sheets"])

function getfiles()
    srcsfiles = []
    for f in folders
        names = readdir(joinpath(@__DIR__, ".", "examples", f))
        setdiff!(names, [".DS_Store", "examples_from_esdl_study_1.jl","examples_from_esdl_study_2.jl","examples_from_esdl_study_3.jl","examples_from_esdl_study_4.jl", "create_from_func.jl"])
        fpaths = "$(f)/" .* names
        srcsfiles = vcat(srcsfiles, fpaths...)
    end
    return srcsfiles
end

srcsfiles = getfiles()

for (d, paths) in (("tutorial", srcsfiles),)
    for p in paths
        Literate.markdown(get_example_path(p), joinpath(OUTPUT, dirname(p));
            documenter=true)
    end

end