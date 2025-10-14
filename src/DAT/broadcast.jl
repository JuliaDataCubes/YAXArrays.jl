struct XStyle <: Broadcast.BroadcastStyle end
Base.BroadcastStyle(::Broadcast.AbstractArrayStyle, ::XStyle) = XStyle()
Base.BroadcastStyle(::XStyle, ::Broadcast.AbstractArrayStyle) = XStyle()
Base.BroadcastStyle(::Type{<:YAXArray}) = XStyle()
to_yax(x::Number) = YAXArray((), fill(x))
to_yax(x::DD.AbstractDimArray) = x
function Base.broadcasted(::XStyle, f, args...)
    return Broadcast.Broadcasted{XStyle}(f, args)
end
function Base.materialize(bc::Broadcast.Broadcasted{XStyle})
    args2 = map(arg -> arg isa Broadcast.Broadcasted ? Base.materialize(arg) : arg, bc.args)
    args2 = map(to_yax, args2)
    # determine output type by calling `eltype` on a dummy function call
    dummy_args = map(a -> first(a.data), args2)
    outtype = typeof(bc.f(dummy_args...))
    return xmap(XFunction(bc.f; inplace=false), args2..., output=XOutput(; outtype))
end
function Base.materialize!(bc::Broadcast.Broadcasted{XStyle})
    args2 = map(arg -> arg isa Broadcast.Broadcasted ? Base.materialize(arg) : arg, bc.args)
    args2 = map(to_yax, args2)
    dummy_args = map(a -> first(a.data), args2)
    outtype = typeof(bc.f(dummy_args...))
    return xmap(XFunction(bc.f; inplace=true), args2..., output=XOutput(; outtype))
end