# Read YAXArrays and Datasets

This section describes how to read files, URLs, and directories into YAXArrays and datasets.

## Read Zarr

Open a Zarr store as a `Dataset`:

````@example read_zarr
using YAXArrays
using Zarr
path="gs://cmip6/CMIP6/ScenarioMIP/DKRZ/MPI-ESM1-2-HR/ssp585/r1i1p1f1/3hr/tas/gn/v20190710/"
store = zopen(path, consolidated=true)
ds = open_dataset(store)
````

We can set `path` to a URL, a local directory, or in this case to a cloud object storage path.

A zarr store may contain multiple arrays.
Individual arrays can be accessed using subsetting:

````@example read_zarr
ds.tas
````

## Read NetCDF

Open a NetCDF file as a `Dataset`:

````@example read_netcdf
using YAXArrays
using NetCDF
using Downloads: download

path = download("https://www.unidata.ucar.edu/software/netcdf/examples/tos_O1_2001-2002.nc", "example.nc")
ds = open_dataset(path)
````

A NetCDF file may contain multiple arrays.
Individual arrays can be accessed using subsetting:

````@example read_netcdf
ds.tos
````

Please note that netCDF4 uses HDF5 which is not thread-safe in Julia.
Add manual [locks](https://docs.julialang.org/en/v1/manual/multi-threading/#man-using-locks) in your own code to avoid any data-race:

````@example read_netcdf
my_lock = ReentrantLock()
Threads.@threads for i in 1:10
    @lock my_lock @info ds.tos[1, 1, 1]
end
````

This code will ensure that the data is only accessed by one thread at a time, i.e. making it actual single-threaded but thread-safe.

## Read GDAL (GeoTIFF, GeoJSON)

All GDAL compatible files can be read as a `YAXArrays.Dataset` after loading [ArchGDAL](https://yeesian.com/ArchGDAL.jl/latest/):

````@example read_gdal
using YAXArrays
using ArchGDAL
using Downloads: download

path = download("https://github.com/yeesian/ArchGDALDatasets/raw/307f8f0e584a39a050c042849004e6a2bd674f99/gdalworkshop/world.tif", "world.tif")
ds = open_dataset(path)
````