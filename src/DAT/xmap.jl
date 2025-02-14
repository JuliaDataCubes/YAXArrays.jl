module Xmap 
import DimensionalData: rebuild, dims, DimArrayOrStack, Dimension, basedims, 
DimTuple, _group_indices, OpaqueArray, otherdims
import DimensionalData as DD
using DiskArrays: find_subranges_sorted

export windows, xmap, Whole

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





end