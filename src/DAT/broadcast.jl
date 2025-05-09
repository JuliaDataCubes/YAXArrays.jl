struct XStyle <: Broadcast.BroadcastStyle end
Base.BroadcastStyle(::Broadcast.AbstractArrayStyle, ::XStyle) = XStyle()
Base.BroadcastStyle(::XStyle, ::Broadcast.AbstractArrayStyle) = XStyle()
Base.BroadcastStyle(::Type{<:YAXArray}) = XStyle()
to_yax(x::Number) = YAXArray((),fill(x))
to_yax(x::DD.AbstractDimArray) = x

function Base.broadcasted(::XStyle, f, args...)
    args2 = map(to_yax,args)
    xmap(XFunction(f,inplace=false),args2...)
end