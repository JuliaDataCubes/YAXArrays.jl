# # Indexing and subsetting via Selectors
using YAXArrays, Dates

## Define a toy cube
t = Date("2020-01-01"):Month(1):Date("2022-12-31")
axes = (Dim{:lon}(-9:10), Dim{:lat}(-5:15), Dim{:time}(t))
c = YAXArray(axes, reshape(1:20*21*36, (20, 21, 36)))

# ## `At` value

c[time = At(Date("2021-05-01"))]

# ## `At` vector of values

c[time = At([Date("2021-05-01"), Date("2021-06-01")])]

# similarly for any of the spatial dimensions:

c[lon = At([-9,-5])]

# ## `At` values with tolerance (`atol`, `rtol`)

c[lon = At([-10, 11]; atol = 1)]

# ## Between
# Altought a `Between(a,b)` function is available in DimensionalData, is recommended to use instead the `a .. b` notation:

c[lon = -9 .. -7] # close interval, all points included.

# ### Open/Close Intervals

using IntervalSets

c[lon = OpenInterval(-9, -7)]
#
c[lon = ClosedInterval(-9, -7)]
#
c[lon =Interval{:open,:closed}(-9,-7)]
#
c[lon =Interval{:closed,:open}(-9,-7)]

# ## Touches
# Docs.doc(Touches) # hide

# ## Near
# Docs.doc(Near) # hide

# ## Where
# Docs.doc(Where) # hide

# ## Contains
# Docs.doc(Contains) # hide

# Another important function is

# ## lookup
# Docs.doc(lookup) # hide

