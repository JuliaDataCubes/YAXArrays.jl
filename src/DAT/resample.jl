to_dimtuple(x::Tuple) = x
to_dimtuple(x::DD.AbstractDimArray) = DD.dims(x)
to_dimtuple(x::DD.Dim) = (x,)

valval(d::DD.Dimension) = valval(DD.val(d))
valval(d::DD.Lookup) = valval(DD.val(d))
valval(x) = x

function xresample(yax::YAXArray;to=nothing,method=Linear(),outtype=Float32)
    newdims = to_dimtuple(to)
    conv = map(newdims) do d
        dold = DD.dims(yax.axes,d)
        dold === nothing && return nothing
        approxequal(dold,d) && return nothing
        idim = DD.dimnum(yax.axes,d)
        idim=>(valval(dold),valval(d))
    end
    conv = filter(!isnothing,conv)
    itp = DAE.interpolate_diskarray(yax.data,conv,method=method,outtype=outtype)
    allnewdims = DD.setdims(yax.axes,newdims)
    YAXArray(allnewdims, itp, yax.properties, cleaner=yax.cleaner)
end
