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


"""
    interpolate(yax, targetgrid; method=Linear(), outspecs=nothing, outtype=Float32)
Interpolate the data in `yax` onto the grid of `target`.
The interpolation is done lazily via DiskArrayEngine. 
"""
function xinterpolate(yax, target::DD.AbstractDimArray;  method=Linear(), outspecs=nothing, outtype=Float32)
    targetdims = dims(target)
    xinterpolate(yax, targetdims; method, outspecs, outtype)
end
function xinterpolate(yax, targetdims;  method=Linear(), outspecs=nothing, outtype=Float32)
    shareddims = DD.commondims(yax, targetdims)
    convtuples = map(shareddims, targetdims) do s,t
        (DD.val(s),DD.val(t))
    end
    conv = DD.dimnum(yax, shareddims) .=> convtuples
    interpdata = DAE.interpolate_diskarray(yax, conv; method, outspecs, outtype)
    newdims = DD.Dimensions.setdims(dims(yax), targetdims)
    DD.rebuild(yax, interpdata, newdims)
end