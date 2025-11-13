struct XStyle <: Broadcast.BroadcastStyle end
Base.BroadcastStyle(::Broadcast.AbstractArrayStyle, ::XStyle) = XStyle()
Base.BroadcastStyle(::XStyle, ::Broadcast.AbstractArrayStyle) = XStyle()
Base.BroadcastStyle(::Type{<:YAXArray}) = XStyle()
Base.BroadcastStyle(::Type{<:DimWindowArray}) = XStyle() 
to_yax(x::Number) = YAXArray((),fill(x))
to_yax(x::DD.AbstractDimArray) = x
to_yax(x::DimWindowArray) = x

Base.broadcastable(d::DimWindowArray) = d
Base.broadcastable(d::YAXArray) = d

function Base.broadcasted(::XStyle, f, args...)
    return Broadcast.Broadcasted{XStyle}(f, args)
end
function Base.materialize(bc::Broadcast.Broadcasted{XStyle})
    args2 = map(arg -> arg isa Broadcast.Broadcasted ? Base.materialize(arg) : arg, bc.args)
    args2 = map(to_yax, args2)
    # determine output type by calling `eltype` on a dummy function call
    intypes = (eltype.(args2)...,)
    @debug intypes
    outtypes = Base.return_types(bc.f, intypes)
    outtype = Base.promote_type(outtypes...)
    @debug outtype
    return xmap(XFunction(bc.f; inplace=false), args2..., output=XOutput(; outtype))
end