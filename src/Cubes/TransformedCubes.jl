export ConcatCube, concatenateCubes
export mergeAxes
import ..Cubes: YAXArray, iscompressed, cubechunks, chunkoffset
using DiskArrayTools: diskstack, DiskArrayTools

function Base.map(op, incubes::YAXArray...)
    axlist = DD.dims(incubes[1])
    @debug axlist
    chunks = incubes[1].chunks
    [@debug DD.dims(c) for c in incubes]
    all(i-> eachchunk(i) == chunks, incubes) || error("All chunk sizes must match, consider resetting the chunks to a common size using `setchunks`")
    all(i -> DD.dims(i) == axlist, incubes) || error("All axes must match")
    props = merge(getattributes.(incubes)...)
    YAXArray(
        axlist,
        broadcast(op, map(c -> getdata(c), incubes)...),
        props,
        chunks,
        mapreduce(i -> i.cleaner, append!, incubes),
    )
end

"""
    function concatenateCubes(cubelist, cataxis::CategoricalAxis)

Concatenates a vector of datacubes that have identical axes to a new single cube along the new
axis `cataxis`
"""
function concatenatecubes(cl, cataxis::DD.Dimension)
    length(cataxis) == length(cl) ||
        error("cataxis must have same length as cube list")
    firstnontrivialcube = findfirst(c->ndims(c)>0, cl)
    axlist = DD.rebuild.(DD.dims(cl[firstnontrivialcube]))
    T = eltype(cl[firstnontrivialcube])
    N = ndims(cl[firstnontrivialcube])
    chunks = eachchunk(cl[firstnontrivialcube])
    cleaners = CleanMe[]
    append!(cleaners, cl[firstnontrivialcube].cleaner)
    for i = 2:length(cl)
        all(DD.dims(cl[i]) .== axlist) ||
            error("All cubes must have the same axes, cube number $i does not match")
        eltype(cl[i]) == T || error(
            "All cubes must have the same element type, cube number $i does not match",
        )
        ndims(cl[i]) == N || error("All cubes must have the same dimension")
        eachchunk(cl[i]) == chunks || error("Trying to concatenate cubes with different chunk sizes. Consider manually setting a common chunk size using `setchunks`.")
        append!(cleaners, cl[i].cleaner)
    end
    props = mapreduce(getattributes, merge, cl, init = getattributes(cl[firstnontrivialcube]))
    newchunks = GridChunks((chunks.chunks...,DiskArrays.RegularChunks(1,0,length(cataxis))))
    @show axlist
    @show typeof(axlist)
    YAXArray((axlist... , cataxis), diskstack([getdata(c) for c in cl]), props, newchunks, cleaners)
end
function concatenatecubes(; kwargs...)
    cubenames = String[]
    for (n, c) in kwargs
        push!(cubenames, string(n))
    end
    cubes = map(i -> i[2], collect(kwargs))
    findAxis("Variable", cubes[1]) === nothing ||
        error("Input cubes must not contain a variable kwarg concatenation")
    concatenateCubes(cubes, CategoricalAxis("Variable", cubenames))
end
