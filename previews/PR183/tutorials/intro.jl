# # Introduction into the EarthDataLab package
#
# In this tutorial we will explore the features of the YAXArrays package. 

using YAXArrays, EarthDataLab, Zarr, NetCDF

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

europe = subsetcube(c, region="Europe", time=2000:2016, 
	Variable=["air_temperature_2m", "net_ecosystem", "soil_moisture"])

    plot(europe.time.values,europe[Variable="air_temperature_2m", lat=50, lon=11].data)

