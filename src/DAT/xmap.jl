module Xmap 
import DimensionalData: rebuild, dims, DimArrayOrStack, Dimension, basedims, 
DimTuple, _group_indices, OpaqueArray, otherdims
import DimensionalData as DD
using DiskArrays: find_subranges_sorted, chunktype_from_chunksizes, GridChunks,isdisk
using ..YAXArrays
import ..Cubes: YAXArray
import DiskArrayEngine as DAE
import IntervalSets: Interval
import DiskArrayEngine.compute

include("resample.jl")

export windows, xmap, Whole, xmap, XOutput, compute_to_zarr, xresample, MovingIntervals, XFunction, ⊘, compute

struct Whole <: DD.AbstractBins end
function DD._group_indices(dim::DD.Dimension, ::Whole; labels=nothing)
    look = DD.lookup(DD.format(DD.rebuild(dim,[first(dim) .. last(dim)])))
    DD.rebuild(dim,look), [1:length(dim)] 
end
⊘(a,b::Tuple) = windows(a,map(Base.Fix2(Pair,Whole()),map(Symbol,b))...)
⊘(a,b) = ⊘(a,(b,))
windows(A::DimArrayOrStack) = DimWindowArray(A,DD.dims(A),map(d->1:length(d),DD.dims(A)),DD.dims(A))
windows(A::DimArrayOrStack, x) = windows(A, dims(x))
#Method to group by another DimArray defined by groups. This array might be very
#large, so we will not be able to determine the groups in all cases and might 
#introduce an axis of unknown length
struct UnknownValues{T}
    eltype::Type{T}
end
struct GroupIndices{I}
    indices::I
    dims_destroyed
    dims_new
end
function windows(A::DimArrayOrStack, groups::DD.AbstractDimArray;groupname=:group, expected_groups=nothing)
    groupdims = DD.dims(groups)
    arraydims = DD.dims(A)
    expanddims = otherdims(groupdims, arraydims)
    groupdimvals = if !isnothing(expected_groups)
        expected_groups
    elseif isdisk(DD.data(groups))
        UnknownValues(eltype(groups))
    else
        ug = collect(skipmissing(unique(groups)))
        mi,ma = extrema(ug)
        if all(isinteger,ug) && length(ug)/ (ma-mi+1) > 0.5
            Int(mi):Int(ma)
        else
            sort!(ug)
        end
    end
    array_indices = map(DD.dims(A)) do d
        DD.rebuild(d,1:length(d))
    end
    newindices = GroupIndices(DD.data(groups),groupdims, DD.Dim{groupname}(groupdimvals))
    gd = DD.dims(array_indices,first(groupdims))
    newind = DD.rebuild(gd,newindices)
    array_indices_view = DD.setdims(array_indices, newind) 
    array_indices_pure = map(DD.val, DD.otherdims(array_indices_view,Base.tail(groupdims)))
    dim_orig = DD.dims(A)
    newdim_firstname = DD.rebuild(first(groupdims),groupdimvals)
    newdims = DD.setdims(dim_orig, newdim_firstname)
    newdims = DD.otherdims(newdims, Base.tail(groupdims))
    irep = DD.dimnum(newdims, first(groupdims))
    newdims = Base.setindex(newdims, DD.Dim{groupname}(groupdimvals),irep)
    return DimWindowArray(A, newdims, array_indices_pure, dim_orig)
end
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
        DD.Dimensions._extradimserror(otherdims(dimfuncs, dims(A)))

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


