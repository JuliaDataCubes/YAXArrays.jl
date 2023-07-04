# The purpose of this section is to show how to switch from the native YAXArray type to the new type based on DimensionalData.jl

# ## Axis lists have to be Tuples instead of Vector

# When you want to define a YAXArray from scratch the list of Axis has to be given as a Tuple instead of a vector.
# Otherwise you would run into a DimensionMismatch error.


# ## Dim instead of RangeAxis and CategoricalAxis
# The dimensions of a YAXArray are now `Dimension` types from DimensionalData 
# and there is no difference anymore in the construction for categorical or 

# ## Find the axis in a cube
# This was previously done via the `findAxis` function and is now done via lookup

lookup(arr, :x)


# ## Get the axes of a YAXArray
# To get the axes of a YAXArray use the `dims` function instead of the `caxes` function

dims(arr)

# ## Copy an axes with the same name but different values
# Use DD.rebuild(ax, values) instead of axcopy(ax, values)


# ## Subsetting is including not excluding
# Beware that the subsets in DimensionalData include the bounds.
# Thereby the size of the subset can differ by one on every bound.
# a[X=1..4]
