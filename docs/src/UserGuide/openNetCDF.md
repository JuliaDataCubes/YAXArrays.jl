# Opening NetCDF files

In this example we are going to use a `NetCDF` file. To open a single data file we first need to load the appropriate backend package via `using NetCDF`. 

## File with one variable 

````@example open_nc
using YAXArrays, NetCDF
using DiskArrays
using Downloads
url = "https://www.unidata.ucar.edu/software/netcdf/examples/tos_O1_2001-2002.nc"
filename = Downloads.download(url, "tos_O1_2001-2002.nc") # you pick your own path
nothing # hide
````

````@ansi open_nc
c = Cube(filename)
````

## File with multiple variables, mixed dimensions

When the dataset contains variables with different dimensions you should use `open_dataset` as in 

````@example open_nc
path2file = "https://www.unidata.ucar.edu/software/netcdf/examples/sresa1b_ncar_ccsm3-example.nc"
filename = Downloads.download(path2file, "sresa1b_ncar_ccsm3-example.nc")
c = open_dataset(filename)
nothing # hide
````

````@ansi open_nc
c
````

Afterwards, selecting a variable as usual works, i.e.

````@ansi open_nc
c["ua"]
````

or 

````@ansi open_nc
c["tas"]
````

Note that their output is a YAXArray.