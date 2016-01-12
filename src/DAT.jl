module DAT
export @registerDATFunction, joinVars
using CABLAB
using Base.Dates





cubeFunctions=Dict{Symbol,Tuple}()
macro registerDATFunction(fname, dimsin, dimsout, args...)
  #Handle cases for input dimensions
  sfname=esc(fname)
  if dimsin.args==[:TimeAxis]
    DAT.cubeFunctions[fname]=(TimeAxis,)
    fhead=Expr(:call,sfname,:(dc::CubeMem),args...)
    args2=ntuple(i->(isa(args[i],Expr) && args[i].head==:(::)) ? args[i].args[1] : args[i],length(args))
    fcall=Expr(:call,sfname,:xin,:xout,:mask,args2...)
      return quote
          #This generates a wrapper that takes a block of Lon-Lat-Time data and peforms the operations along Time Axis"
          $fhead=begin
              isa(dc.axes[1],TimeAxis) || (dc=dims2Front(dc,TimeAxis))
              ntime=size(dc.data,1)
              nother=div(length(dc.data),ntime)
              indata=reshape(dc.data,(ntime,nother))
              outdata=zeros(eltype(indata),size(indata))
              maskfull=reshape(dc.mask,(ntime,nother))
              for iother=1:nother
                  xin=slice(indata,:,iother)
                  xout=slice(outdata,:,iother)
                  mask=slice(maskfull,:,iother)
                  $fcall
              end
              CubeMem(dc.axes,reshape(outdata,size(dc.data)),dc.mask)
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
  elseif dimsin.args==[:TimeAxis,:VariableAxis]
    DAT.cubeFunctions[fname]=(TimeAxis,VariableAxis)
    fhead=Expr(:call,sfname,:(dc::CubeMem),args...)
    args2=ntuple(i->(isa(args[i],Expr) && args[i].head==:(::)) ? args[i].args[1] : args[i],length(args))
    fcall=Expr(:call,sfname,:xin,:xout,args2...)
    return quote
      #This generates a wrapper that takes a block of Lon-Lat-Time data and peforms the operations along Time Axis"
      $fhead=begin
        isa(dc.axes[1],TimeAxis) && isa(dc.axes[1],TimeAxis,VariableAxis) || (dc=dims2Front(dc,TimeAxis))
        ntime=size(dc.data,1)
        nother=div(length(dc.data),ntime)
        indata=reshape(dc.data,(ntime,nother))
        outdata=zeros(eltype(indata),size(indata))
        for iother=1:nother
          xin=slice(indata,:,iother)
          xout=slice(outdata,:,iother)
          $fcall
        end
        CubeMem(dc.axes,reshape(outdata,size(dc.data)),dc.mask)
      end
    end
  end

end

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
  CubeMem(CubeAxis[d[vnames[1]].axes;VariableAxis{length(vnames)}(vnames)],reshape(datanew,size(d[vnames[1]])...,length(vnames)),reshape(masknew,size(d[vnames[1]])...,length(vnames)))
end

include("msc.jl")


end
