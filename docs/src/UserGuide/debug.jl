using Zarr
using YAXArrays

da = open_dataset("http://data.rsc4earth.de/EarthSystemDataCube/v3.0.2/esdc-8d-0.25deg-1x720x1440-3.0.2.zarr")
da.kndvi.properties["long_name"]

da = Cube("http://data.rsc4earth.de/EarthSystemDataCube/v3.0.2/esdc-8d-0.25deg-1x720x1440-3.0.2.zarr")
da[Variable = At("kndvi")].properties["long_name"]