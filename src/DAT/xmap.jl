module Xmap 
import DimensionalData: rebuild, dims, DimArrayOrStack, Dimension, basedims, 
DimTuple, _group_indices, OpaqueArray, otherdims
import DimensionalData as DD
using DiskArrays: find_subranges_sorted, chunktype_from_chunksizes, GridChunks
using ..YAXArrays
import DiskArrayEngine as DAE

export windows, xmap, Whole, xmap, XOutput, compute_to_zarr

struct Whole <: DD.AbstractBins end
function DD._group_indices(dim::DD.Dimension, ::Whole; labels=nothing)
    look = DD.lookup(DD.format(DD.rebuild(ta.lon,[-180.0 .. 180.0])))
    DD.rebuild(dim,look), [1:length(dim)] 
end

windows(A::DimArrayOrStack) = DimWindowArray(A,DD.dims(A),map(d->1:length(d),DD.dims(A)),DD.dims(A))
windows(A::DimArrayOrStack, x) = windows(A, dims(x))
windows(A::DimArrayOrStack, dimfuncs::Dimension...) = windows(A, dimfuncs)
function windows(
    A::DimArrayOrStack, p1::Pair{<:Any,<:Base.Callable}, ps::Pair{<:Any,<:Base.Callable}...;
)
    dims = map((p1, ps...)) do (d, v)
        rebuild(basedims(d), v)
    end
    return windows(A, dims)
end
function windows(A::DimArrayOrStack, dimfuncs::DimTuple)
    length(otherdims(dimfuncs, dims(A))) > 0 &&
        Dimensions._extradimserror(otherdims(dimfuncs, dims(A)))

    # Get groups for each dimension
    dim_groups_indices = map(dimfuncs) do d
        _group_indices(dims(A, d), DD.val(d))
    end

    # Separate lookups dims from indices
    group_dims = map(first, dim_groups_indices)
    # Get indices for each group wrapped with dims for indexing
    indices = map(rebuild, group_dims, map(last, dim_groups_indices))

    array_indices = map(DD.dims(A)) do d
        DD.rebuild(d,1:length(d))
    end
    
    array_indices_view = DD.setdims(array_indices, rangeify_indices(indices))
    array_indices_pure = map(DD.val, array_indices_view)
    dim_orig = DD.dims(A)
    newdims = DD.setdims(dim_orig, group_dims)
    N = ndims(A)
    indt = map(eltype,array_indices_pure)
    et = Base.promote_op(getindex,typeof(A),indt...)
    #etdim = mapreduce(ndims ∘ eltype, +, array_indices_pure)
    return DimWindowArray(A, newdims, array_indices_pure, dim_orig)
end

function rangeify_indices(indices)
    map(indices) do d
        newvalues = map(DD.val(d)) do inds
            if !isempty(inds)
                r = first(find_subranges_sorted(inds))
                if length(r) == 1
                    return only(r)
                end
            end
            return inds
        end
        DD.rebuild(d,newvalues)
    end
end



struct DimWindowArray{A,D,I,DO}
    data::A
    dims::D
    indices::I
    dim_orig::DO
end
Base.size(a::DimWindowArray) = length.(a.indices)
Base.getindex(a::DimWindowArray, i::Int...) = a.data[map(getindex,a.indices,i)...]
DD.dims(a::DimWindowArray) = a.dims
to_windowarray(d::DimWindowArray) = d
to_windowarray(d) = windows(d)
function Base.show(io::IO, dw::DimWindowArray)
    println(io,"Windowed array view with dimensions: ")
    show(io, dw.dims)
end

struct XOutput
    outaxes
    outtype
end
function XOutput(outaxes...; outtype=1)
    XOutput(outaxes, outtype)
end


function xmap(f, ars::Union{YAXArrays.Cubes.YAXArray,DimWindowArray}...; output = XOutput())
    alldims = mapreduce(union,ars,init=[]) do ar
        DD.dims(ar)
    end
    alldims = (alldims...,)
    #Check for duplicated but different dimensions
    alldims_simple = unique(basedims(alldims))
    if length(alldims) != length(alldims_simple)
        throw(ArgumentError("Duplicated dimensions with different values"))
    end

    #Create outspecs
    if output isa XOutput
        output = (output,)
    end
    daefunction = DAE.create_userfunction(f,map(o->o.outtype,output), is_mutating=true)

    outspecs = map(output) do o
        outtype = if o.outtype isa Integer
            eltype(input_arrays[o.outtype].a.data)
        else
            o.outtype
        end
        extrawindows = map(o.outaxes) do ax
            [Base.OneTo(length(ax))]
        end
        extrasize = map(length,o.outaxes)
        sout = (extrasize...,map(length,alldims)...)
        dimsmap = (ntuple(identity,length(extrasize))...,(ntuple(identity,length(alldims)).+1)...)
        DAE.create_outwindows(sout;dimsmap=dimsmap,windows = (extrawindows...,map(Base.OneTo,length.(alldims))...))
    end
    #Create DiskArrayEngine Input arrays
    input_arrays = map(ars) do ar
        a = to_windowarray(ar)
        dimsmap = map(d->findfirst(==(d),alldims),DD.dims(a)).+1
        DAE.InputArray(a.data;dimsmap, windows=a.indices)
    end
    op = DAE.GMDWop(input_arrays,outspecs,daefunction)

    res = DAE.results_as_diskarrays(op)

    outars = map((res...,),output) do r,o
        YAXArray((o.outaxes...,alldims...),r)
    end

    if length(outars) == 1
        return only(outars)
    else
        outars
    end
end

function gmwop_from_conn(conn,nodes)
    op = conn.f
    inputs = DAE.InputArray.(nodes[conn.inputids], conn.inwindows)
    outspecs = map(nodes[conn.outputids], conn.outwindows) do outnode, outwindow
      (; lw=outwindow, chunks=outnode.chunks, ismem=outnode.ismem)
    end
    DAE.GMDWop(inputs, outspecs, op)
end

function compute_to_zarr(ods, path; max_cache=5e8,overwrite=false)
    g = DAE.MwopGraph()
    outnodes = Dict()
    for k in keys(ods.cubes)
        outnodes[k] = DAE.to_graph!(g, ods.cubes[k].data);
    end
    DAE.fuse_graph!(g)
    op = YAXArrays.Xmap.gmwop_from_conn(only(g.connections),g.nodes);
    lr = DAE.optimize_loopranges(op,max_cache)

    newcubes = map(collect(keys(outnodes))) do k
        looprange = lr.lr.members
        lw = op.outspecs[1].lw
        mylr = DAE.mysub(lw,looprange)
        newcs = map(mylr,lw.windows.members) do mlr, w
            map(mlr) do lr
                DAE.windowmin(w[first(lr)]):DAE.windowmax(w[last(lr)]) |> length
            end |> chunktype_from_chunksizes
        end |> GridChunks
        k=>YAXArrays.Datasets.setchunks(ods.cubes[k],newcs)
    end
    newds = Dataset(;newcubes...)

    emptyds = savedataset(newds,path=path,skeleton=true, overwrite=true)
    outars = Array{Any}(undef,length(newcubes))
    for (k,v) in outnodes
        outars[v] = emptyds.cubes[k].data
    end
    runner = DAE.LocalRunner(op,lr,outars);
    run(runner)
end


end