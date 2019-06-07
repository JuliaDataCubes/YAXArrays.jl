import GDAL

# GDALRasterize
function rasterize!(outar,shapefile;x0=-180.0,y0=-90.0,x1=180.0,y1=90.0)
    sx,sy = size(outar)
    ds_point = GDAL.openex(shapefile, GDAL.GDAL_OF_VECTOR, C_NULL, C_NULL, C_NULL)
    ds_point == C_NULL && error("Could not open shapefile")
    options = GDAL.rasterizeoptionsnew(["-of","MEM","-ts",string(sx),string(sy),"-te",string(x0),string(y0),string(x1),string(y1),"-a_srs","WGS84"], C_NULL)
    ds_rasterize = GDAL.rasterize("data/point-rasterize.mem", Ptr{GDAL.GDALDatasetH}(C_NULL), ds_point, options, C_NULL)
    GDAL.rasterizeoptionsfree(options)
    GDAL.close(ds_point)

    band = GDAL.getrasterband(ds_rasterize,1)

    xsize = GDAL.getrasterbandxsize(band)
    ysize = GDAL.getrasterbandysize(band)
    dtype = GDAL.getdatatypename(GDAL.getrasterdatatype(band))
    @assert (xsize,ysize)==(sx,sy)
    GDAL.rasterio(band, GDAL.GF_Read, 0, 0, xsize, ysize,
    outar, xsize, ysize, GDAL.GDT_Float64, 0, 0)
    GDAL.close(ds_rasterize)
end

function getboundingbox(data)
  defaultval = (CartesianIndex(size(data)),CartesianIndex{ndims(data)}())
  r1, r2 = mapreduce(
    i->data[i]==-3.4f38 ? defaultval : (i,i),
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
function aggstats(shp,csubvar,refdate;npast=10,nfuture=3)
  lonax,latax = getAxis("lon",csubvar), getAxis("lat",csubvar)
  data  = zeros(length(lonax.values),length(latax.values))
  rasterize!(shp,data)
  bspace = getboundingbox(data)
  blon,blat = map(i->CartesianIndices((i,)),bspace.indices)
  taxall = getAxis("Time",csubvar)
  itime = axVal2Index(taxall,refdate)
  refdate = taxall.values[itime]
  btime = LinearIndices((itime-npast:itime+nfuture,))
  csmallbox = csubvar[lon=blon,lat=blat,time=btime]
  maskcube = CubeMem(CubeAxis[getAxis("Lon",csmallbox),getAxis("Lat",csmallbox)],replace(data[bspace],0.0=>missing))
  ct = CubeTable(cdata = csmallbox, cmask = maskcube, include_axes=("lat","var","time"))
  fitres = cubefittable(ct,WeightedMean,:cdata,by=(:var,i->ismissing(i.cmask),i->Int((i.time-refdate)/Day(1))),weight=i->cosd(i.lat),showprog=false)

  fr = fitres[Category2=false]
  renameaxis!(fr,"Category"=>RangeAxis("Time",(-npast:nfuture)*8))
  fr
end
