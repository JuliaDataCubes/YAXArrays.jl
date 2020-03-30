using NetCDF
using DiskArrayTools: SenMissDiskArray

struct NetCDFDataset <: DatasetBackend
  filename::String
end

get_var_dims(ds::NetCDFDataset,name) = NetCDF.open(v->map(i->i.name,v[name].dim),ds.filename)
get_varnames(ds::NetCDFDataset) = NetCDF.open(v->collect(keys(v.vars)),ds.filename)
get_var_attrs(ds::NetCDFDataset, name) = NetCDF.open(v->v[name].atts,ds.filename)
Base.getindex(ds::NetCDFDataset, i) = NetCDF.open(ds.filename,i)
Base.haskey(ds::NetCDFDataset,k) = NetCDF.open(nc->haskey(nc.vars,k),ds.filename)

function add_var(p::NetCDFDataset, T::Type{>:Missing}, varname, s, dimnames, attr; kwargs...)
  S = Base.nonmissingtype(T)
  if !haskey(attr,"missing_value")
    attr = copy(attr)
    attr["missing_value"]=defaultfillval(S)
  end
  za = add_var(p, S, varname, s, dimnames, attr; kwargs...)
  SenMissDiskArray(za,convert(Base.nonmissingtype(T),attr["missing_value"]))
end

function add_var(p::NetCDFDataset, T, varname, s, dimnames, attr;
  chunksize=s, compress = -1)
  dimsdescr = Iterators.flatten(zip(dimnames,s))
  nccreate(p.filename, varname, dimsdescr..., atts = attr, t=T, chunksize=chunksize, compress=compress)
  NetCDF.open(p.filename,varname)
end

function create_empty(::Type{NetCDFDataset}, path)
  NetCDF.create(path, NcVar[])
  NetCDFDataset(path)
end

#
#
#
# Cube(z::ZGroup;joinname="Variable") = Cube(Dataset(ZarrDataset(z)),joinname=joinname)
