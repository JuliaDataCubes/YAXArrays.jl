# # Examples from the ESDL paper 
# ## Earth Syst. Dynam., 11, 201–234, 2020 [doi](https://doi.org/10.5194/esd-11-201-2020)

# **NOTE:** This section is based on the case studies from the paper "Earth system data cubes unravel global multivariate dynamics" by Mahecha, Gans et al. (2019), available [here](https://github.com/esa-esdl/ESDLPaperCode.jl).
# - We have slightly adjusted the scripts. A few differences are that these new scripts are updated to Julia 1.9, and the YAXArrays.jl package is used.
# - The dataset has been updated but it has less available variables. Therefore the results might differ.
# - The calculations are performed with a very coarse spatial (2.5°) and temporal resolution (monthly).
# - These are examples for illustrative purposes of the packages and do not intend any deeper scientific interpretation. For scientific analysis use the higher spatio-temporal resolution datasets.

# ## Case study 3: Model-parameter estimation in the ESDL
# ### Example of the temperature sensitivity of ecosystem respiration

# * Script to reproduce and understand examples in the paper *Earth system data cubes unravel global multivariate dynamics* .

# * The code is written on Julia 1.9 and uses GeoMakie for plotting.

# * Normal text are explanations referring to notation and equations in the paper

# * `# comments in the code are intended explain specific aspects of the coding`

# * ### New steps in workflows are introduced with **bold headers**


## Load requiered packages
using Pkg
Pkg.instantiate()

## for operating data cubes
using DimensionalData
using Zarr, YAXArrays, NetCDF, DiskArrays

## other relevant packages
using Statistics, Dates

# ### Select and subet an Earth system data cube

# We have to choose a cube and here we select a monthly global cube of 2.5° resolution. This very low-resolution cube aims at fast processing for the safety of computational time and resources.

# using EarthDataLab
# cube_handle = esdc(res="tiny")

bucket = "esdl-esdc-v3.0.2"
store =  "esdc-16d-2.5deg-46x72x1440-3.0.2.zarr"
path = "https://s3.bgc-jena.mpg.de:9000/" * bucket * "/" * store
cube_handle = Cube(open_dataset(zopen(path, consolidated=true, fill_as_missing=true)))

# In this case it is better to have one cube for the Tair and one for terrestrial ecosystem respiration `R$_{eco}$`.
world_tair = cube_handle[variable = At("air_temperature_2m")]
world_resp = cube_handle[variable = At("terrestrial_ecosystem_respiration")]


# Find overlapping time between variables
span_starts = first(findall(i-> !ismissing(i), world_tair[:,:,:]))
axtime = collect(cube_handle.axes[3]);
println("Data span of `air_temperature_2m` starts on ", axtime[span_starts[3]])

# similarly

span_starts = first(findall(i-> !ismissing(i), world_resp[:,:,:]))
axtime = collect(cube_handle.axes[3]);
println("Data span of `terrestrial_ecosystem_respiration` starts on ", axtime[span_starts[3]])


# susbet again based on overlapping period
world_tair = world_tair[time=2001:2015]
world_resp = world_resp[time=2001:2015]

# The objective is to estimate  $Q_{10}$ from the decomposed time series.
# For details we refere the reader to Mahecha, M.D. et al. (2010) *Global convergence
# in the temperature sensitivity of respiration at ecosystem level.* Science, 329, 838-840.

# The first step is the transformation of both variables, so that the $Q_{10}$ model becomes linear and Tair the exponent:

## Element-wise transformations using `map` are done in a lazy manner, so the
## transformation will be applied only when the data is read or further processed
## We forced `world_τ` output format as Float32 to assure the output data type is equal, and to avoid further incompatibilities
world_τ = map(tair -> (tair - Float32(273.15+15))/10, world_tair)
world_ρ = map(log, world_resp)

# ... and we combine them into a Data Cube again using `concatenatecubes`
world_new = concatenatecubes([world_τ, world_ρ], Dim{:Variable}(["τ","ρ"]))


# First we need a function for time-series filtering. Using a moving average filter is the simplest way
# to decomposes a signal into fast and slow oscillations by caluclating a moving average over a window of points.
# This creates a smoothed curve (slow osc.) which can be subtracted from the original signal to obtain
# fast oscillations separately. We could have likewise used FFTs, SSA, EMD, or any other method for
# discrete time-series decomposition.
# Moving Average decomposes a signal into fast and slow oscillations
# by calculating a moving average over a window of points.
# This creates a smoothed curve (slow osc.) which can be subtracted from the original signal,
# to obtain fast oscillations separately.

function movingAverage(xout, xin; windowsize = 4)
    Z = length(xin)
    ## calculate moving average over window
    ## truncating windows for data points at beginning and end
    movAv = map(1:Z) do i
        r = max(1,i-windowsize):min(i+windowsize,Z)
        mean(view(xin,r))
    end
    ## return slow oscillations in col 1 and fast oscillations in col 2
    xout[:,1] .= movAv
    xout[:,2] .= xin .- movAv
    return xout
end

## here we define the input and output dimensions for the decomposition
indims  = InDims("Time")
outdims = OutDims("Time", Dim{:Scale}(["Slow","Fast"]))
cube_decomp = mapCube(movingAverage, world_new, indims=indims, outdims=outdims)

# ### For estimating the temperature sensitivities

