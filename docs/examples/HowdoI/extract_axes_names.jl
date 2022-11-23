# !!! question
#     How do I extract the axes names from a Cube?

using YAXArrays
c = YAXArray(rand(10,10,5))
caxes(c)