"""
    MovingIntervals{T, O, L, R}

A type representing a collection of intervals that can "move" based on specified offsets. 
Each interval is defined by a starting point (`i1`), an ending point (`i2`), and a set of offsets 
that determine the positions of the intervals.

# Fields
- `i1::T`: The starting point of the base interval.
- `i2::T`: The ending point of the base interval.
- `offsets::O`: A collection of offsets that shift the base interval to generate the moving intervals.

# Type Parameters
- `T`: The type of the interval bounds (`i1` and `i2`).
- `O`: The type of the offsets collection.
- `L`: The left bound type of the interval (e.g., `:open` or `:closed`).
- `R`: The right bound type of the interval (e.g., `:open` or `:closed`).

# Usage
`MovingIntervals` is typically used to create a series of intervals that are shifted by the specified offsets. 
It supports both array-based and scalar-based definitions for interval bounds and offsets.

# Example
```julia
# Create moving intervals with array-based left bounds
left_bounds = [1, 2, 3]
width = 2
intervals = MovingIntervals(:open, :closed; left=left_bounds, width=width)

# Access the first interval
first_interval = intervals[1]  # Interval(1, 3)
"""
struct MovingIntervals{T,O,L,R} <: DD.AbstractBins
    i1::T
    i2::T
    offsets::O
end
compute_steps(step::AbstractArray,_::Nothing) = step
compute_steps(step,n::Int) = range(0,step=step,length=n)
Base.getindex(m::MovingIntervals{<:Any,<:Any,L,R},i::Int) where {L,R} = Interval{L,R}(m.i1+m.offsets[i],m.i2+m.offsets[i])
function MovingIntervals(lb::Symbol=:open,rb::Symbol=:closed;left=nothing,right=nothing,step=nothing,center=nothing,width=nothing,n=nothing)
    if any(i->isa(i,AbstractArray),(left,right,center))
        width == nothing && error("Width must be specified if left, right or center are arrays")
        if left !== nothing
            i1 = first(left)
            i2 = i1+width
            offsets = left .- i1
        elseif right !== nothing
            i2 = first(right)
            i1 = i2-width
            offsets = right .- i2
        elseif center !== nothing
            i1 = first(center)-width/2
            i2 = i1+width
            offsets = center .- first(center)
        end
        return MovingIntervals{typeof(i1),typeof(offsets),lb,rb}(i1,i2,offsets)
    else
        (step===nothing) || (n===nothing) && error("Step and n must be specified if left, right or center are not arrays")
        offsets = compute_steps(step,n)
        if left !== nothing && right !== nothing
            i1 = left
            i2 = right
        elseif center !== nothing && width !== nothing
            i1 = center-width/2
            i2 = i1+width
        else
            throw(ArgumentError("Either left and right or center and width must be specified"))
        end
        return MovingIntervals{typeof(i1),typeof(offsets),lb,rb}(i1,i2,offsets)
    end
end
function DD._group_indices(dim::DD.Dimension, m::MovingIntervals{<:Any,<:Any,L,R}; labels=nothing) where {L,R}
    look = DD.lookup(dim)
    r = map(m.offsets) do off
        i = Interval{L,R}(m.i1+off,m.i2+off)
        DD.selectindices(look, i)
    end
    newdiminds = map(r) do i
       imid = first(i) + (last(i)-first(i))÷2
       dim[imid]
    end 
    look = DD.lookup(DD.format(DD.rebuild(dim,newdiminds)))
    DD.rebuild(dim,look), r
end

struct DimWindowArray{A,D,I,DO}
    data::A
    dims::D
    indices::I
    dim_orig::DO
end
Base.size(a::DimWindowArray) = length.(a.dims)
index_group(a,i) = a[i]
index_group(a::GroupIndices,i) = findall(isequal(i),a.indices)
Base.getindex(a::DimWindowArray, i::Int...) = a.data.data[map(index_group,a.indices,i)...]
DD.dims(a::DimWindowArray) = a.dims
to_windowarray(d::DimWindowArray) = d
to_windowarray(d) = windows(d)
function Base.show(io::IO, dw::DimWindowArray)
    println(io,"Windowed array view with dimensions: ")
    show(io, dw.dims)
end


struct XOutput{D<:Tuple{Vararg{DD.Dimension}},R,T}
    outaxes::D
    destroyaxes::R
    outtype::T
    properties
