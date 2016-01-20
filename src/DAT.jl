module DAT
export @registerDATFunction, joinVars
using CABLAB
using Base.Dates

#To fix deprecation warning
Base.broadcast(::Function)=nothing


getCheckExpr(i::Int,axtype::Symbol)=:(isa(dc.axes[$i],$axtype))
function getCheckExpr(dimsin::Vector)
    ndimin=length(dimsin)
    ex=getCheckExpr(1,dimsin[1])
    for i=2:ndimin
        ex=:($ex || $(getCheckExpr(i,dimsin[i])))
    end
    :($ex || (dc=dims2Front(dc,$(dimsin...))))
end

function getInDimExpr(ndimin)
  quote
    nfrontin=size(dc.data,$(collect(1:ndimin)...))
    nother=div(length(dc.data),prod(nfrontin))
    indata=reshape(dc.data,(nfrontin...,nother))
    inmaskfull=reshape(dc.mask,(nfrontin...,nother))
  end
end

function getOutDimExpr(ndimout,dimsout)
  if ndimout>0
    return quote
      idimout=findOutIndex(dc,$(dimsout.args...))
      nfrontout=size(dc.data,idimout...)
      outdata=zeros(eltype(dc.data),(nfrontout...,nother))
      outmaskfull=zeros(UInt8,(nfrontout...,nother))
    end
 else
   return quote
     nfrontout=()
     idimout=Int[]
     outdata=zeros(eltype(dc.data),nother)
     outmaskfull=zeros(UInt8,nother)
   end
 end
end
cubeFunctions=Dict{Symbol,Tuple}()
macro registerDATFunction(fname, dimsin, dimsout, args...)
  #Handle cases for input dimensions
  sfname=esc(fname)
  DAT.cubeFunctions[fname]=(dimsin.args...)
  fhead=Expr(:call,sfname,:(dc::CubeMem),args...)
  args2=ntuple(i->(isa(args[i],Expr) && args[i].head==:(::)) ? args[i].args[1] : args[i],length(args))
  fcall=Expr(:call,sfname,:xin,:xout,:maskin,:maskout,args2...)
  ndimin=length(dimsin.args);
  ndimout=length(dimsout.args);
  return quote
  #This generates a wrapper that takes a block of Lon-Lat-Time data and peforms the operations along Time Axis"
  $fhead=begin
    #println(size(dc))
    $(getCheckExpr(dimsin.args))
    #println(size(dc))
    $(getInDimExpr(ndimin))
    $(getOutDimExpr(ndimout,dimsout))
    for iother=1:nother
      xin=$(Expr(:call,:slice,:indata,fill(:(:),ndimin)...,:iother))
      xout=$(Expr(:call,:slice,:outdata,fill(:(:),ndimout)...,:iother))
      maskin=$(Expr(:call,:slice,:inmaskfull,fill(:(:),ndimin)...,:iother))
      maskout=$(Expr(:call,:slice,:outmaskfull,fill(:(:),ndimout)...,:iother))
      $fcall
    end
    #println(nfrontout,nbackout)
    nbackout=size(dc.data)[$(ndimin+1):end]
    CubeMem([dc.axes[idimout];dc.axes[$(ndimin+1):end]],reshape(outdata,(nfrontout...,nbackout...)),reshape(outmaskfull,(nfrontout...,nbackout...)))
  end
  #Second function
  function $(esc(fname))(dc::Cube,variable::AbstractString,time::Tuple{TimeType,TimeType},latitude::Tuple{Real,Real},longitude::Tuple{Real,Real};cache_size=1.0)
    grid_y1,grid_y2,grid_x1,grid_x2 = getLonLatsToRead(config,longitude,latitude)
    y1,i1,y2,i2,ntime,NpY = getTimesToRead(time[1],time[2],config)
    #Determine lon and latrange
    lonrange=grid_x1:grid_x2
    latrange=grid_y1:grid_y2
    timrange=i1:i2
    #We determine how many grid points should be read at once:
    #Idea: do dry run and test?
    ngridcellscache=cache_size*1e6/8/length(timrange)
    if ngridcellscache<length(lonrange) #We have to split up by longitude and latitude
      lonstep   = floor(Int,ngridcellscache/length(lonrange))
      latstep   = 1
    else # split up only by latitude
      lonstep   = length(lonrange)
      latstep   = floor(Int,ngridcellscache/length(lonrange)/length(latrange))
    end
    #Create temporary datacube on Hard Drive
    tempout = createTempCube()
    # Start the main loop
    for ilat=1:latstep:length(latrange), ilon=1:lonstep:length(lonrange)
      data=getCube(dc,variable,latitude=(ilat,ilat+latstep-1),(ilon,ilon+lonstep-1))
      resu = $(esc(fname))(data)
      saveToTemp(resu,ilat,ilon)
    end
  end
  end
