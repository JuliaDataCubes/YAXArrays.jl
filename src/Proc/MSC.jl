module MSC
export removeMSC!, gapFillMSC
importall ..DAT
importall ..CubeAPI

"Function that removes mean seasonal cycle from xin and writes the MSC to xout. The time dimension is specified in itimedim, NpY is the number of years"
function removeMSC!{T,ndim}(xin::AbstractArray{T,ndim},xout::AbstractArray{T,ndim},maskin::AbstractArray{UInt8,ndim},maskout::AbstractArray{UInt8,ndim},NpY::Integer)
    #Start loop through all other variables
    msc=getMSC!(xin,xout,maskin,NpY)
    subtractMSC(msc,xin,xout,NpY)
    copy!(maskout,maskin)
    xout
end
export removeMSC!

function gapFillMSC!(xin::AbstractArray,xout::AbstractArray,maskin::AbstractArray{UInt8},maskout::AbstractArray{UInt8},NpY::Integer)

  msc=getMSC!(xin,xout,maskin,NpY)
  replaceMisswithMSC!(xin,xout,maskin,maskout,NpY)

end




"Calculate the mean seasonal cycle of xin and write the output to xout."
function getMSC!(xin::AbstractVector,xout::AbstractVector,mask,NpY::Integer;imscstart::Int=1)
    #Reshape the cube to squeeze unimportant variables
    ntime=length(xin)
    length(xin)==length(xout) || error("Length of input and output vectors must be the same")
    msc=sub(xout,length(xout)-NpY+1:length(xout)) # This is the array where the temp msc is stored
    nmsc=sub(xout,(length(xout)-2*NpY+1):(length(xout)-NpY)) # This is for counting how many values were added
    fillmsc(imscstart,msc,nmsc,xin,mask,NpY)
    msc
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
function replaceMisswithMSC!(msc::AbstractVector,xin::AbstractArray,xout::AbstractArray,maskin,maskout,NpY::Integer)
  imsc=1
  for i in eachindex(xin)
    if (mask[i] & MISSING)>0 && !isnan(msc[imsc])
      xout[i]=msc[imsc]
      maskout[i]=maskin[i] & FILLED
    end
    imsc= imsc==NpY ? 1 : imsc+1 # Increase msc time step counter
  end
end

"Calculates the mean seasonal cycle of a vector"
function fillmsc{T}(imscstart::Integer,msc::AbstractVector{T},nmsc::AbstractVector{T},xin::AbstractVector{T},mask,NpY)
    imsc=imscstart
    fill!(msc,zero(T))
    fill!(nmsc,zero(T))
    for itime=eachindex(xin)
        if mask[itime]==VALID
            msc[imsc]  += xin[itime]
            nmsc[imsc] += 1
        end
        imsc=imsc==NpY ? 1 : imsc+1 # Increase msc time step counter
    end
    for i in 1:NpY msc[i] = nmsc[i] > 0 ? msc[i]/nmsc[i] : NaN end # Get MSC by dividing by number of points
end

@registerDATFunction removeMSC! (TimeAxis,) (TimeAxis,) NpY::Int
@registerDATFunction gapFillMSC (TimeAxis,) (TimeAxis,) NpY::Int
end
