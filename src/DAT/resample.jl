to_dimtuple(x::Tuple) = x
to_dimtuple(::Nothing) = ()
to_dimtuple(x::DD.AbstractDimArray) = DD.dims(x)
to_dimtuple(x::DD.Dim) = (x,)

valval(d::DD.Dimension) = valval(DD.val(d))
valval(d::DD.Lookup) = valval(DD.val(d))
valval(x) = x

"""
    xresample(yax; to=nothing, method=Linear(), outspecs=nothing, outtype=Float32)

Interpolate the data in `yax` onto a new grid specified by `to`.

# Arguments
- `yax`: A `YAXArray` or any `AbstractDimArray`
- `to`: Tuple of new `Dimension` specifications. Only common dimensions are resampled; 
  dimensions not in `to` are carried along unchanged.

# Keywords
- `method`: Interpolation method (default: `Linear()`)
- `outspecs`: Output specification forwarded to `DiskArrayEngine.interpolate_diskarray`
- `outtype`: Element type of the output (default: `Float32`)
"""
function xresample(yax::DD.AbstractDimArray; to=nothing, 
                   method=Linear(), outspecs=nothing, outtype=Float32)
    newdims = to_dimtuple(to)
    yaxdims = DD.dims(yax)
    conv = map(newdims) do d
        dold = DD.dims(yaxdims, d)
        dold === nothing && return nothing
        approxequal(dold, d) && return nothing
        idim = DD.dimnum(yaxdims, d)
        idim => (valval(dold), valval(d))
    end
    conv = filter(!isnothing, conv)
    interpdata = isempty(conv) ? yax.data : DAE.interpolate_diskarray(parent(yax), conv; method, outspecs, outtype)
    allnewdims = DD.setdims(DD.dims(yax), newdims)
    DD.rebuild(yax, interpdata, allnewdims)
end