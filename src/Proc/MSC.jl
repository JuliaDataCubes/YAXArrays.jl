module MSC
export removeMSC, gapFillMSC, getMSC, getMedSC, gapfillpoly
import Polynomials: polyfit
import ..Proc: getNpY
import ...Cubes: AbstractCubeData
import ...DAT: mapCube, InDims, OutDims
import Statistics: quantile!

function removeMSC(aout,ain,NpY::Integer)
    #Start loop through all other variables
    tmsc, tnmsc = zeros(Union{Float64,Missing},NpY),zeros(Int,NpY)
    fillmsc(1,tmsc,tnmsc,ain,NpY)
    subtractMSC(tmsc,ain,aout,NpY)
    nothing
end

"""
    removeMSC(c::AbstractCubeData)

Removes the mean annual cycle from each time series of a data cube.

**Input Axis** `Time`axis

**Output Axis** `Time`axis
"""
function removeMSC(c::AbstractCubeData;kwargs...)
    NpY = getNpY(c)
    mapCube(
        removeMSC,
        c,
        NpY;
        indims  = InDims("Time"),
        outdims = OutDims("Time"),
        kwargs...
    )
end

"""
    gapFillMSC(c::AbstractCubeData;complete_msc=false)

Fills missing values of each time series in a cube with the mean annual cycle.
If `complete_msc` is set to `true`, the MSC will be filled with a polynomial
in case it still contains missing values due to systematic gaps.

**Input Axis** `Time`axis

**Output Axis** `Time`axis
"""
function gapFillMSC(c::AbstractCubeData;kwargs...)
  NpY=getNpY(c)
  mapCube(gapFillMSC,c,NpY;indims=InDims("Time"),outdims=OutDims("Time"),kwargs...)
end

function gapFillMSC(aout::AbstractVector,ain::AbstractVector,NpY::Integer;complete_msc=false)
  tmsc, tnmsc = zeros(Union{Float64,Missing},NpY),zeros(Int,NpY)
  fillmsc(1,tmsc,tnmsc,ain,NpY)
  if complete_msc
    fill_msc_poly!(tmsc)
  end
  replaceMisswithMSC(tmsc,ain,aout,NpY)
end

function fill_msc_poly!(tmsc)
  mscrep = [tmsc;tmsc;tmsc]
  n = length(tmsc)
  a = gapfillpoly(mscrep, max_gap = n÷2, nbefore_after = max(3,n÷30))
  tmsc .= view(a,(n+1):(n+n))
end

gapfillpoly(x::AbstractCubeData;max_gap=30,nbefore_after=10, polyorder = 2) =
  mapslices(gapfillpoly,x,dims="Time",max_gap=max_gap, nbefore_after=nbefore_after, polyorder=polyorder)

"""
    fillgaps_poly(x;max_gap=30,nbefore_after=10, polyorder = 2)

Function for polnomial gap filling. Whenever a gap smaller than `max_gap` is found
the algorithm uses `nbefore_after` time steps before and after the gap to fit
a polynomial of order `polyorder`. The missing alues are then replaced by the
fitted polynomial.
"""
function gapfillpoly(x;max_gap=30,nbefore_after=10, polyorder = 2)
    x = replace(i->(!ismissing(i) && isfinite(i)) ? i : missing,x)
    a = copy(x)
    workx = Float64[]
    worky = Float64[]
    # find first nonmissing value
    idxstart = findfirst(!ismissing,a)
    idxstart === nothing && return a
    while true
        #find next missing value
        gapstart = findnext(ismissing,a,idxstart)
        gapstart === nothing && break
        gapstop = findnext(!ismissing,a,gapstart)
        gapstop === nothing && break
        if gapstop-gapstart < max_gap
            idxfirst = max(1,gapstart - nbefore_after)
            idxlast  = min(length(a), gapstop + nbefore_after - 1)
            idxr = idxfirst:idxlast
            for (ii,idx) in enumerate(idxr)
                if !ismissing(x[idx])
                    push!(workx,idxr[ii])
                    push!(worky,x[idx])
                end
            end
            if length(workx)>polyorder
                p = polyfit(workx,worky,polyorder)
                for idx in gapstart:(gapstop-1)
                    a[idx] = p(idx)
                end
            end
        end
        idxstart = gapstop
        empty!(workx)
        empty!(worky)
    end
    a
end


"""
    getMSC(c::AbstractCubeData)

Returns the mean annual cycle from each time series.

**Input Axis** `Time`axis

**Output Axis** `MSC`axis

"""
function getMSC(c::AbstractCubeData;kwargs...)
  outdims = OutDims(MSCAxis(getNpY(c)))
  indims = InDims(TimeAxis)
  mapCube(getMSC,c,getNpY(c);indims=indims,outdims=outdims,kwargs...)
end

function getMSC(aout::AbstractVector,ain::AbstractVector,NpY;imscstart::Int=1)
    nmsc = zeros(Int,NpY)
    fillmsc(imscstart,aout,nmsc,ain,NpY)
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

**Input Axis** `Time`axis

**Output Axis** `MSC`axis
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
