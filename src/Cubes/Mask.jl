module Mask
export VALID, OCEAN, OUTOFPERIOD, MISSING, FILLED, isvalid, isinvalid,
  isvalid, isvalidorfilled, isfilled, MaskArray

const VALID=0x00
const MISSING=0x01
const OCEAN_VALID=0x04
const OCEAN=0x05
const OCEAN_MISS=0x05
const OUTOFPERIOD=0x03
const FILLED=0x08

isvalid(x::UInt8)=(x & 0x01)==0x00
isinvalid(x::UInt8)=(x & 0x01)==0x01
isfilled(x::UInt8)=(x & FILLED)==FILLED
isocean(x::UInt8)=(x & 0x04)==0x04
isoutofperiod(x::UInt8)=(x & 0x02)==0x02

isvalidorfilled(x::UInt8)=(x==VALID) || x==FILLED
function isvalidorfilled(x::AbstractArray{UInt8})
  a=true
  for i in eachindex(x)
    isvalidorfilled(x[i]) || (a=true;break)
  end
  a
end

struct MaskArray{T,N,P<:AbstractArray{T,N},P2<:AbstractArray{UInt8,N}} <: AbstractArray{Union{T,Missing},N}
    data::P
    mask::P2
end
Base.show(io::IO,m::MaskArray)=print(io,"A Mask array")
Base.size(m::MaskArray)=size(m.data)
Base.getindex(m::MaskArray,i::Int) = (m.mask[i] & 0x01)==0x01 ? missing : m.data[i]
Base.getindex(m::MaskArray{<:Any,N},i::Vararg{Int, N}) where N = (m.mask[i...] & 0x01) == 0x01 ? missing : m.data[i...]
Base.setindex!(m::MaskArray, ::Missing, i::Int) = m.mask[i]=m.mask[i] | 0x01
Base.setindex!(m::MaskArray, ::Missing, i::Vararg{Int, N}) where N = m.mask[i...]=m.mask[i...] | 0x01
function Base.setindex!(m::MaskArray, v, i::Int)
    m.mask[i] = m.mask[i] & 0xfe
    m.data[i] = v
end
function Base.setindex!(m::MaskArray{<:Any,N}, v, i::Vararg{Int, N}) where N
    m.mask[i...] = m.mask[i...] & 0xfe
    m.data[i...] = v
end
Base.Array(m::MaskArray)=map((d,ma)->iszero(ma & MISSING) ? d : missing,m.data,m.mask)
Base.view(m::MaskArray,i...)=MaskArray(view(m.data,i...),view(m.mask,i...))
Base.IndexStyle(::Type{<:MaskArray{<:Any,<:Any,P}}) where P = Base.IndexStyle(P)
Base.length(m::MaskArray)=length(m.data)
Base.ismissing(m::MaskArray, i::Integer...) = !iszero(m.mask[i...] & MISSING)
Base.dropdims(m::MaskArray;dims=dims) = MaskArray(dropdims(m.data,dims=dims),dropdims(m.mask,dims=dims))
function Base.copyto!(m1::MaskArray,m2::MaskArray)
  copyto!(m1.data,m2.data)
  copyto!(m1.mask,m2.mask)
end
Base.reshape(m::MaskArray,s::Tuple{Vararg{Int64,N}} where N)=MaskArray(reshape(m.data,s),reshape(m.mask,s))
isvalid(m::MaskArray, i::Integer...) = iszero(m.mask[i...] & MISSING)
isocean(m::MaskArray, i::Integer...) = (m.mask[i...] & OCEAN_VALID)==OCEAN_VALID
isfilled(m::MaskArray, i::Integer...) = (m.mask[i...] & FILLED)==FILLED
isoutofperiod(m::MaskArray, i::Integer...) = (m.mask[i...] & 0x02)==0x02

end
