#import GDAL

# # GDALRasterize
# function rasterize!(outar,shapefile;x0=-180.0,y0=-90.0,x1=180.0,y1=90.0)
#     sx,sy = size(outar)
#     ds_point = GDAL.openex(shapefile, GDAL.GDAL_OF_VECTOR, C_NULL, C_NULL, C_NULL)
#     ds_point == C_NULL && error("Could not open shapefile")
#     options = GDAL.rasterizeoptionsnew(["-of","MEM","-ts",string(sx),string(sy),"-te",string(x0),string(y0),string(x1),string(y1),"-a_srs","WGS84"], C_NULL)
#     ds_rasterize = GDAL.rasterize("data/point-rasterize.mem", Ptr{GDAL.GDALDatasetH}(C_NULL), ds_point, options, C_NULL)
#     GDAL.rasterizeoptionsfree(options)
#     GDAL.close(ds_point)
#
#     band = GDAL.getrasterband(ds_rasterize,1)
#
#     xsize = GDAL.getrasterbandxsize(band)
#     ysize = GDAL.getrasterbandysize(band)
#     dtype = GDAL.getdatatypename(GDAL.getrasterdatatype(band))
#     @assert (xsize,ysize)==(sx,sy)
#     GDAL.rasterio(band, GDAL.GF_Read, 0, 0, xsize, ysize,
#     outar, xsize, ysize, GDAL.GDT_Float64, 0, 0)
#     GDAL.close(ds_rasterize)
# end

import Shapefile
import GeoInterface: AbstractMultiPolygon, AbstractPoint
export cubefromshape
import ..Cubes.Axes: get_bb, axisfrombb
import DBFTables
import WeightedOnlineStats: WeightedMean
import Dates: Day

function getlabeldict(shapepath,labelsym,T,labelsleft)
  dbfname = string(splitext(shapepath)[1],".dbf")
  dbf = open(dbfname) do f
    DBFTables.read_dbf(f)
  end
  labels = dbf[labelsym]
  labeldict = Dict(T(i)=>stripc0x(labels[i]) for i in 1:length(labels) if T(i) in labelsleft)
  properties = Dict("labels"=>labeldict)
end
getlabeldict(shapepath, ::Nothing,T, labelsleft)=Dict{String,Any}()

function aggregate_out(allout, highmat, labelsleft,n)
  dsort = Dict(i[2]=>i[1] for i in enumerate(labelsleft))
  for jout in 1:size(allout,2)
    for iout in 1:size(allout,1)
      v = view(highmat,(iout*n-9):iout*n,(jout*n-9):jout*n,:)
      for value in skipmissing(v)
        allout[iout,jout,dsort[value]]+=1
      end
    end
  end
  map!(i->i/(n*n),allout,allout)
end

function cubefromshape_fraction(shapepath,lonaxis,lataxis;labelsym=nothing, T=Float64, nincrease=10)
  s = (length(lonaxis), length(lataxis))
  outmat = zeros(T,map(i->i*nincrease,s)...)
  lon1,lon2 = get_bb(lonaxis)
  lat1,lat2 = get_bb(lataxis)
  rasterize!(outmat, shapepath, bb = (left = lon1, right=lon2, top=lat1, bottom=lat2))

  outmat = replace(outmat,zero(T)=>missing)
  labelsleft = collect(skipmissing(unique(outmat)))
  pp = getlabeldict(shapepath,labelsym,T,Set(labelsleft))["labels"]

  allout = zeros(T,s...,length(labelsleft))
  aggregate_out(allout,outmat,labelsleft,nincrease)

  if labelsym===nothing
    newax = CategoricalAxis("Label", labelsleft)
  else
    newax = CategoricalAxis(labelsym,[pp[l] for l in labelsleft])
  end

  return CubeMem(CubeAxis[lonaxis, lataxis, newax], allout)


end
function cubefromshape_single(shapepath, lonaxis, lataxis; labelsym = nothing, T=Int32)
  s = (length(lonaxis), length(lataxis))
  outmat = zeros(T,s...)
  lon1,lon2 = get_bb(lonaxis)
  lat1,lat2 = get_bb(lataxis)
  rasterize!(outmat, shapepath, bb = (left = lon1, right=lon2, top=lat1, bottom=lat2))

  outmat = replace(outmat,zero(T)=>missing)
  labelsleft = collect(skipmissing(unique(outmat)))
  properties = getlabeldict(shapepath,labelsym,T,labelsleft)

  return CubeMem(CubeAxis[lonaxis, lataxis], outmat,properties)
end
cubefromshape(shapepath, c::AbstractCubeData; kwargs...) = cubefromshape(shapepath, getAxis("Lon",c), getAxis("Lat",c);kwargs...)
function cubefromshape(args...; samplefactor=nothing, kwargs...)
  if samplefactor===nothing
    cubefromshape_single(args...; kwargs...)
  else
    cubefromshape_fraction(args...; nincrease = samplefactor, kwargs...)
  end
end

