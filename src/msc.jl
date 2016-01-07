"Function that removes mean seasonal cycle from xin and writes the MSC to xout. The time dimension is specified in itimedim, NpY is the number of years"
function removeMSC!{T,ndim}(xin::AbstractArray{T,ndim},xout::AbstractArray{T,ndim};NpY::Integer=10)

    #Start loop through all other variables
    msc=getMSC!(xin,xout,NpY)
    subtractMSC(msc,xout,xin,NpY)
    xout
end


"Calculate the mean seasonal cycle of xin and write the output to xout."
function getMSC!(xin::AbstractVector,xout::AbstractVector,NpY::Integer;imscstart::Int=1)
    #Reshape the cube to squeeze unimportant variables
    ntime=length(xin)
    length(xin)==length(xout) || error("Length of input and output vectors must be the same")
    msc=sub(xout,length(xout)-NpY+1:length(xout)) # This is the array where the temp msc is stored
    nmsc=sub(xout,(length(xout)-2*NpY+1):(length(xout)-NpY)) # This is for counting how many values were added
    fillmsc(imscstart,msc,nmsc,xin,NpY)
    msc
end


function subtractMSC(msc::AbstractVector,xin2::AbstractVector,xout2,NpY)
    imsc=1
    ltime=length(xin2)
    for i in 1:ltime
        xout2[i] = xin2[i]-msc[imsc]
        imsc =imsc==NpY ? 1 : imsc+1 # Increase msc time step counter
    end
end

function fillmsc{T}(imscstart::Integer,msc::AbstractVector{T},nmsc::AbstractVector{T},xin::AbstractVector{T},NpY)
    imsc=imscstart
    fill!(msc,zero(T))
    fill!(nmsc,zero(T))
    ltime=length(xin)
    for itime=1:ltime
        curval=xin[itime]
        if !isnan(curval)
            msc[imsc]  += curval
            nmsc[imsc] += 1
        end
        imsc=imsc==NpY ? 1 : imsc+1 # Increase msc time step counter
    end
    for i in 1:NpY msc[i] = nmsc[i] > 0 ? msc[i]/nmsc[i] : NaN end # Get MSC by dividing by number of points
end

"Function that removes mean seasonal cycle from xin and writes the MSC to xout. The time dimension is specified in itimedim, NpY is the number of years"
function removeMSC!{T,ndim}(xin::AbstractArray{T,ndim},xout::AbstractArray{T,ndim},NpY::Integer)

    #Start loop through all other variables
    msc=getMSC!(xin,xout,NpY)
    subtractMSC(msc,xin,xout,NpY)
    xout
end
export removeMSC!

@registerDATFunction removeMSC! (TimeAxis,) TimeAxis NpY::Int
