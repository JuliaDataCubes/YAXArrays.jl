using GitHub

function getavatars(; n = 90)
    contri = GitHub.contributors("JuliaDataCubes/YAXArrays.jl")[1]
    avatars = []
    contributions = []
    urls = []
    for i in eachindex(contri)
        push!(avatars, contri[i]["contributor"].avatar_url.uri)
        push!(contributions, contri[i]["contributions"])
        push!(urls, contri[i]["contributor"].html_url.uri)
    end
    p = sortperm(contributions, rev=true)
    return avatars[p], urls[p]
end

avatars, urls = getavatars(; n = 90)
for (i,a) in enumerate(avatars)
    println("""<a href="$(urls[i])" target="_blank"><img src="$(a)"></a>""")
end