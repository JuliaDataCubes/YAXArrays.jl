module SentinelMissings
struct SentinelMissing{T,SV} <: Number
    x::T
end
Base.promote_rule(::Type{SentinelMissing{SM,SV}}, ::Union{T,Missing}) where {SM,SV,T} =
    Union{promote_type(SM, T),Missing}
Base.promote_rule(::Type{SentinelMissing{SM,SV}}, ::Type{T}) where {SM,SV,T} =
    Union{promote_type(SM, T),Missing}
Base.promote_rule(
    ::Type{SentinelMissing{SM,SV}},
    ::Type{SentinelMissing{SM,SV}},
) where {SM,SV} = Union{SM,Missing}
Base.convert(::Type{Union{T,Missing}}, sm::SentinelMissing) where {T} =
    ismissing(sm) ? missing : convert(T, sm[])
Base.convert(::Type{T}, sm::SentinelMissing) where {T<:Number} = convert(T, sm[])
Base.getindex(x::SentinelMissing) = ismissing(x) ? missing : x.x
Base.convert(::Type{Any}, sm::SentinelMissing) = sm[]
Base.ismissing(x::SentinelMissing) = isequal(x.x, senval(x))
Base.nonmissingtype(::Type{SentinelMissing{T,SV}}) where {T,SV} = T
Base.isless(x::SentinelMissing, y::SentinelMissing) = isless(x[], y[])
Base.isless(x::SentinelMissing, y::Number) = isless(x[], y)
Base.isless(y::Number, x::SentinelMissing) = isless(y, x[])
function Base.convert(::Type{<:T}, x::Number) where {T<:SentinelMissing}
    sv = senval(T)
    et = eltype(T)
    SentinelMissing{et,sv}(convert(et, x))
end
Base.convert(::Type{<:T}, x::Missing) where {T<:SentinelMissing} =
    SentinelMissing{eltype(T),senval(T)}(senval(T))
for op in (:(+), :(-), :(*), :(/), :(^))
    eval(
        :(
            Base.$(op)(x1::T, x2::T) where {T<:SentinelMissing{SM}} where {SM} =
                $(op)(convert(Union{SM,Missing}, x1), convert(Union{SM,Missing}, x2))
        ),
    )
end
Base.zero(T::Type{<:SentinelMissing{SM}}) where {SM} = T(zero(SM))
Base.one(T::Type{<:SentinelMissing{SM}}) where {SM} = T(one(SM))
Base.convert(::Type{<:T}, x::T) where {T<:SentinelMissing} = x
senval(::SentinelMissing{<:Any,SV}) where {SV} = SV
senval(::Type{<:SentinelMissing{<:Any,SV}}) where {SV} = SV
Base.eltype(::Type{<:SentinelMissing{T}}) where {T} = T
Base.show(io::IO, x::SentinelMissing) = print(io, x[])
Base.similar(x::AbstractArray{<:SentinelMissing{T,SV}}) where {T,SV} =
    zeros(Union{T,Missing}, size(x))
Base.similar(
    x::AbstractArray{<:SentinelMissing{T,SV}},
    dims::Tuple{Vararg{Int64,N}},
) where {T,SV,N} = zeros(Union{T,Missing}, dims)

"""
    as_sentinel(x, v)

Reinterprets a Number Array or a Number `x` so that values in x that equal v will be treated as missing.
This is done by reinterpreting the array as a `SentinelMissing` without copying the data.
"""
as_sentinel(x::AbstractArray{T}, v) where {T<:Number} =
    reinterpret(SentinelMissing{T,convert(T, v)}, x)
as_sentinel(x::T, v) where {T<:Number} = SentinelMissing{T,convert(T, v)}(x)
export as_sentinel
end
