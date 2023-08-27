# https://github.com/lazarusA/GoogleTrans.jl.git
using GoogleTrans
using DelimitedFiles

dest_languages = ["es", "ja", "zh", "de"]

dest_lang = "ja"
s = "creating.jl"
name = split(s, ".")[1]

path = joinpath(@__DIR__, "./examples/UserGuide/", s)
dest = translate_script(path; dest_lang)

outpath = joinpath(@__DIR__, "langs/$(dest_lang)/UserGuide")

write(joinpath(outpath, "$s"), dest)