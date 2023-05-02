# The purpose of this section is to show how to switch from the native YAXArray type to the new type based on DimensionalData.jl

# ## Find the axis in a cube
# This was previously done via the `findAxis` function and is now done via lookup

lookup(arr, :x)


# ## Get the axes of a YAXArray
# To get the axes of a YAXArray use the `axes` instead of the `caxes` function

axes(arr)

# ## 