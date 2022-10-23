# In this example we are going to use a `NetCDF` file but this should be very similar for other data backends. 
# To open a single data file we first need to load the appropriate backend package via `using NetCDF`. 

using YAXArrays, NetCDF
using Downloads
url = "https://www.unidata.ucar.edu/software/netcdf/examples/tos_O1_2001-2002.nc"
filename = Downloads.download(url, "tos_O1_2001-2002.nc") # you pick your own path
c = Cube(filename)