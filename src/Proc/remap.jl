module ReSample
using ..Cubes
using ..DAT
export spatialinterp
import Interpolations: BSpline, scale,extrapolate, interpolate, Constant, Linear, Quadratic,
  Cubic, OnGrid, Flat, Line,Free, Periodic, Reflect
function fremap(xout,xin,oldlons,oldlats,newlons,newlats;order=Linear(),bc = Flat())
  #interp = LinearInterpolation((oldlons,oldlats),xin);
  interp = extrapolate(scale(interpolate(xin, BSpline(order)), oldlons,oldlats), bc)
  for (ilat,lat) in enumerate(newlats)
    for (ilon,lon) in enumerate(newlons)
      xout[ilon,ilat]=interp(lon,lat)
    end
  end
end

"""
  spatialinterp(c::AbstractCubeData,newlons::AbstractRange,newlats::AbstractRange;order=Linear(),bc = Flat())
"""
function spatialinterp(c::AbstractCubeData,newlons::AbstractRange,newlats::AbstractRange;order=Linear(),bc = Flat())
  oldlons = getAxis("Lon",c).values
  oldlats = getAxis("Lat",c).values
  indims=InDims("Lon","Lat")
  outdims=OutDims(LonAxis(newlons),LatAxis(newlats))
  if step(oldlats)<0
    oldlats = reverse(oldlats)
    newlats = reverse(newlats)
  end

  mapCube(fremap,c,oldlons,oldlats,newlons,newlats,indims=indims,outdims=outdims,order=order,bc=bc)
end
spatialinterp(c::AbstractCubeData,newlons::CubeAxis,newlats::CubeAxis;kwargs...)=
  spatialinterp(c,newlons.values,newlats.values)
spatialinterp(c::AbstractCubeData,target_cube::AbstractCubeData)=
  spatialinterp(c,getAxis("Lon",))
end #module