end
# elseif dimsin.args==[:VariableAxis,:TimeAxis]
#   #DAT.cubeFunctions[fname]=(VariableAxis,TimeAxis)
#   fhead=Expr(:call,sfname,:(dc::CubeMem),args...)
#   args2=ntuple(i->(isa(args[i],Expr) && args[i].head==:(::)) ? args[i].args[1] : args[i],length(args))
#   fcall=Expr(:call,sfname,:xin,:xout,:mask,args2...)
#   return quote
#     #This generates a wrapper that takes a block of Lon-Lat-Time data and peforms the operations along Time Axis"
#     $fhead=begin
#       isa(dc.axes[1],VariableAxis) && isa(dc.axes[2],TimeAxis) || (dc=dims2Front(dc,VariableAxis,TimeAxis))
#       ntime=size(dc.data,2)
#       nvar=size(dc.data,1)
#       nother=div(length(dc.data),ntime*nvar)
#       indata=reshape(dc.data,(nvar,ntime,nother))
#       outdata=zeros(eltype(indata),(ntime,nother))
#       maskfull=reshape(dc.mask,(nvar,ntime,nother))
#       for iother=1:nother
#         #pxin=pointer(indata,(iother-1)*nvar*ntime+1)
#         #xin=pointer_to_array(pxin,(nvar,ntime))
#         xin=slice(indata,:,:,iother)
#         xout=slice(outdata,:,iother)
#         mask=slice(maskfull,:,iother)
#         $fcall
#       end
#       s=map(length,dc.axes)
#       masknew=reducedim(&,dc.mask,1,UInt8(0))
#       CubeMem(dc.axes[2:end],reshape(outdata,s[2:end]...),reshape(masknew,s[2:end]...))
#     end

"Find a certain axis type in a vector of Cube axes"
function findAxis{T<:CABLAB.CubeAxis}(a::Type{T},v)
    i=1
    for i=1:length(v)
        isa(v[i],a) && break
    end
    i
end

"Reshape a cube to bring the wanted dimensions to the front"
function dims2Front{T,N}(dc::CubeMem{T,N},dims...)
  axes=copy(dc.axes)
  perm=Int[i for i=1:length(axes)];
  iold=Int[]
  for i=1:length(dims) push!(iold,findAxis(dims[i],axes)) end
  iold2=sort(iold,rev=true)
  for i=1:length(iold) splice!(perm,iold2[i]) end
  perm=Int[iold;perm]
  newdata=permutedims(dc.data,ntuple(i->perm[i],N))
  newmask=permutedims(dc.mask,ntuple(i->perm[i],N))
  CubeMem(axes[perm],newdata,newmask)
end

findOutIndex(dc::CubeMem,dims...)=Int[findAxis(d,dc.axes) for d in dims]

"Function to join a Dict of several variables in a data cube to a single one."
function joinVars(d::Dict{UTF8String,Any})
  #First determine the common promote type of all variables
  vnames=collect(keys(d))
  typevec=DataType[eltype(d[vnames[i]]) for i in 1:length(vnames)]
  tcommon=reduce(promote_type,typevec[1],typevec)
  nold=prod(size(d[vnames[1]]))
  datanew=zeros(tcommon,nold*length(vnames))
  masknew=zeros(UInt8,nold*length(vnames))
  ipos=1
  for i=1:length(vnames)
    datanew[ipos:ipos+nold-1]=d[vnames[i]].data
    masknew[ipos:ipos+nold-1]=d[vnames[i]].mask
    ipos+=nold
  end
  CubeMem(CubeAxis[d[vnames[1]].axes;VariableAxis(vnames)],reshape(datanew,size(d[vnames[1]])...,length(vnames)),reshape(masknew,size(d[vnames[1]])...,length(vnames)))
end

include("msc.jl")
include("misc.jl")

end

include("Outlier.jl")
import Outlier.recurrences!
DAT.@registerDATFunction recurrences! (VariableAxis,TimeAxis) (TimeAxis,) rec_threshold::Float64 temp_excl::Int distmatspace::AbstractMatrix