end
function XOutput(outaxes...; outtype=1,properties=Dict(),destroyaxes=())
    XOutput(outaxes, destroyaxes, outtype,properties)
end

_step(x::AbstractArray{<:Number}) = length(x) > 1 ? (last(x)-first(x))/(length(x)-1) : zero(eltype(x))
_step(x) = 1

function approxequal(a::DD.Dimension,b::DD.Dimension)
    DD.name(a) == DD.name(b) || return false
    if !(eltype(a) <: Number && eltype(b) <: Number)
        return isequal(a,b)
    end
    stepa = _step(a)
    stepb = _step(b)
    0.99 < stepa / stepb < 1.01 || return false
    tres = 0.001*abs(stepa)    
    all(zip(a,b)) do (x,y)
        abs(x-y) < tres
    end
end
approxequal(a::DD.Dimension) = Base.Fix1(approxequal, a)

function approxunion!(a, b)
    for bb in b
        found = false
        for aa in a
            if approxequal(aa,bb)
                found = true
                break
            end
        end
        if !found
            push!(a,bb)
        end
    end
    a
end

dataeltype(y::YAXArray) = eltype(y.data)
dataeltype(y::DimWindowArray) = eltype(y.data.data)

"""
    _groupby_xmap(f,winars...;output,inplace)

Function to handle groupby operations in `xmap`. It assumes that the only input array 
is a DimWindowArray where one of the dimensions is a GroupIndices dimension.
"""
function _groupby_xmap(f,ars...;output,inplace)

    @assert length(ars) == 1
    g = only(ars)
    inds = findall(i->isa(i,Xmap.GroupIndices), g.indices)
    #For now we allow only a single group array
    @assert length(inds) == 1
    igroup = only(inds)

    preproc, groupconv = (identity, identity)
    _f = isa(f,XFunction) ? f.f : f
    newf = DAE.disk_onlinestat(_f,preproc,groupconv)

    outputs = XOutput(g.dims[igroup],destroyaxes=DD.otherdims(g.dim_orig,g.dims))
    groupar = YAXArray(g.indices[igroup].dims_destroyed, g.indices[igroup].indices)
    xmap(newf, g.data, groupar, output=outputs)
end


