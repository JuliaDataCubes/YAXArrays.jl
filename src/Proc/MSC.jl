module MSC
export removeMSC, gapFillMSC, getMSC, getMedSC
importall ..Cubes
importall ..DAT
importall ..CubeAPI
importall ..Proc

function removeMSC(xout::AbstractArray,maskout::AbstractArray{UInt8},xin::AbstractArray,maskin::AbstractArray{UInt8},NpY::Integer,tmsc,tnmsc)
    #Start loop through all other variables
    getMSC(tmsc,xin,tnmsc,NpY=NpY)
    subtractMSC(tmsc,xin,xout,NpY)
    copy!(maskout,maskin)
    xout
end

registerDATFunction(removeMSC,(TimeAxis,),(TimeAxis,),(cube,pargs)->begin
    NpY=getNpY(cube[1])
    (NpY,zeros(Float64,NpY),zeros(Int,NpY))
end,no_ocean=1)

function gapFillMSC(xout::AbstractArray,maskout::AbstractArray{UInt8},xin::AbstractArray,maskin::AbstractArray{UInt8},NpY::Integer,tmsc,tnmsc)

  getMSC(tmsc,xin,tnmsc,NpY=NpY)
  replaceMisswithMSC(tmsc,xin,xout,maskin,maskout,NpY)

end
registerDATFunction(gapFillMSC,(TimeAxis,),(TimeAxis,),(cube,pargs)->begin
    NpY=getNpY(cube[1])
    (NpY,zeros(Float64,NpY),zeros(Int,NpY))
end,no_ocean=1)



"Calculate the mean seasonal cycle of xin and write the output to xout."
function getMSC(xout::AbstractVector,xin::AbstractVector,nmsc::Vector{Int}=zeros(Int,length(xout));imscstart::Int=1,NpY=length(xout))
    #Reshape the cube to squeeze unimportant variables
    NpY=length(xout)
    fillmsc(imscstart,xout,nmsc,xin,NpY)
end
registerDATFunction(getMSC,(TimeAxis,),((cube,pargs)->MSCAxis(getNpY(cube[1])),),(cube,pargs)->(zeros(Int,getNpY(cube[1])),),inmissing=(:nan,),outmissing=:nan,no_ocean=1)




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

"Calculate the median seasonal cycle of xin and write the output to xout."
function getMedSC(xout::AbstractVector,maskout::AbstractVector{UInt8},xin::AbstractVector,maskin::AbstractVector{UInt8})
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
            maskout[doy]=CABLAB.CubeAPI.MISSING
        end
    end
    xout
end
registerDATFunction(getMedSC,(TimeAxis,),((cube,pargs)->MSCAxis(getNpY(cube[1])),),no_ocean=1)


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
