# Functions to be implemented, so that an array type
# can be used as an ESDLArray. Here fakkback methods are implemented
# for the AbstractArray's
dimvals(x::AbstractArray, i) = axes(x,i)

dimname(::AbstractArray,i) = Symbol(i->"Dim_",i)
#Mandatory interface ends here
# Optional methods
function iscontdim(x, i)
  v = dimvals(x,i)
  isa(eltype(v), Number) && (issorted(v) || issorted(v,rev=true))
end

iscompressed(x) = false

dimnames(x::AbstractArray) = ntuple(i->dimname(x,i), ndims(x))

getattributes(x::AbstractArray) = Dict{String,Any}()
# Implementation for ESDLArray
dimvals(x::ESDLArray, i) = x.axes[i].values

function dimname(x::ESDLArray, i)
  axsym(x.axes[i])
end

getattributes(x::ESDLArray) = x.properties

iscontdim(x::ESDLArray, i) = isa(x.axes[i], RangeAxis)
