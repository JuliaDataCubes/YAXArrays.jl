abstract type DatasetBackend end
#Functions to be implemented for Dataset sources:

"Test if a given variable name belongs to a dataset"
Base.haskey(t::DatasetBackend, key) = error("haskey not implemented for $(typeof(t))")

"Return a DiskArray handle to a dataset"
get_var_handle(ds, name) = ds[name]

"Return a list of variable names"
function get_varnames(ds) end

"Return a list of dimension names for a given variable"
function get_var_dims(ds, name) end

"Return a dict with the attributes for a given variable"
function get_var_attrs(ds,name) end

"Initialize and return a handle to a new empty dataset"
create_empty(T::Type{<:DatasetBackend},path) =
  error("create_empty not implemented for $T")
#Functions to be implemented for Dataset sinks

"""
    add_var(ds, T, name, s, dimlist, atts)

Add a new variable to the dataset with element type `T`,
name `name`, size `s` and depending on the dimensions `dimlist`
given by a list of Strings. `atts` is a list of attributes. 
"""
function add_var(ds, T, name, s, dimlist, atts;kwargs...) end
