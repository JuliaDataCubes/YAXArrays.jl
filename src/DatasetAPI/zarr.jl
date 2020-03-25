struct ZarrDataset <: DatasetBackend
  g::ZGroup
end

get_var_dims(ds::ZarrDataset,name) = reverse(ds[name].attrs["_ARRAY_DIMENSIONS"])
get_varnames(ds::ZarrDataset) = collect(keys(ds.g.arrays))
get_var_attrs(ds::ZarrDataset, name) = ds[name].attrs
Base.getindex(ds::ZarrDataset, i) = ds.g[i]
Base.haskey(ds::ZarrDataset,k) = haskey(ds.g,k)

function add_var(p::ZarrDataset, T, varname, s, dimnames, attr)
  attr["_ARRAY_DIMENSIONS"]=reverse(collect(dimnames))
  za = zcreate(T, p.g, varname, s...,attrs=attr)
end

create_empty(::Type{ZarrDataset}, path) = zgroup(path) 


Cube(z::ZGroup;joinname="Variable") = Cube(Dataset(ZarrDataset(z)),joinname=joinname)
