# Convert YAXArrays

This section describes how to convert variables from types of other Julia packages into YAXArrays and vice versa.


::: warning

YAXArrays is designed to work with large datasets that are way larger than the memory.
However, most types are designed to work in memory.
Those conversions are only possible if the entire dataset fits into memory.
In addition, metadata might be lost during conversion.

:::


## Convert `Base.Array`

Convert `Base.Array` to `YAXArray`:

````@example convert
using YAXArrays

m = rand(5,10)
a = YAXArray(m)
````

Convert `YAXArray` to `Base.Array`:

````@example convert
m2 = collect(a.data)
````