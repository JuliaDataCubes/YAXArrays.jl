# In this example we are going to use a `NetCDF` file but this should be very similar for other data backends. 
# To open a single data file we first need to load the appropriate backend package via `using NetCDF`. 

# ## One variable 
using YAXArrays, NetCDF
using Downloads
url = "https://www.unidata.ucar.edu/software/netcdf/examples/tos_O1_2001-2002.nc"
filename = Downloads.download(url, "tos_O1_2001-2002.nc") # you pick your own path
c = Cube(filename)

# ## Multiple variables, mixed dimensions

# When the dataset contains variables with different dimensions you should use `open_dataset` as in 

path2file = "https://www.unidata.ucar.edu/software/netcdf/examples/sresa1b_ncar_ccsm3-example.nc"
filename = Downloads.download(path2file, "sresa1b_ncar_ccsm3-example.nc")
c = open_dataset(filename)

# Afterwards, selecting a variable as usual works, i.e.
c["ua"]

# or 

c["tas"]

#  Note that their output is a YAXArray.
