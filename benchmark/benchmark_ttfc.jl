# This script is to benchmark the Time to first Cube
# Currently this is not automatically tested. 

@time begin
using YAXArrays
c = YAXArray(rand(10,10,2))
end