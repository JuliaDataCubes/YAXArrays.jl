# # Examples from the ESDL paper 
# ## Earth Syst. Dynam., 11, 201–234, 2020 (https://doi.org/10.5194/esd-11-201-2020)

# **NOTE:** This section is based on the case studies from the paper "Earth system data cubes unravel global multivariate dynamics" by Mahecha, Gans et al. (2019), available at https://github.com/esa-esdl/ESDLPaperCode.jl.
# We have slightly adjusted the scripts. A few differences are that these new scripts are updated to Julia 1.9, the YAXArrays.jl package is used, and the calculations are performed with an updated dataset.

# ## Case study 4: 

# * The code is written based on Julia 1.9

# * Normal text are explanations referring to notation and equations in the paper

# * `# comments in the code are itended explain specific aspects of the coding`

# *  **New steps in workflows are introduced with bold headers**

# Load requiered packages

using Pkg

## for operating data cubes
using EarthDataLab
using Zarr, YAXArrays, NetCDF 

## for data analysis
using WeightedOnlineStats
# using Statistics, Dates, SkipNan

using Plots

# Next we get a handle to the Earth System Data Cube we want to use, which provides a description of the cube:
cube_handle = esdc(res="tiny")

# Here we define two subcubes for gross primary productivity and for surface moisture
gpp = subsetcube(cube_handle, variable = "gross_primary_productivity", time = 2003:2012)
moisture = subsetcube(cube_handle, variable = "surface_moisture", time = 2003:2012)

# The objective is to estimate histograms of gross_primary_productivity and surface moisture and split them by AR5 region. We first download a shapefile defining these regions.
regions = Cube("/home/lina/howdoi/data/IPCCregions_2d5.nc")
regions
unique(regions[:,])

regions.lon

Plots.heatmap(regions.lon,regions.lat,regions[:,:]')

# In order to compute some aggregate statistics over our datasets we join the 3 data cubes into a single iterable table. The data is not loaded but can be iterated over in an efficient manner which is chunk-aware. Additionally we need the latitude values of the Table to compute the weights of our aggregation which represent the grid cell size.
t = CubeTable(gpp=gpp, moisture=moisture, region=regions)

# If the concept of this table is still a bit opaque, we can visualize the table.
using DataFrames, Base.Iterators
t1 =DataFrame(t[1])

# Now comes the actual aggregation. First we generate an empty `WeightedHist` for every SREX region. Then we loop through all the entries in our table and fit the gpp/moisture pair into the respective histogram. Never will the whole cube be loaded into memory, but only one chunk is read at a time. In the end we create a new (in-memory) data cube from the resulting histograms.
meangpp = cubefittable(t, WeightedMean, :gpp,  by=(:region,), weight=(i->cosd(i.lat)))

meangpp[:,:]

# tab = CubeTable(veg=cmscyr, biome=cbu, include_axes=("lat","MSC"))
# meanbybiome = cubefittable(tab,WeightedMean,:veg,by=(:biome, i->(i.MSC)), weight=i->cosd(i.lat))

using ProgressMeter
function aggregate_by_mask(t,labels)
    n_classes = length(labels)
    # Here we create an empty 2d histogram for every SREX region

    ####hists = [WeightedHist((0.0:1:12,0:0.1:1)) for i=1:n_labels]
    hists = [WeightedHist((0.0:0.1:12,0:0.01:1)) for i=1:n_classes]

    # Now loop through every data point (in space and time)
    @showprogress for row in t
        # If all data are there
        if !any(ismissing,(row.gpp, row.moisture, row.region))
            ####We select the appropriate histogram according to the region the data point belongs to
            h = hists[row.region[]]
            ####And we fit the two data points to the histogram, weight by cos of lat
            fit!(h,(row.gpp,row.moisture),cosd(row.lat))
        end
    end
    ########We create the axes for the new output data cube
    midpointsgpp   = 0.05:0.1:11.95
    midpointsmoist = 0.005:0.01:0.995
    newaxes = CubeAxis[
        CategoricalAxis("SREX",[labels[i] for i in 1:33]),
        RangeAxis("GPP",midpointsgpp),
        RangeAxis("Moisture",midpointsmoist),
    ]
    # And create the new cube object
    data = [WeightedOnlineStats.pdf(hists[reg],(g,m)) for reg in 1:33, g in midpointsgpp, m in midpointsmoist]
    CubeMem(newaxes,data)
end


ipccid = Dict(
    #IPCCregions=>LAB
    1=>"ALA",
    2=>"AMZ",
    3=>"CAM",
    4=>"CAR*",
    5=>"CAS",
    6=>"CEU",
    7=>"CGI",
    8=>"CNA",
    9=>"EAF",
    10=>"EAS",
    11=>"ENA",
    12=>"MED",
    13=>"NAS",
    14=>"NAU",
    15=>"NEB",
    16=>"NEU",
    17=>"SAF",
    18=>"SAH",
    19=>"SAS",
    20=>"SAU",
    21=>"SEA",
    22=>"SSA",
    23=>"TIB",
    24=>"WAF",
    25=>"WAS",
    26=>"WNA",
    27=>"WSA",
    28=>"ANT*",
    29=>"ARC*",
    30=>"NTP*",
    31=>"STP*",
    32=>"ETP*",
    33=>"WIO*"
)

t1

r = aggregate_by_mask(t,srex.properties["labels"])


test = filter(x->x.region== "1", t1)

gd = groupby(t1, :region)

gd[11]

import Plots
Plots.heatmap(0.005:0.01:0.995,0.05:0.1:11.95,r[srex="EAF"][:,:], clim=(0,5e-7), xlabel="Moisture", ylabel="GPP")


######################


using StatsBase, Plots
d1 = randn(10_000)
d2 = randn(10_000)

nbins1 = 25
nbins2 = 10
	
hist = fit(Histogram, (d1,d2),
		(range(minimum(d1), stop=maximum(d1), length=nbins1+1),
		range(minimum(d2), stop=maximum(d2), length=nbins2+1)))
Plots.plot(hist)