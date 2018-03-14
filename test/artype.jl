using CABLAB
c=RemoteCube()

d = getCubeData(c,variable=["air_temperature_2m","gross_primary_productivity"],longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))

dmem=readCubeData(d)

function docor(xout,xin)
    #Inside this function, xin is now a data frame
    xout[1]=cor(xin[:air_temperature_2m],xin[:gross_primary_productivity])
end
incubes = InDims(TimeAxis,VariableAxis,artype = AsDataFrame())
outcubes = OutDims()
registerDATFunction(docor,indims=incubes,outdims=outcubes)
o = mapCube(docor,dmem)

using DataFrames
using Base.Dates
function annMean(xout,xin)
    #xin is now a DataFrame where time is added as the third column
    #We derive the year and add it to the dataframe
    xin[:year] = year.(xin[:Time])
    #Now we do the annual aggregation, note that we have to exclude the time column, because we can't aggregate here
    x2 = aggregate(xin[[1,2,4]],:year,a->mean(skipmissing(a)))
    #We copy the results to our output
    xout[:,1] = x2[2]
    xout[:,2] = x2[3]
end
indims = InDims("time","var",artype=AsDataFrame(true))
outdims = OutDims(RangeAxis("Year",2002:2008),"var")
registerDATFunction(annMean,indims=indims,outdims=outdims)

mapCube(annMean,dmem)