"""
    xmap(f, ar...; output = nothing, inplace = nothing)

Maps a function `f` over an array of `ar` of type `YAXArray` or `DimWindowArray`.

`xmap` requires the specification of a type for the output of `f`, with a default type which is 1 indicating 
that the data type should be equal to the element type of the first input array. `output` must be a list of `XOutput` objects, where each contains a tuple of axes under which the results are stored and the type of the values stored. If `inplace` is `true`, then the original values are replaced in a place. `xmap` returns one or more objects of type `YAXArray` or `DimWindowArray` containing a view over the data passed to `f` by `overlaying` the outputs over the original data arrays. If reduction functions are specified, then the `xmap` outputs replace the original original data array with the reduced values. During the execution of `xmap`, the everything except `f` itself is compiled just once. Specifying `f` as an object of type `XFunction` waits until the actual function is called before compiling it.

xmap will return a lazy representation of the resulting array. 

* `output::Vector{XOutput}`: specifies the output arrays. Each XOutput object contains a tuple of axes (or symbols) to store the result and the element type of the output arrays.
* `inplace::Bool`: if `true` the function `f` operates in-place so that pre-allocated output buffers will be passed to the function as 



**Examples.**

    # Simple mapping
    x = xmap(+, a, b)


"""
function xmap(f, ars::Union{YAXArrays.Cubes.YAXArray,DimWindowArray}...; args=(), kwargs=(;), output = nothing,inplace=nothing)
    output === nothing && (output = default_output(f))
    inplace === nothing && (inplace = default_inplace(f))
    alldims = mapreduce(approxunion!,ars,init=[]) do ar
        DD.dims(ar)
    end
    alldims = (alldims...,)
    #Check for duplicated but different dimensions
    alldims_simple = unique(basedims(alldims))

    if length(alldims) != length(alldims_simple)
        throw(ArgumentError("Duplicated dimensions with different values"))
    end

    winars = map(to_windowarray,ars)
    #Check for any input that contains an array groupby
    is_groupby = any(winars) do a
        any(Base.Fix2(isa,GroupIndices),a.indices)
    end
    is_groupby && return _groupby_xmap(f,winars...;output,inplace)

    #Create outspecs
    if output isa XOutput
        output = (output,)
    end
    outaxinfo = map(output) do o
        r = map(o.outaxes) do ax
            ax_indim = DD.dims(alldims,ax)
            if isnothing(ax_indim)
                ax, length(o.outaxes)+length(alldims)
            else
                idim = DD.dimnum(alldims,ax)
                ax, idim
            end
        end
        outaxes = map(first,r)
        dimsmap = map(last,r)
        #Add some logic for destroying dimensions, i.e. in reducing operations
        destroydims = o.destroyaxes
        addaxes = DD.otherdims(alldims,DD.basedims(outaxes))

        
        dimsmapadd = setdiff(ntuple(identity,length(alldims)),dimsmap)
        outwindows = map(outaxes) do outax
                [Base.OneTo(length(outax))]
        end
        extrawindows = map(addaxes) do outax
            if isnothing(DD.dims(destroydims,outax))
                Base.OneTo(length(outax))
            else
                fill(1, length(outax))
            end
        end
        addaxes = map(addaxes) do outax
            if isnothing(DD.dims(destroydims,outax))
                outax
            else
                DD.reducedims(outax, DD.Dim)
            end
        end
        (outaxes...,addaxes...), (dimsmap...,dimsmapadd...), (outwindows...,extrawindows...)
    end
    outaxes = map(first,outaxinfo)
    dimsmap = map(Base.Fix2(getindex,2),outaxinfo)
    outwindows = map(last,outaxinfo)
    outtypes = []
    outspecs = map(output,outaxinfo) do o,info
        ax,dm,w = info
        outtype = if o.outtype isa Integer
            dataeltype(ars[o.outtype])
        else
            o.outtype
        end
        push!(outtypes, outtype)
        
        sout = map(win->maximum(maximum,win),w)
        DAE.create_outwindows(sout;dimsmap=dm,windows = w)
    end
    daefunction = if f isa DAE.UserOp
       f
    else
        DAE.create_userfunction(f, (outtypes...,); is_mutating=inplace,allow_threads=false,args, kwargs)
    end
    #Create DiskArrayEngine Input arrays
    input_arrays = map(ars) do ar
        a = to_windowarray(ar)
        dimsmap = map(d -> findfirst(approxequal(d), alldims), DD.dims(a))
        DAE.InputArray(a.data.data; dimsmap, windows=a.indices)
    end
    op = DAE.GMDWop(input_arrays,outspecs,daefunction)

    res = DAE.results_as_diskarrays(op)

    outproperties = map(i->i.properties,output)
    outars = map((res...,),outaxes,outproperties) do r,ax,prop
        YAXArray(ax,r,prop)
    end

    if length(outars) == 1
        return only(outars)
    else
        outars
    end
end

import Base.mapslices
function mapslices(f, d::YAXArray, addargs...; dims, kwargs...)
    !isa(dims, Tuple) && (dims = (dims,))
    dw = map(dims) do d
        Symbol(d)=>Whole()
    end
    w = windows(d,dw...)
    xmap(f,w,inplace=false)    
end

struct XFunction{F,O,I} <: Function
    f::F
    outputs::O
    inputs::I
    inplace::Bool
