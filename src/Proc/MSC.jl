module MSC
export removeMSC, gapFillMSC, getMSC, getMedSC
importall ..Cubes
importall ..DAT
importall ..CubeAPI
importall ..Proc
importall ..CubeAPI.Mask
"""
    removeMSC

Removes the mean annual cycle from each time series.

### Call signature

    mapCube(removeMSC, cube)

* `cube` data cube with a axes: `TimeAxis`

**Input Axes** `Time`axis

**Output Axes** `Time`axis

"""
function removeMSC(aout::Tuple,ain::Tuple,NpY::Integer,tmsc,tnmsc)
  xout,maskout = aout
  xin, maskin  = ain
    #Start loop through all other variables
    getMSC(tmsc,xin,tnmsc,NpY=NpY)
    subtractMSC(tmsc,xin,xout,NpY)
    copy!(maskout,maskin)
    xout
end

function alloc_msc_helpers(cube,pargs)
  NpY=getNpY(cube[1])
  (NpY,zeros(Float64,NpY),zeros(Int,NpY))
end
registerDATFunction(removeMSC,
  indims = InDims("Time",miss=MaskMissing()),
  outdims = OutDims("Time",miss=MaskMissing()),
  no_ocean=1,
  args = alloc_msc_helpers)

"""
    gapFillMSC

Fills missing values of each time series with the mean annual cycle.

### Call signature

    mapCube(gapFillMSC, cube)

* `cube` data cube with a axes: `TimeAxis`

**Input Axes** `Time`axis

**Output Axes** `Time`axis

"""
function gapFillMSC(aout::Tuple,ain::Tuple,NpY::Integer,tmsc,tnmsc)
  xin,maskin = ain
  xout,maskout = aout
  getMSC(tmsc,xin,tnmsc,NpY=NpY)
  replaceMisswithMSC(tmsc,xin,xout,maskin,maskout,NpY)
end
registerDATFunction(gapFillMSC,
  indims = InDims(TimeAxis,miss=MaskMissing()),
  outdims = OutDims(TimeAxis,miss=MaskMissing()),
  no_ocean=1,
  args = alloc_msc_helpers)


"""
    getMSC

Returns the mean annual cycle from each time series.

### Call signature

    mapCube(getMSC, cube)

* `cube` data cube with a axes: `TimeAxis`

**Input Axes** `Time`axis

**Output Axes** `MSC`axis

"""
function getMSC(xout::AbstractVector,xin::AbstractVector,nmsc::Vector{Int}=zeros(Int,length(xout));imscstart::Int=1,NpY=length(xout))
    #Reshape the cube to squeeze unimportant variables
    NpY=length(xout)
    fillmsc(imscstart,xout,nmsc,xin,NpY)
end
registerDATFunction(getMSC,
  indims = InDims(TimeAxis,miss=NaNMissing()),
  outdims = OutDims((cube,pargs)->MSCAxis(getNpY(cube[1])),miss=NaNMissing()),
  args = (cube,pargs)->(zeros(Int,getNpY(cube[1])),),
  no_ocean=1)



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
    getMedMSC

Returns the median annual cycle from each time series.

### Call signature

    mapCube(getMedMSC, cube)

* `cube` data cube with a axes: `TimeAxis`

**Input Axes** `Time`axis

**Output Axes** `MSC`axis

"""
function getMedSC(aout::Tuple,ain::Tuple)
  xout,maskout = aout
  xin,maskin   = ain
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
registerDATFunction(getMedSC,
  indims = InDims(TimeAxis,miss=MaskMissing()),
  outdims = OutDims((cube,pargs)->MSCAxis(getNpY(cube[1])),miss=MaskMissing()),
  no_ocean=1)


"Calculates the mean seasonal cycle of a vector"
function fillmsc{T1}(imscstart::Integer,msc::AbstractVector{T1},nmsc::AbstractVector{Int},xin::AbstractVector,NpY)
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
