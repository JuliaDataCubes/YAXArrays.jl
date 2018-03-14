export InDims, OutDims
const AxisDescriptorAll = Union{AxisDescriptor,String,Type{T},CubeAxis,Function} where T<:CubeAxis

"""
    InDims(axisdesc)

Creates a description of an Input Data Cube for cube operations. Takes a single
  or a Vector/Tuple of axes as first argument. Axes can be specified by their
  name (String), through an Axis type, or by passing a concrete axis.

- axisdesc: List of input axis names
- miss: Representation of missing values for this input cube, must be a subtype of [MissingRepr](@ref)
"""
type InDims
  axisdesc::Tuple
  miss::MissingRepr
end
function InDims(axisdesc::AxisDescriptorAll...; miss::MissingRepr=DataArrayMissing())
  descs = map(get_descriptor,axisdesc)
  any(i->isa(i,ByFunction),descs) && error("Input cubes can not be specified through a function")
  InDims(descs,miss)
end

"""
    OutDims(axisdesc;...)

Creates a description of an Output Data Cube for cube operations. Takes a single
  or a Vector/Tuple of axes as first argument. Axes can be specified by their
  name (String), through an Axis type, or by passing a concrete axis.

- axisdesc: List of input axis names
- miss: Representation of missing values for this input cube, must be a subtype of [MissingRepr](@ref), defaults to `DataArrayMissing`
- genOut: function to initialize the values of the output cube given its element type. Defaults to `zero`
- finalizeOut: function to finalize the values of an output cube, defaults to identity.
- retCubeType: sepcifies the type of the return cube, can be `CubeMem` to force in-memory, `TempCube` to force disk storage, or `"auto"` to let the system decide.
- outtype: force the output type to a specific type, defaults to `Any` which means that the element type of the first input cube is used
"""
immutable OutDims
  axisdesc::Tuple
  bcaxisdesc::Tuple
  miss::MissingRepr
  genOut::Function
  finalizeOut::Function
  retCubeType::Any
  update::Bool
  outtype::Union{Int,DataType}
end
function OutDims(axisdesc...;
           bcaxisdesc=(),
           miss::MissingRepr=DataArrayMissing(),
           genOut=zero,
           finalizeOut=identity,
           retCubeType=:auto,
           update=false,
           outtype=1)
  descs = map(get_descriptor,axisdesc)
  bcdescs = totuple(map(get_descriptor,bcaxisdesc))
  update && !isa(miss,NoMissing) && error("Updating output is only possible for miss=NoMissing()")
  OutDims(descs,bcdescs,miss,genOut,finalizeOut,retCubeType,update,outtype)
end

type DATFunction
  inCubes::Tuple
  outCubes::Tuple
  no_ocean::Int
  inplace::Bool
  args::Any
end
const regDict=Dict{Function,DATFunction}()

function registerDATFunction(f;indims=nothing, outdims=nothing, no_ocean=nothing,inplace=nothing,args=(),kwargs...)
  regDict[f] = regFromScratch(indims,outdims,no_ocean,inplace,args)
end