end
(f::XFunction)(x) = f.f(x)
(f::XFunction)(x1,x2) = f.f(x1,x2)
(f::XFunction)(x1,x2,x3) = f.f(x1,x2,x3)
(f::XFunction)(x1,x2,x3,x4) = f.f(x1,x2,x3,x4)
(f::XFunction)(x1,x2,x3,x4,x5) = f.f(x1,x2,x3,x4,x5)
(f::XFunction)(x1,x2,x3,x4,x5,x6) = f.f(x1,x2,x3,x4,x5,x6)
(f::XFunction)(x1,x2,x3,x4,x5,x6,x7) = f.f(x1,x2,x3,x4,x5,x6,x7)
(f::XFunction)(x1,x2,x3,x4,x5,x6,x7,x8) = f.f(x1,x2,x3,x4,x5,x6,x7,x8)
"""
    XFunction(f::Function; outputs = XOutput(), inputs = (),inplace=true)

Wraps any Julia function into an XFunction. The result will be callable as a normal Julia 
function. However, when broadcasting over the resulting function, the normal broadcast machinery
will be skipped and `xmap` functionality will be used for lazy broadcasting of `AbstractDimArrays` 
instead.

### Arguments

`f`: function to be wrapped

### Keyword arguments

`outputs`: either an `XOutput` or tuple of `XOutput` describing dimensions of the output array that `f` operates on
`inputs`: currently not used (yet)
`inplace`: set to `false` if `f` is not defined as an inplace function, i.e. it does not write results into its first argument
"""
function XFunction(f::Function;outputs = XOutput(), inputs = (),inplace=true)
    XFunction(f, outputs, inputs,inplace)
end
XFunction(f::XFunction;kwargs...) = f

default_inplace(f::XFunction) = f.inplace
default_inplace(f) = true
default_output(f) = XOutput()
default_output(f::XFunction) = f.outputs


function Base.broadcasted(f::XFunction,args...) 
    xmap(f,args...,output = f.outputs, inplace = f.inplace)
end
function gmwop_from_conn(conn,nodes)
    op = conn.f
    inputs = DAE.InputArray.(nodes[conn.inputids], conn.inwindows)
    outspecs = map(nodes[conn.outputids], conn.outwindows) do outnode, outwindow
      (; lw=outwindow, chunks=outnode.chunks, ismem=outnode.ismem)
    end
    DAE.GMDWop(inputs, outspecs, op)
end

function compute(yax::YAXArray,args...;kwargs...) 
    if isa(yax.data,DAE.GMWOPResult) 
        r = if any(a->isa(a.a,DAE.GMWOPResult), yax.data.op.inars)
            g = DAE.MwopGraph()
            i = DAE.to_graph!(g, yax.data)
            DAE.remove_aliases!(g)
            DAE.fuse_graph!(g)
            newop = DAE.gmwop_from_reducedgraph(g);
            DAE.results_as_diskarrays(newop)[i]
        else
            yax.data
        end
        computed = DAE.compute(r,args...;kwargs...)
        DD.rebuild(yax,computed)
    else
        @warn "Yaxarray does not wrap a computation, nothing to do"
        yax
    end
end

"""
    compute_to_zarr(ods, path; max_cache=5e8, overwrite=false)

Computes the YAXArrays dataset `ods` and saves it to a Zarr dataset at `path`.

# Arguments
- `ods`: The YAXArrays dataset to compute.
- `path`: The path to save the Zarr dataset to.

# Keywords
- `max_cache`: The maximum amount of data to cache in memory while computing the dataset.
- `overwrite`: Whether to overwrite the dataset at `path` if it already exists.
"""
function compute_to_zarr(ods, path; max_cache=5e8,overwrite=false)
    if !isa(ods,Dataset)
        throw(ArgumentError("Direct saving of YAXArrays is not supported. Please wrap your array `a` into a Dataset by calling `Dataset(layer=a)`"))
    end
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
    outars = Array{Any}(undef,length(op.outspecs))
    fill!(outars,nothing)
    for (k,v) in outnodes
        outars[v] = emptyds.cubes[k].data
    end
    runner = if DAE.Distributed.nworkers() > 1
        DAE.DaggerRunner(op,lr,outars)
    else
        DAE.LocalRunner(op,lr,outars)
    end
    run(runner)
    emptyds
end

include("broadcast.jl")

end