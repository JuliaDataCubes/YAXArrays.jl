using DimensionalData: DimensionalData as DD
const VecOrTuple{S} = Union{Vector{<:S},Tuple{Vararg{S}}} where {S}

abstract type AxisDescriptor end

struct ByName <: AxisDescriptor
    name::String
end


struct ByInference <: AxisDescriptor end

struct ByValue <: AxisDescriptor
    v::DD.Dimension
end

"""
    get_descriptor(a)

Get the descriptor of an Axis. 
This is used to dispatch on the descriptor. 
"""
get_descriptor(a::String) = ByName(a)
get_descriptor(a::Symbol) = ByName(String(a))
get_descriptor(a::DD.Dimension) = ByValue(a)
get_descriptor(a) = error("$a is not a valid axis description")
get_descriptor(a::AxisDescriptor) = a


"""
    findAxis(desc, c)
Internal function
# Extended Help

    Given an Axis description and a cube return the index of the Axis.
The Axis description can be:
  - the name as a string or symbol.
  - an Axis object
"""
findAxis(desc, c) = findAxis(desc, caxes(c))
findAxis(a, axlist::VecOrTuple{DD.Dimension}) = findAxis(get_descriptor(a), axlist)
function findAxis(bs::AxisDescriptor, axlist::VecOrTuple{DD.Dimension})
    m = findall(i -> match_axis(bs, i), axlist)
    if isempty(m)
        return nothing
    elseif length(m) > 1
        error("Multiple possible axis matches found for $bs")
    else
        return m[1]
    end
end

"""
    match_axis
Internal function
# Extended Help
    Match the Axis based on the AxisDescriptor.
    This is used to find different axes and to make certain axis description the same.
    For example to disregard differences of captialisation.
"""
function match_axis(bs::ByName, ax)
    name_corrected = if lowercase(bs.name) == "time"
        "Ti"
    else
        bs.name
    end
    startswith(lowercase(string(DD.name(ax))), lowercase(name_corrected))
end
function match_axis(bs::ByValue, ax)
    isequal(bs.v, ax)
end
match_axis(a, ax) = match_axis(get_descriptor(a), ax)


"""
    getOutAxis
"""
getOutAxis(desc, axlist, incubes, pargs, f) = getAxis(desc, unique(axlist))

function getOutAxis(desc::Tuple{ByInference}, axlist, incubes, pargs, f)
    axlist = map(axlist) do ax
        isa(ax, String) ? Symbol(ax) : ax
    end
    inAxSmall = map(i -> DD.dims(i, axlist), incubes)
    inSizes = map(i -> (map(length, i)...,), inAxSmall)
    intypes = map(eltype, incubes)
    testars = map((s, it) -> zeros(it, s...), inSizes, intypes)
    # map(testars) do ta
    #     ta .= rand(Base.nonmissingtype(eltype(ta)), size(ta)...)
    #     if eltype(ta) >: Missing
    #         # Add some missings
    #         randind = rand(1:length(ta), length(ta) ÷ 10)
    #         ta[randind] .= missing
    #     end
    # end
    resu = f(testars..., pargs...)
    isa(resu, AbstractArray) ||
        isa(resu, Number) ||
        isa(resu, Missing) ||
        error("Function must return an array or a number")
    if (isa(resu, Number) || isa(resu, Missing)) 
        return map(reduce(union!,inAxSmall)) do ax
            DD.rebuild(ax,[DD.val(ax)])
        end
    end
    outsizes = size(resu)
    allAxes = reduce(union, inAxSmall)
    outaxes = map(outsizes, 1:length(outsizes)) do s, il
        if s > 2
            i = findall(i -> i == s, length.(allAxes))
            if length(i) == 1
                return allAxes[i[1]]
            elseif length(i) > 1
                @info "Found multiple matching axes for output dimension $il"
            end
        end
        return Dim{Symbol("OutAxis$(il)")}(1:s)
    end
    if !allunique(outaxes)
        #TODO: fallback with axis renaming in this case
        error("Could not determine unique output axes from output shape")
    end
    @show outaxes
    return (outaxes...,)
end


"""
    getAxis(desc, c)

Given an Axis description and a cube, returns the corresponding axis of the cube.
The Axis description can be:
  - the name as a string or symbol.
  - an Axis object
"""
getAxis(desc, c) = getAxis(desc, DD.dims(c))
getAxis(desc::ByValue, axlist::Vector{T}) where {T<:DD.Dimension} = desc.v
function getAxis(desc, axlist::VecOrTuple{DD.Dimension})
    i = findAxis(desc, axlist)
    if isa(i, Nothing)
        return nothing
    else
        return axlist[i]
    end
end
