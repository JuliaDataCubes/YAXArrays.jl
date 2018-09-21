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

struct MaskArray{T,N,P<:AbstractArray{T,N}}<: AbstractArray{Union{T,Missing},N}
    data::P
    mask::Array{UInt8,N}
end
function MaskArray(data::AbstractArray, mask::AbstractArray{UInt8})
    size(data)==size(mask) || throw(DimensionMismatch("Data and Mask array must have the same size"))
    MaskArray(data,mask)
end
Base.size(m::MaskArray)=size(m.data)
Base.getindex(m::MaskArray,i::Int)=(m.mask[i] & 0x01)==0x01 ? missing : m.data[i]
Base.setindex!(m::MaskArray, ::Missing, i::Int) = m.mask[i]=m.mask[i] | 0x01
function Base.setindex!(m::MaskArray, v, i::Int)
    m.mask[i] = m.mask[i] & 0xfe
    m.data[i] = v
end
Base.IndexStyle(::Type{<:MaskArray})=IndexLinear()
Base.length(m::MaskArray)=length(m.data)
Base.ismissing(m::MaskArray, i::Integer...) = !iszero(m.mask[i...] & MISSING)
isvalid(m::MaskArray, i::Integer...) = iszero(m.mask[i...] & MISSING)
isocean(m::MaskArray, i::Integer...) = (m.mask[i...] & OCEAN_VALID)==OCEAN_VALID
isfilled(m::MaskArray, i::Integer...) = (m.mask[i...] & FILLED)==FILLED
isoutofperiod(m::MaskArray, i::Integer...) = (m.mask[i...] & 0x02)==0x02

end
