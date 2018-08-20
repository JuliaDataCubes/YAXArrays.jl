export InDims, OutDims,AsArray,AsDataFrame,AsAxisArray
const AxisDescriptorAll = Union{AxisDescriptor,String,Type{T},CubeAxis,Function} where T<:CubeAxis

abstract type ArTypeRepr end
struct AsArray <: ArTypeRepr end
struct AsAxisArray <: ArTypeRepr end
struct AsDataFrame <: ArTypeRepr
  dimcol::Bool
end
AsDataFrame()=AsDataFrame(false)
wrapWorkArray(::AsArray,a,axes) = a
function wrapWorkArray(::AsAxisArray,a,cablabaxes)
  newaxes = map(cablabaxes) do ax
    AxisArrays.Axis{Symbol(axname(ax))}(ax.values)
  end
  AxisArrays.AxisArray(a,newaxes...)
end
import DataFrames
function wrapWorkArray(t::AsDataFrame,a,cablabaxes)
  colnames = map(Symbol,cablabaxes[2].values)
  df = DataFrames.DataFrame(a,colnames)
  if t.dimcol
    df[Symbol(axname(cablabaxes[1]))]=collect(cablabaxes[1].values)
  end
  df
end

"""
    InDims(axisdesc)

Creates a description of an Input Data Cube for cube operations. Takes a single
  or a Vector/Tuple of axes as first argument. Axes can be specified by their
  name (String), through an Axis type, or by passing a concrete axis.

- axisdesc: List of input axis names
- miss: Representation of missing values for this input cube, must be a subtype of [MissingRepr](@ref)
- include_axes: If set to `true` the array will be represented as an AxisArray inside the inner function, so that axes values can be accessed
"""
mutable struct InDims
  axisdesc::Tuple
  miss::MissingRepr
  artype::ArTypeRepr
end
function InDims(axisdesc::AxisDescriptorAll...; miss::MissingRepr=MaskMissing(),artype::ArTypeRepr=AsArray())
  descs = map(get_descriptor,axisdesc)
  any(i->isa(i,ByFunction),descs) && error("Input cubes can not be specified through a function")
  isa(artype,AsDataFrame) && length(descs)!=2 && error("DataFrame representation only possible if for 2D inner arrays")
  InDims(descs,miss,artype)
end

"""
    OutDims(axisdesc;...)

Creates a description of an Output Data Cube for cube operations. Takes a single
  or a Vector/Tuple of axes as first argument. Axes can be specified by their
  name (String), through an Axis type, or by passing a concrete axis.

- axisdesc: List of input axis names
- miss: Representation of missing values for this input cube, must be a subtype of [MissingRepr](@ref), defaults to `MaskMissing`
- genOut: function to initialize the values of the output cube given its element type. Defaults to `zero`
- finalizeOut: function to finalize the values of an output cube, defaults to identity.
- retCubeType: sepcifies the type of the return cube, can be `CubeMem` to force in-memory, `TempCube` to force disk storage, or `"auto"` to let the system decide.
- outtype: force the output type to a specific type, defaults to `Any` which means that the element type of the first input cube is used
"""
struct OutDims
  axisdesc::Tuple
  bcaxisdesc::Tuple
  miss::MissingRepr
  genOut::Function
  finalizeOut::Function
  retCubeType::Any
  update::Bool
  artype::ArTypeRepr
  outtype::Union{Int,DataType}
end
function OutDims(axisdesc...;
           bcaxisdesc=(),
           miss::MissingRepr=MaskMissing(),
           genOut=zero,
           finalizeOut=identity,
           retCubeType=:auto,
           update=false,
           artype::ArTypeRepr=AsArray(),
           outtype=1)
  descs = map(get_descriptor,axisdesc)
  bcdescs = totuple(map(get_descriptor,bcaxisdesc))
  isa(artype,AsDataFrame) && length(descs)!=2 && error("DataFrame representation only possible if for 2D inner arrays")
  update && !isa(miss,NoMissing) && error("Updating output is only possible for miss=NoMissing()")
  OutDims(descs,bcdescs,miss,genOut,finalizeOut,retCubeType,update,artype,outtype)
end

registerDATFunction(a...;kwargs...)=@warn("Registration does not exist anymore, ignoring....")
