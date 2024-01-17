# # Introduction into the EarthDataLab package
#
# In this tutorial we will explore the features of the YAXArrays package. 

using YAXArrays, EarthDataLab, Zarr, NetCDF
using DimensionalData: Where

# ## Use data larger than RAM#
#
# - Uses DiskArrays.jl in the background
# - Load only the data that is really needed
# - Use chunks of the data
# - Use NetCDF or Zarr or GDAL to load data
# - Load data locally or from the cloud


# Here we use the EarthSystemDataCube a multivariate global dataset with climate and biosphere variables.

c = esdc(res="low")

# ## Subsets happen lazily


europe = c[region="Europe", time=2000:2016, 
	Variable=Where( x-> any(contains.((x,),["air_temperature_2m", "net_ecosystem", "moisture"])))]


plot(lookup(europe, Ti).data,europe[Variable=At("air_temperature_2m"), lat=50, lon=11].data)