function prune_labels!(c::CubeMem)
  if haskey(c.properties,"labels")
    labelsleft = Set(skipmissing(unique(c.data)))
    dold = c.properties["labels"]
    dnew = Dict(k=>dold[k] for k in filter(i->in(i,labelsleft),keys(dold)))
    c.properties["labels"] = dnew
  end
  c
end
stripc0x(a) = replace(a, r"[^\x20-\x7e]"=> "")

function rasterize!(outar,shapefile;bb = (left = -180.0, right=180.0, top=90.0,bottom=-90.0),label=nothing)
  shapepath = shapefile
  handle = open(shapepath, "r") do io
    read(io, Shapefile.Handle)
  end
  p = handle.shapes
  if length(p)>1
    rasterizepoly!(outar,p,bb)
  else
    rasterizepoly!(outar,p[1],bb)
  end
end

function rasterizepoly!(outmat,poly::Vector{<:AbstractMultiPolygon},bb)
    foreach(1:length(poly)) do ipoly
        rasterizepoly!(outmat,poly[ipoly],bb,value=ipoly)
    end
    outmat
end

function rasterizepoly!(outmat,poly::Vector{T},bb;value=one(eltype(outmat)), wrap = (left = -180.0,right = 180.0)) where T<:AbstractPoint
nx,ny = size(outmat)
resx = (bb.right-bb.left)/nx
resy = (bb.top-bb.bottom)/ny
xr = range(bb.left+resx/2,bb.right-resx/2,length=nx)
yr = range(bb.top-resy/2,bb.bottom+resy/2,length=ny)
wrapwidth = wrap.right-wrap.left

for (iy,pixelY) in enumerate(yr)
    nodeX = Float64[]
    j = length(poly)
    for i = 1:length(poly)
        p1 = poly[i]
        p2 = poly[j]
        if wrap !==nothing && abs(p1.x-p2.x)>wrapwidth
            p1,p2 = p1.x < p2.x ? (T(p1.x+wrapwidth,p1.y),T(p2.x,p2.y)) : (T(p1.x,p1.y),T(p2.x+wrapwidth,p2.y))
        end
        if (p1.y < pixelY) && (p2.y >= pixelY) || (p2.y < pixelY) && (p1.y >= pixelY)
            push!(nodeX, p1.x + (pixelY-p1.y)/(p2.y-p1.y)*(p2.x-p1.x))
        end
        j = i
    end
    #Add intersect points at start and end for wrapped polygons
    if wrap!==nothing && any(i->i>wrap.right,nodeX)
        push!(nodeX,wrap.left)
        push!(nodeX,wrap.right)
        map!(i->i>wrap.right ? i-wrapwidth : i,nodeX,nodeX)
    end
    sort!(nodeX)
    @assert(iseven(length(nodeX)))
    for i = 1:2:length(nodeX)
        outmat[searchsortedfirst(xr,nodeX[i]):searchsortedlast(xr,nodeX[i+1]),iy].=value
    end
end
    outmat
end

function rasterizepoly!(outmat,pp::Shapefile.Polygon,bb;value=one(eltype(outmat)))
    points = map(1:length(pp.parts)) do ipart
        i0 = pp.parts[ipart]+1
        iend = ipart == length(pp.parts) ? length(pp.points) : pp.parts[ipart+1]
        pp.points[i0:iend]
    end
    foreach(1:length(points)) do ipoly
        rasterizepoly!(outmat,points[ipoly],bb,value=value)
    end
    outmat
end

function getboundingbox(data)
  defaultval = (CartesianIndex(size(data)),CartesianIndex{ndims(data)}())
  r1, r2 = mapreduce(
    i->ismissing(data[i]) ? defaultval : (i,i),
    (x,y)->(min(x[1],y[1]),max(x[2],y[2])),
    CartesianIndices(data),
    init = defaultval
  )
  CartesianIndices(map(Colon(),r1.I,r2.I))
end


"""
    aggregate_shapefile(shp,cube,refdate)

Calculates spatially aggregated statistics
"""
function aggstats(shp,csubvar,refdate;npast=3,nfuture=10)

  craster = cubefromshape(shp, csubvar)
  bspace = getboundingbox(craster.data)
  blon,blat = map(i->CartesianIndices((i,)),bspace.indices)
  taxall = getAxis("Time",csubvar)
  itime = axVal2Index(taxall,refdate)
  refdate = taxall.values[itime]
  btime = LinearIndices((itime-npast:itime+nfuture,))
  csmallbox = csubvar[lon=blon,lat=blat,time=btime]
  maskcube = craster[lon=blon,lat=blat]
  if findAxis("Variable",csubvar)===nothing
    by = ()
    incax = ("lat","time")
  else
    by = (:var,)
    incax = ("lat","var","time")
  end
  ct = CubeTable(cdata = csmallbox, cmask = maskcube, include_axes=incax)

  by = (i->iszero(i.cmask),by...,i->Int((i.time-refdate)/Day(1)))
  fitres = cubefittable(ct,WeightedMean,:cdata,by=by,weight=i->cosd(i.lat),showprog=false)

  fr = fitres[Category1=false]
  renameaxis!(fr,"Category"=>RangeAxis("Time",(-npast:nfuture)*8))
  fr
end
