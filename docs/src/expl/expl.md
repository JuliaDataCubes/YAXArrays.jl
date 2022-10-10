## Indexing and subsetting

As for most array types, YAXArray also provides special indexing behavior when using the square brackets for indexing. 
Assuming that `c` is a YAXArray, there are 3 different semantics to use the square brackets with, depending on the types of the arguments
provided to getindex. 

1. **Ranges and Integers only** as for example `c[1,4:8,:]` will access the underlying data according to the provided index in index space and read the data *into memory* as a plain Julia Array. 
It is equivalent to `c.data[1,4:8,:]`. 
2. **Keyword arguments with values or Intervals** as for example `c[longitude = 30..50, time=Date(2005,6,1), variable="air_temperature"]`. 
This always creates a *view* into the specified subset of the data and return a new YAXArray with new axes without reading the data. Intervals and 
values are always interpreted in the units as provided by the axis values.
3. **A Tables.jl-compatible object** for irregular extraction of a list of points or sub-arrays and random locations. For example calling `c[[(lon=30,lat=42),(lon=-50,lat=2.5)]]` will extract data at the specified coordinates and along all additional axes into memory. It returns a new YAXArray with a new Multi-Index axis along the selected longitudes and latitudes.   
