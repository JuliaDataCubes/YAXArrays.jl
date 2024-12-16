using DimensionalData: @dim, YDim, XDim, ZDim, TimeDim
export Lat, lat, latitude, Latitude
export Lon, lon, longitude, Longitude
export Variables

@dim Lat YDim "Latitude"
@dim lat YDim "Latitude"
@dim latitude YDim "Latitude"
@dim Latitude YDim "Latitude"
@dim rlat YDim
@dim lat_c YDim

@dim Lon XDim "Longitude"
@dim lon XDim "Longitude"
@dim longitude XDim "Longitude"
@dim Longitude XDim "Longitude"
@dim rlon XDim
@dim lon_c XDim

@dim height ZDim
@dim depth ZDim

@dim time TimeDim "time"
@dim Time TimeDim "time"

@dim Variables