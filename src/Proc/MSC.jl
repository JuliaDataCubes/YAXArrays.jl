module MSC
export removeMSC, gapFillMSC, getMSC, getMedSC
using ..Cubes
using ..DAT
using ..CubeAPI
using ..Proc
using ..CubeAPI.Mask

function removeMSC(aout,ain,NpY::Integer,tmsc,tnmsc)
    xout, maskout = aout.data, aout.mask
    xin,  maskin  = ain.data,  ain.mask
    #Start loop through all other variables
    map!((m,v)->(m & 0x01)==0 ? v : oftype(v,NaN),xin,maskin,xin)
    getMSC(tmsc,xin,tnmsc,NpY=NpY)
    subtractMSC(tmsc,xin,xout,NpY)
    copyto!(maskout,maskin)
    xout
end

function alloc_msc_helpers(cube)
  NpY=getNpY(cube)
  (NpY,zeros(Float64,NpY),zeros(Int,NpY))
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
        zeros(NpY),
        zeros(Int,NpY);
        indims  = InDims( "Time", miss = MaskMissing()),
        outdims = OutDims("Time", miss = MaskMissing()),
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
  mapCube(gapFillMSC,c,NpY,zeros(NpY),zeros(Int,NpY);indims=InDims("Time",miss=MaskMissing()),outdims=OutDims("Time",miss=MaskMissing()),kwargs...)
end

function gapFillMSC(aout::Tuple,ain::Tuple,NpY::Integer,tmsc,tnmsc)
  xin,maskin = ain.data, ain.mask
  xout,maskout = aout.data, aout.mask
  map!((m,v)->(m & 0x01)==0 ? v : oftype(v,NaN),xin,maskin,xin)
  getMSC(tmsc,xin,tnmsc,NpY=NpY)
  replaceMisswithMSC(tmsc,xin,xout,maskin,maskout,NpY)
end


"""
    getMSC

Returns the mean annual cycle from each time series.

**Input Axes** `Time`axis

**Output Axes** `MSC`axis

"""
function getMSC(c::AbstractCubeData;kwargs...)
  outdims = OutDims(MSCAxis(getNpY(c)),miss=MaskMissing())
  indims = InDims(TimeAxis,miss=MaskMissing())
  mapCube(getMSC,c,zeros(Int,getNpY(c));indims=indims,outdims=outdims,kwargs...)
end
function getMSC(xout::AbstractVector{<:AbstractFloat},xin::AbstractVector{<:AbstractFloat},nmsc::Vector{Int}=zeros(Int,length(xout));imscstart::Int=1,NpY=length(xout))
    #Reshape the cube to squeeze unimportant variables
    NpY=length(xout)
    fillmsc(imscstart,xout,nmsc,xin,NpY)
end
function getMSC(aout::AbstractVector,ain::AbstractVector,nmsc::Vector{Int}=zeros(Int,length(xout));imscstart::Int=1,NpY=length(aout[1]))
    #Reshape the cube to squeeze unimportant variables
    xout,mout = aout.data, aout.mask
    xin,min   = ain.data, ain.mask
    NpY=length(xout)
    map!((m,v)->(m & 0x01)==0 ? v : oftype(v,NaN),xin,min,xin)
    fillmsc(imscstart,xout,nmsc,xin,NpY)
    for i=1:length(xout)
      mout[i] = isnan(xout[i]) ? (min[i] | 0x01) : 0x00
    end
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
function replaceMisswithMSC(msc::AbstractVector,xin::AbstractArray,xout::AbstractArray,maskin,maskout,NpY::Integer)
  imsc=1
  for i in eachindex(xin)
    if (maskin[i] & (MISSING | OUTOFPERIOD))>0 && !isnan(msc[imsc])
      xout[i]=msc[imsc]
      maskout[i]=FILLED
    else
      xout[i]=xin[i]
      maskout[i]=maskin[i]
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
  outdims = OutDims(MSCAxis(getNpY(c)),miss=MaskMissing())
  indims = InDims(TimeAxis,miss=MaskMissing())
  mapCube(getMedSC,c;indims=indims,outdims=outdims,kwargs...)
end

function getMedSC(aout::AbstractVector,ain::AbstractVector)
  xout,maskout = aout.data, aout.mask
  xin,maskin   = ain.data, ain.mask
    #Reshape the cube to squeeze unimportant variables
    NpY=length(xout)
    yvec=eltype(xout)[]
    q=[convert(eltype(yvec),0.5)]
    for doy=1:length(xout)
        empty!(yvec)
        for i=doy:NpY:length(xin)
            maskin[i]==VALID && push!(yvec,xin[i])
        end
        if length(yvec) > 0
            xout[doy]=quantile!(yvec,q)[1]
            maskout[doy]=VALID
        else
            xout[doy]=NaN
            maskout[doy]=ESDL.CubeAPI.MISSING
        end
    end
    xout
end


"Calculates the mean seasonal cycle of a vector"
function fillmsc(imscstart::Integer,msc::AbstractVector{T1},nmsc::AbstractVector{Int},xin::AbstractVector,NpY) where T1
    imsc=imscstart
    fill!(msc,zero(T1))
    fill!(nmsc,0)
    for v in xin
        if !isnan(v)
            msc[imsc]  += v
            nmsc[imsc] += 1
        end
        imsc=imsc==NpY ? 1 : imsc+1 # Increase msc time step counter
    end
    for i in 1:NpY msc[i] = nmsc[i] > 0 ? msc[i]/nmsc[i] : NaN end # Get MSC by dividing by number of points
end


end
