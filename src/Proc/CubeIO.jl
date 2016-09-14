module CubeIO
importall ..Cubes
importall ..DAT
importall ..CubeAPI
importall ..CubeAPI.CachedArrays
importall ..Proc
exportmissval(x::AbstractFloat)=oftype(x,NaN)
exportmissval(x::Integer)=typemax(x)

function copyMAP(xout::AbstractArray,maskout::AbstractArray{UInt8},xin::AbstractArray,maskin::AbstractArray{UInt8})
    #Start loop through all other variables
    for (iout,vin,min) in zip(eachindex(xout),xin,maskin)
      if (x>UInt8(0)) || (x & FILLED)==FILLED
        xout[iout]=vin
      else
        xout[iout]=exportmissval(vin)
      end
      maskout[iout]=min
    end
end

import NetCDF.ncread, NetCDF.ncclose
import StatsBase.WeightVec
import StatsBase.sample
#function readLandSea(c::Cube)
#    m=ncread(joinpath(c.base_dir,"mask","mask.nc"),"mask")
#    scale!(m,OCEAN)
#    a1=LonAxis((c.config.grid_x0:(c.config.grid_width-1))*c.config.spatial_res+c.config.spatial_res/2-180.0)
#    a2=LatAxis(90.0-(c.config.grid_y0:(c.config.grid_height-1))*c.config.spatial_res-c.config.spatial_res/2)
#    ncclose(joinpath(c.base_dir,"mask","mask.nc"))
#    CubeMem(CubeAxis[a1,a2],m,m);
#end


function getSpatiaPointAxis(mask::CubeMem)
    a=Tuple{Float64,Float64}[]
    ax=axes(mask)
    ocval=OCEAN
    for (ilat,lat) in enumerate(ax[2].values)
        for (ilon,lon) in enumerate(ax[1].values)
            if (mask.mask[ilon,ilat] & ocval) != ocval
                push!(a,(lon,lat))
            end
        end
    end
    SpatialPointAxis(a)
end

function toPointAxis(xout,maskout,xin,maskin,lonax,lonmask,latax,latmask,pointax,pointmask)
    lom=LonAxis(lonax)
    lam=LatAxis(latax)
    iout=1
    for (lon,lat) in pointax
        ilon=axVal2Index(lom,lon)
        ilat=axVal2Index(lam,lat)
        xout[iout]=xin[ilon,ilat]
        maskout[iout]=maskin[ilon,ilat]
        iout+=1
    end
end
export toPointAxis
registerDATFunction(toPointAxis,((LonAxis,LatAxis),(LonAxis,),(LatAxis,),(SpatialPointAxis,)),(SpatialPointAxis,))

function sampleLandPoints(cdata::CubeAPI.AbstractCubeData,nsample::Integer)
  axlist=axes(cdata)
  ilon=findAxis(LonAxis,axlist)
  ilat=findAxis(LatAxis,axlist)
  bs=ntuple(i->in(i,(ilon,ilat)) ? length(axlist[i]) : 1,length(axlist))
  sargs=ntuple(i->ifelse(in(i,(ilon,ilat)),1:length(axlist[i]),1),length(axlist))
  mh=getMemHandle(cdata,1,CartesianIndex(bs))
  a,m=getSubRange(mh,sargs...)
  m=copy(m)
  cm=CubeMem(CubeAxis[axlist[ilon],axlist[ilat]],m,m)
  sax=getSpatiaPointAxis(cm);
  w=WeightVec(map(i->cosd(i[2]),sax.values))
  sax2=SpatialPointAxis(sample(sax.values,w,nsample,replace=false))
  y=mapCube(toPointAxis,(cdata,axlist[1],axlist[2],sax2),max_cache=1e8);
end
export sampleLandPoints
end
