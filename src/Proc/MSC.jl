module MSC
export removeMSC, gapFillMSC, getMSC, getMedSC
using ..Cubes
using ..DAT
using ..Proc
import Statistics: quantile!

function removeMSC(aout,ain,NpY::Integer,tmsc,tnmsc)
    #Start loop through all other variables
    fillmsc(1,tmsc,tnmsc,ain,NpY)
    subtractMSC(tmsc,ain,aout,NpY)
    nothing
end

"""
    removeMSC(c::AbstractCubeData)

Removes the mean annual cycle from each time series of a data cube.

**Input Axes** `Time`axis

**Output Axes** `Time`axis
"""
function removeMSC(c::AbstractCubeData;kwargs...)
    NpY = getNpY(c)
    mapCube(
        removeMSC,
        c,
        NpY,
        zeros(Union{Missing,Float64},NpY),
        zeros(Int,NpY);
        indims  = InDims( "Time" ),
        outdims = OutDims("Time" ),
        kwargs...
    )
end

"""
    gapFillMSC

Fills missing values of each time series in a cube with the mean annual cycle.

**Input Axes** `Time`axis

**Output Axes** `Time`axis
"""
function gapFillMSC(c::AbstractCubeData;kwargs...)
  NpY=getNpY(c)
  mapCube(gapFillMSC,c,NpY,zeros(Union{Float64,Missing},NpY),zeros(Int,NpY);indims=InDims("Time"),outdims=OutDims("Time"),kwargs...)
end

function gapFillMSC(aout::AbstractVector,ain::AbstractVector,NpY::Integer,tmsc,tnmsc)
  fillmsc(1,tmsc,tnmsc,ain,NpY)
  replaceMisswithMSC(tmsc,ain,aout,NpY)
end


"""
    getMSC

Returns the mean annual cycle from each time series.

**Input Axes** `Time`axis

**Output Axes** `MSC`axis

"""
function getMSC(c::AbstractCubeData;kwargs...)
  outdims = OutDims(MSCAxis(getNpY(c)))
  indims = InDims(TimeAxis)
  mapCube(getMSC,c,zeros(Int,getNpY(c)),zeros(Union{Float64,Missing},getNpY(c));indims=indims,outdims=outdims,kwargs...)
end

function getMSC(aout::AbstractVector,ain::AbstractVector,nmsc,fmsc;imscstart::Int=1,NpY=length(aout))
    NpY=length(aout)
    fillmsc(imscstart,fmsc,nmsc,ain,NpY)
    copyto!(aout,fmsc)
end



"Subtracts given msc from input vector"
function subtractMSC(msc::AbstractVector,xin2::AbstractVector,xout2,NpY)
    imsc=1
    ltime=length(xin2)
    for i in 1:ltime
        xout2[i] = xin2[i]-msc[imsc]
        imsc =imsc==NpY ? 1 : imsc+1 # Increase msc time step counter
    end
end

"Replaces missing values with mean seasonal cycle"
function replaceMisswithMSC(msc::AbstractVector,xin::AbstractArray,xout::AbstractArray,NpY::Integer)
  imsc=1
  for i in eachindex(xin)
    if ismissing(xin[i]) && !ismissing(msc[imsc])
      xout[i]=msc[imsc]
    else
      xout[i]=xin[i]
    end
    imsc= imsc==NpY ? 1 : imsc+1 # Increase msc time step counter
  end
end

"""
    getMedMSC(c::AbstractCubeData)

Returns the median annual cycle from each time series.

**Input Axes** `Time`axis

**Output Axes** `MSC`axis
"""
function getMedSC(c::AbstractCubeData;kwargs...)
  outdims = OutDims(MSCAxis(getNpY(c)))
  indims = InDims(TimeAxis)
  mapCube(getMedSC,c;indims=indims,outdims=outdims,kwargs...)
end

function getMedSC(aout::AbstractVector{Union{T,Missing}},ain::AbstractVector) where T
    #Reshape the cube to squeeze unimportant variables
    NpY=length(aout)
    yvec=T[]
    q=[convert(eltype(yvec),0.5)]
    for doy=1:length(aout)
        empty!(yvec)
        for i=doy:NpY:length(ain)
            ismissing(ain[i]) || push!(yvec,ain[i])
        end
        aout[doy] = isempty(yvec) ? missing : quantile!(yvec,q)[1]
    end
    aout
end


"Calculates the mean seasonal cycle of a vector"
function fillmsc(imscstart::Integer,msc::AbstractVector{T1},nmsc::AbstractVector{Int},xin::AbstractVector,NpY) where T1
  imsc=imscstart
  fill!(msc,zero(T1))
  fill!(nmsc,0)
  for v in xin
    if !ismissing(v)
      msc[imsc]  += v
      nmsc[imsc] += 1
    end
    imsc=imsc==NpY ? 1 : imsc+1 # Increase msc time step counter
  end
  for i in 1:NpY msc[i] = nmsc[i] > 0 ? msc[i]/nmsc[i] : missing end # Get MSC by dividing by number of points
end


end