## The classical $Q_{10}$ estimation could be realized with the following function
function Q10direct(xout_Q10, xout_rb, xin)
    τ, ρ = eachcol(xin)
    ## solve the regression
    b    = cor(τ, ρ)*std(ρ)/std(τ)
    a    = mean(ρ) - b*mean(τ)

    Q10  = exp(b)
    Rb   = exp(a)
    ## the returned Rb is a constant time series
    xout_rb .= Rb
    xout_Q10 .= Q10
end

# For the scale dependent parameter estimation, the function is a bit more complex. And the numbers in the code comment refer to the  supporting online materials in Mahecha et al. (2010)
function Q10SCAPE(xout_Q10, xout_rb, xin)
    ## xin is now a 3D array with dimensions Time x Scale x Variable
    τ_slow = xin[:, 1, 1]
    τ_fast = xin[:, 2, 1]
    ρ_slow = xin[:, 1, 2]
    ρ_fast = xin[:, 2, 2]
    τ      = τ_slow + τ_fast
    ρ      = ρ_slow + ρ_fast

    ## EQ S5
    ## Q10 calculated on fast oscillations only
    d    = cor(τ_fast, ρ_fast)*std(ρ_fast)/std(τ_fast)
    c    = mean(ρ_fast) - d*mean(τ_fast)
    Q10  = exp(d)

    ## EQ S6: Influence of low frequency temperature on Rb
    ρ_sc = (τ_slow .+ mean(τ)) .* d

    ## EQ S7: Time varying estimate for Rb
    ρ_b  = ρ_slow .+ mean(ρ) .- ρ_sc
    Rb_b  = exp.(ρ_b)

    xout_Q10 .= Q10
    xout_rb  .= Rb_b
end

# ### Application of these functions on the prepared cubes

indims_q10 = InDims("Time","Var")
outdims_q10 = OutDims() ## Just a single number, the first output cube
outdims_rb = OutDims("Time") ## The Rb time series, the second output cube
q10_direct, rb_direct = mapCube(Q10direct, world_new, indims=indims_q10, outdims=(outdims_q10, outdims_rb))

# For the SCAPE approach, the parameter estimation on the decomposed appraoch is then

indims_scape = InDims("Time","Scale","Var")
q10_scape, rb_scape = mapCube(Q10SCAPE,cube_decomp, indims=indims_scape, outdims=(outdims_q10, outdims_rb))

# ### The rest is plotting. In this example we use GeoMakie.
using CairoMakie, GeoMakie
CairoMakie.activate!()
using LaTeXStrings

function geoplotsfx(xin, titlein, labelin, crange, cmap)
    fig = Figure(fontsize=19)
    ax = GeoAxis(fig[1,1]; )#coastlines = false,lonlims=(-180, 180), latlims = (-90,90))
    sf = surface!(ax, -180:2.5:180, -90:2.5:90, xin; shading = false, 
        colormap = (cmap, 1,),
        colorrange=crange,
        highclip=:red
        )
    Colorbar(fig[2,1], sf; label=labelin, width = Relative(0.5), vertical=false)
    Label(fig[0,1], titlein, fontsize=25, width = Relative(0.5))
    fig
end

label_direct = L"$Q_{10}$"
label_scape = L"$SCAPE Q_{10}$"
crange = (0,3)
cmap = :GnBu

fig1 = geoplotsfx(q10_direct[:,:].data, "a) Confounded Parameter Estimation", label_direct, crange, cmap)

# and for the other case

fig2 = geoplotsfx(q10_scape[:,:].data, "b) Scale Dependent Parameter Estimation", label_scape, crange, cmap)

# ## The following are some additional analyses, not included in the paper.
# For this analysis we need to construct a new cube by concatenating a couple of previous cube outputs.
# To do this, there are two important remarks; (1) the cubes' axes order must be the same in both cubes
# (2) as well they both must have the same data chunking

## checking cubes axes order
world_tair.axes

# and 

rb_scape.axes


# Now we need to sort the rb_scape axes order. Axes order must be the same for the cubes concatenation.
data_reshaped = permutedims(rb_scape.data,(2,3,1))
rb_scape_reshaped = YAXArray(rb_scape.axes[[2,3,1]],data_reshaped)

# checking cubes chunking
eachchunk(world_tair)


# and 

eachchunk(rb_scape_reshaped)


# setting up the same chunking
rb_scape_reshaped = setchunks(rb_scape_reshaped, Dict("lon"=>144, "lat"=>72, "time"=>44))
rb_chunking = eachchunk(rb_scape_reshaped);
first(rb_chunking)

# and

world_tair = setchunks(world_tair, Dict("lon"=>144, "lat"=>72, "time"=>44))
tair_chunking = eachchunk(world_tair);
first(tair_chunking)


# concatenate the cubes
ds = concatenatecubes([world_tair, rb_scape_reshaped], Dim{:Variables}(["tair", "rb"]))    


# And compute the correlation between Air temperature and Base respiration
cor_tair_rb = mapslices(i->cor(eachcol(i)...),ds, dims=("Time","Variable"))
q10_diff = map((x,y)->x-y, q10_direct, q10_scape)

crange = (-1,1)
cmap = :PRGn

fig3 = geoplotsfx(cor_tair_rb[:,:].data, "Correlation Tair and Rb", "Coefficient", crange, cmap)

# and also

fig4 = geoplotsfx(q10_diff[:,:].data, string("Ratio of Q10 conv and Q10 Scape"), "Ratio", crange, cmap)