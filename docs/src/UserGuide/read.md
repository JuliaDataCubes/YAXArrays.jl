# Read YAXArrays and Datasets

Here we learn how to open files as arrays and datasets.


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