"""
    registerDATFunction(f, dimsin, [dimsout, [addargs]]; inmissing=(:mask,...), outmissing=:mask, no_ocean=0)

Registers a function so that it can be applied to the whole data cube through mapCube.

  - `f` the function to register
  - `dimsin` a tuple containing the Axes Types that the function is supposed to work on. If multiple input cubes are needed, then a tuple of tuples must be provided
  - `dimsout` a tuple of output Axes types. If omitted, it is assumed that the output is a single value. Can also be a function with the signature (cube,pargs)-> ... which returns the output Axis. This is useful if the output axis can only be constructed based on runtime input.
  - `addargs` an optional function with the signature (cube,pargs)-> ... , to calculate function arguments that are passed to f which are only known when the function is called. Here `cube` is a tuple of input cubes provided when `mapCube` is called and `pargs` is a list of trailing arguments passed to `mapCube`. For example `(cube,pargs)->(length(getAxis(cube[1],"TimeAxis")),pargs[1])` would pass the length of the time axis and the first trailing argument of the mapCube call to each invocation of `f`
  - `inmissing` tuple of symbols, determines how to deal with missing data for each input cube. `:mask` means that masks are explicitly passed to the function call, `:nan` replaces all missing data with NaNs, and `:data` passes a DataArray to `f`
  - `outmissing` symbol, determines how missing values is the output are interpreted. Same values as for `inmissing are allowed`
  - `no_ocean` integer, if set to a value > 0, omit function calls that would act on grid cells where the first value in the mask is set to `OCEAN`.
  - `inplace::Bool` defaults to true. If `f` returns a single value, instead of writing into an output array, one can set `inplace=false`.

"""
function registerDATFunction(f,dimsin::Tuple{Vararg{Tuple}},dimsout::Tuple{Vararg{Tuple}},addargs...;outtype=Any,inmissing=ntuple(i->DataArrayMissing,length(dimsin)),outmissing=ntuple(i->DataArrayMissing,length(dimsout)),no_ocean=0,inplace=true,genOut=zero,finalizeOut=identity,outbroad=[],retCubeType="auto")
    nIn=length(dimsin)
    nOut=length(dimsout)
    inmissing=expandTuple(inmissing,nIn)
    outmissing=expandTuple(outmissing,nOut)
    outtype=expandTuple(outtype,nOut)
    genOut=expandTuple(genOut,nOut)
    finalizeOut=expandTuple(finalizeOut,nOut)
    retCubeType=expandTuple(retCubeType,nOut)
    outtype = expandTuple(outtype,nOut)
    outbroad = expandTuple(outbroad,nOut)
    if length(addargs)==1 && isa(addargs[1],Function)
      addargs=addargs[1]
    end
    inCubes = map(dimsin,inmissing) do inax,miss
      !isa(miss,MissingRepr) && (miss=toMissRepr(miss))
      isa(inax,Tuple) ? InDims(inax...,miss=miss) : InDims(inax,miss=miss)
    end
    outCubes = map(dimsout,outmissing,genOut,finalizeOut,retCubeType,outtype) do outax,miss,gen,fin,ret,out
      !isa(miss,MissingRepr) && (miss=toMissRepr(miss))
      isa(outax,Tuple) ? OutDims(outax...,miss=miss,genOut=gen,finalizeOut=fin,retCubeType=ret,outtype=out) :  OutDims(outax,miss=miss,genOut=gen,finalizeOut=fin,retCubeType=ret,outtype=out)
    end
    regDict[f]=DATFunction(inCubes,outCubes,no_ocean,inplace,addargs)
end
function registerDATFunction(f,dimsin,dimsout,addargs...;kwargs...)
  dimsin=expandTuple(dimsin,1)
  dimsout=expandTuple(dimsout,1)
  isempty(dimsin) ? (dimsin=((),)) : isa(dimsin[1],Tuple) || (dimsin=(dimsin,))
  isempty(dimsout) ? (dimsout=((),)) : isa(dimsout[1],Tuple) || (dimsout=(dimsout,))
  registerDATFunction(f,dimsin,dimsout,addargs...;kwargs...)
end
#function registerDATFunction(f,dimsin;kwargs...)
#  registerDATFunction(f,dimsin,();kwargs...)
#end

function overwrite_settings!(reginfo::DATFunction,incubes,outcubes,no_ocean,inplace)
  incubes  != nothing && (reginfo.incubes  = isa(incubes,InDims) ? [incubes] : collect(incubes))
  outcubes != nothing && (reginfo.outcubes = isa(outcubes,OutDims) ? [outcubes] : collect(outcubes))
  no_ocean != nothing && (reginfo.no_ocean = no_ocean)
  inplace  != nothing && (reginfo.inplace  = inplace)
end

function regFromScratch(incubes,outcubes,no_ocean,inplace,addargs)
  incubes  == nothing && (incubes  = InDims())
  outcubes == nothing && (outcubes = OutDims())
  no_ocean == nothing && (no_ocean = 0)
  inplace  == nothing && (inplace  = true)
  DATFunction(expandTuple(incubes,1),expandTuple(outcubes,1),no_ocean,inplace,addargs)
end
