# Opening a Zarr directory from a store

````@example open_zarr
using Zarr, YAXArrays
store ="gs://cmip6/CMIP6/ScenarioMIP/DKRZ/MPI-ESM1-2-HR/ssp585/r1i1p1f1/3hr/tas/gn/v20190710/"
````

Open and select the `tas` variable,

````@ansi open_zarr
g = open_dataset(zopen(store, consolidated=true))
````

get variable

````@ansi open_zarr
c = g["tas"]
````

After this operate on it as usual.

