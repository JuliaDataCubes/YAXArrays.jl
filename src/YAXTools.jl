module YAXTools
using Distributed
import ..YAXArrays: YAXdir
export freshworkermodule, passobj, @everywhereelsem, PickAxisArray, Window

struct PickAxisArray{T,N,AT<:AbstractArray,P,PERM}
    parent::AT
end

struct Window
    i::Int
    pre::Int
    after::Int
end


function PickAxisArray(parent, indmask, perm=nothing)
    f = findall(isequal(true), indmask)
    f2 = findall(isequal(Colon()), indmask)
    f3 = findall(i -> isa(i, Tuple{Int,Int}), indmask)
    o = sort([f; f2; f3])
    o = isempty(f2) ? o : replace(o, map(i -> i => Colon(), f2)...)
    o = isempty(f3) ? o : replace(o, map(i -> i => Window(i, indmask[i]...), f3)...)
    nsub = 0
    for i = eachindex(o)
        if o[i] isa Colon
            nsub += 1
        elseif o[i] isa Window
            o[i] = Window(o[i].i - nsub, o[i].pre, o[i].after)
        else
            o[i] = o[i] - nsub
        end
    end
    if perm !== nothing
        length(perm) != length(f2) + length(f3) && error("Not a valid permutation")
        perm = (perm...,)
    end
    PickAxisArray{eltype(parent),length(indmask),typeof(parent),(o...,),perm}(parent)
end
indmask(::PickAxisArray{<:Any,<:Any,<:Any,i}) where {i} = i
getind(i, j) = i[j]
getind(i, j::Colon) = j
function getind(i, j::Window)
    c = i[j.i]
    c-j.pre:c+j.after
end

permout(::PickAxisArray{<:Any,<:Any,<:Any,<:Any,P}, x) where {P} = permutedims(x, P)
permout(::PickAxisArray{<:Any,<:Any,<:Any,<:Any,nothing}, x) = x
function Base.view(p::PickAxisArray, i::Integer...)
    inew = map(j -> getind(i, j), indmask(p))
    r = permout(p, view(p.parent, inew...))
    r
end
function Base.getindex(p::PickAxisArray, i::Integer...)
    inew = map(j -> getind(i, j), indmask(p))
    permout(p, getindex(p.parent, inew...))
end
anycol(::Tuple{}) = false
anycol(t::Tuple) = anycol(first(t), Base.tail(t))
anycol(::Union{Colon,Window}, t::Tuple) = true
anycol(i, ::Tuple{}) = false
anycol(::Union{Colon,Window}, ::Tuple{}) = true
anycol(i, t::Tuple) = anycol(first(t), Base.tail(t))


ncol(t::Tuple) = ncol(first(t), Base.tail(t), 0)
ncol(::Union{Colon,Window}, t::Tuple, n) = ncol(first(t), Base.tail(t), n + 1)
ncol(i, ::Tuple{}, n) = n
ncol(::Union{Colon,Window}, ::Tuple{}, n) = n + 1
ncol(i, t::Tuple, n) = ncol(first(t), Base.tail(t), n)

function Base.eltype(p::PickAxisArray{T}) where {T}
    im = indmask(p)
    if anycol(im)
        Array{T,ncol(im)}
    else
        T
    end
end
Base.getindex(p::PickAxisArray, i::CartesianIndex) = p[i.I...]
end