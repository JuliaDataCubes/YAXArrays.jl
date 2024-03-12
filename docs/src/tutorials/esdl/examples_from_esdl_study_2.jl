# # Examples from the ESDL paper (Mahecha, Gans et al. Earth Syst. Dynam., 11, 201–234, 2020)

# **NOTE:** This section is based on the case studies from the paper "Earth system data cubes unravel global multivariate dynamics" by Mahecha, Gans et al. (2019), available [here](https://github.com/esa-esdl/ESDLPaperCode.jl).
# - We have slightly adjusted the scripts. A few differences are that these new scripts are updated to Julia 1.9, and the YAXArrays.jl package is used.
# - The dataset has been updated but it has less available variables. Therefore the results might differ.
# - The calculations are performed with a very coarse spatial (2.5°) and temporal resolution (monthly).
# - These are examples for illustrative purposes of the packages and do not intend any deeper scientific interpretation. For scientific analysis use the higher spatio-temporal resolution datasets.

# ## Case study 2: Intrinsic dimensions of ecosystem dynamics
# ### As estimate based on PCAs

# * Script to reproduce and understand examples in the paper *Earth system data cubes unravel global multivariate dynamics* .

# * The code is written on Julia 1.9 

# * Normal text are explanations referring to notation and equations in the paper

# * `# comments in the code are intended to explain specific aspects of the coding`

# * ### New steps in workflows are introduced with **bold headers**


## Load requiered packages
using Pkg

## for operating data cubes
using Zarr, YAXArrays
using DimensionalData
## for operating the Earth system data lab
using EarthDataLab

## for data analysis
using Statistics, MultivariateStats, Dates, SkipNan

## for plotting later
using CairoMakie
CairoMakie.activate!()
using GeoMakie


# In this study we investigate the redundancy of the different variables in each pixel.
# Therefore we calculate a linear dimensionality reduction (PCA) and check how many dimensions
# are needed to explain 90% of the variance of a cube that contained originally 11 variables.

# ### Select and prepare (subset/gapfill) an Earth system data cube.


# We need to choose a cube and here select a monthly, 2.5° resolution global cube.
# This very low resolution cube aims at rapid processing for the safe of time and computational resources.

cube_handle = esdc(res="tiny")

# Check which variables are avaiable in the data cube:

## if we want the names of the variables:
println.(getAxis("Var", cube_handle));

# Having the variable names allows us to make a selection, such that we can subset the global cube.
# We should also take care that the variables are as complete as possible in the time window we analyze.
# This has been explored a priori.

## vector of variables we will work with
vars = ["evaporative_stress",
    "latent_energy",
    "root_moisture",
    "transpiration",
    "sensible_heat",
    "bare_soil_evaporation",
    "net_radiation",
    "net_ecosystem_exchange",
    "evaporation",
    "terrestrial_ecosystem_respiration",
    "gross_primary_productivity",
    ];

## time window where most of them are complete
timespan = Date("2003-01-01")..Date("2011-12-31")

## subset the grand cube and get the cube we will analyse here
cube_subset = cube_handle[time = timespan, variable = At(vars)]

println.(getAxis("Var", cube_subset));

# An important preprocessing step is gapfilling. We do not want to enter the debate on the optimal gapfilling method.
# What we do here is gapfilling first with the mean seasonal cycle (where it can be estimated), and interpolating
# long-recurrent gaps (typically in winter seasons).
# use the EarthDataLab buit-in function
@time cube_fill = gapFillMSC(cube_subset)

# The interpolation of wintergaps needs a function that we code here an call `LinInterp`.
  
using Interpolations

function LinInterp(y)

  try
    ## find the values we need to input
    idx_nan = findall(ismissing, y)
    idx_ok  = findall(!ismissing, y)

    ## make sure to have a homogenous input array
    y2 = Float64[y[i] for i in idx_ok]

    ## generate an interpolation object based on the good data
    itp = extrapolate(interpolate((idx_ok,), y2, Gridded(Linear())),Flat())

    ## fill the missing values based on a linter interpolation
    y[idx_nan] = itp(idx_nan)
    return y
  catch
    idx_nan = findall(ismissing, y)
    y[idx_nan] .= mean(skipmissing(y))
    return y
  end
end


# The function `LiInterp` can now be applied on each time series, so we would have a rather trival mapping of the form:

    # \begin{equation}
    #   f_{\{time\}}^{\{time}\} : \mathcal{C}(\{lat, lon, time, var\}) \rightarrow \mathcal{C}(\{lat, lon, time, var\}).
    # \end{equation}
    
#  For operations of this kind, the best is to use the `mapslices` function. In the EarthDataLab package,
# this function needs the input function, the cube handle, and an indication on which dimension we would apply it.
# The function can then infer that the output dimension here is also an axis of type `Time`:

cube_fill_itp = mapslices(LinInterp, cube_fill, dims = "Time")
    
# As we describe in the paper, we estimate the intrinsic dimensions from the raw, yet gapfilled,
# data cube (`cube_fill_itp`), but also based on spectrally decomposed data. The decomposition via discrete FFTs
# is an atomic operation of the following form (Eq. 12),

# \begin{equation}
#   f_{\{time\}}^{\{time, freq\}} : \mathcal{C}(\{lat, lon, time, var\}) \rightarrow \mathcal{C}(\{lat, lon, time, var, freq\}).
# \end{equation}

# which can be done using a pre-implemented EarthDataLab function. Note that this step will use a lot of computing time.

cube_decomp = filterTSFFT(cube_fill_itp)

# ### Estimate intrinsic dimension via PCA

# For estimating the intrinsic estimation via PCA from a multivariate time series we need essentially
# two atomic functions. First, dimensionality reduction,

# \begin{equation}
#      f_{\{time, var\}}^{\{time, princomp \}} : \mathcal{C}(\{time, var\}) \rightarrow \mathcal{C}(\{time, princomp\})
# \end{equation}

# And second estimating from the reduced space the number of dimensions that represent more variance than
# the threshold (for details see paper):

# \begin{equation}
#      f_{\{time, princomp\}}^{\{ \}} : \mathcal{C}(\{time, var\}) \rightarrow \mathcal{C}(\{int dim\})
# \end{equation}

# However, we as both steps emerge from the same analysis it is more efficient to wrap these two steps
# in a single atomic functions which has the structure:

# \begin{equation}
#      f_{\{time, var\}}^{\{ \}} : \mathcal{C}(\{time, var\}) \rightarrow \mathcal{C}(\{\})
# \end{equation}

# We can now apply this to the cube: The latter was the operation described in the paper (Eq. 11) as

# \begin{equation}
#      f_{\{time, var\}}^{\{ \}} : \mathcal{C}(\{lat, lon, time, var\}) \rightarrow \mathcal{C}(\{lat, lon\})
# \end{equation}


function sufficient_dimensions(xin::AbstractArray, expl_var::Float64 = 0.95)

  any(ismissing,xin) && return NaN
  npoint, nvar = size(xin)
  means = mean(xin, dims = 1)
  stds  = std(xin,  dims = 1)
  xin   = broadcast((y,m,s) -> s>0.0 ? (y-m)/s : one(y), xin, means, stds)
  pca = fit(PCA, xin', pratio = 0.999, method = :svd)
  return findfirst(cumsum(principalvars(pca)) / tprincipalvar(pca) .> expl_var)
end


# We first apply the function `cube_decomp` to the standard data cube with the threshold of 95% of retained variance. As we see from the description of the atomic function above, we need as minimum input dimension `Time` and `Variable`. We call the output cube `cube_int_dim`, which efficiently is a map.
cube_int_dim = mapslices(sufficient_dimensions, cube_fill_itp, 0.95, dims = ("Time","Variable"))

# Saving intermediate results can save CPU later, not needed to guarantee reproducibility tough
# `savecube(cube_int_dim, "../data/IntDim", overwrite=true)`

# Now we apply the same function

#   \begin{equation}
#       f_{\{time, var\}}^{\{ \}} : \mathcal{C}(\{time, var\}) \rightarrow \mathcal{C}(\{\})
#   \end{equation}
  
#   to the spectrally decomposed cube (Eq. 13):
  
#   \begin{equation}
#          f_{\{time, var\}}^{\{\}} : \mathcal{C}(\{lat, lon, time, var, freq\})\rightarrow \mathcal{C}(\{lat, lon, freq\})
#   \end{equation}

cube_int_dim_dec = mapslices(sufficient_dimensions, cube_decomp, 0.95, dims = ("Time","Variable"))

# for saving the output please use the command line below
# `savecube(cube_int_dim_dec, "../data/IntDimDec", overwrite=true)`

# ### Visualizing results is not part of the EarthDataLab package.
# Here we use GeoMalkie for plotting in comparison to the original script that relies on PyPlot.

# #### Plotting the instrinsic dimensions maps
## standard function for plotting global grids
function geoplotsfx(xin, titlein, labelin, crange, cmap)
  fig = GeoMakie.Figure(fontsize=19)
  ax = GeoAxis(fig[1,1]; coastlines = false,
  lonlims=(-180, 180), latlims = (-90,90)
  )
  sf = GeoMakie.surface!(ax, -180:2.5:180, -90:2.5:90, xin; shading = false,
  colormap = (cmap, 1,), colorrange=crange, rev=true)
  cb1 = Colorbar(fig[2,1], sf; label=labelin, width = Relative(0.5), vertical=false, highclip=RGBA{Float32}(0.059f0,0.084f0,0.072f0,1f0))
  Label(fig[0,1], titlein, fontsize=25, width = Relative(0.5))
  return(fig)
end

labelin = "Intrinsic dimension"

crange = (0,11)

cmap = Reverse(:magma)

scale_name = ["(a) Original Data", "(b) Long-term variability", "(c) Seasonal variability", "(d) Short-term variability"]

f = CairoMakie.Figure(fontsize=15, resolution = (1000, 700))
titlein = string(scale_name[1])
## map original data  
  ax = GeoAxis(f[1,1]; coastlines = false, lonlims=(-180, 180), latlims = (-90,90), title=scale_name[1])
  sf1 = GeoMakie.surface!(ax, -180:2.5:180, -90:2.5:90, cube_int_dim[:,:]; shading = false,
  colormap = (cmap, 1,), colorrange=crange, rev=true)
  cb1 = Colorbar(f[3,1:2], sf1; label=labelin, width = Relative(0.5), vertical=false, highclip=RGBA{Float32}(0.059f0,0.084f0,0.072f0,1f0))
## map Long-term variability
  ax = GeoAxis(f[1,2]; coastlines = false, lonlims=(-180, 180), latlims = (-90,90), title=scale_name[2])
  GeoMakie.surface!(ax, -180:2.5:180, -90:2.5:90, cube_int_dim_dec[2,:,:]; shading = false,
  colormap = (cmap, 1,), colorrange=crange, rev=true)
## map seasonal variability
  ax = GeoAxis(f[2,1]; coastlines = false, lonlims=(-180, 180), latlims = (-90,90), title=scale_name[3])
  GeoMakie.surface!(ax, -180:2.5:180, -90:2.5:90, cube_int_dim_dec[3,:,:]; shading = false,
  colormap = (cmap, 1,), colorrange=crange, rev=true)
## map seasonal variability
  ax = GeoAxis(f[2,2]; coastlines = false, lonlims=(-180, 180), latlims = (-90,90), title=scale_name[4])
  GeoMakie.surface!(ax, -180:2.5:180, -90:2.5:90, cube_int_dim_dec[4,:,:]; shading = false,
  colormap = (cmap, 1,), colorrange=crange, rev=true)
f


# #### Plotting the intrinsic dimensions histograms 

# we will weight out reslults considering the pixel size. For this we use the cosine of the latitudes. 
lat_ax_vals = getAxis("lat", cube_int_dim_dec)
lon_ax_vals = getAxis("lon", cube_int_dim_dec)
weights = reshape(cosd.(repeat(lat_ax_vals, inner = length(lon_ax_vals))), 144,72)

## identify pixels with values and exclude missings
idx = findall(i->i>0, skipmissing(cube_int_dim[:,:]))
weights_sub = weights[idx]
weights_sum = sum(weights_sub)

## function for calculation weighted frequencies of intrinsic dimensions
function weightdatafrec(xin, weights_sub, weights_sum)
  dout = Array{Union{Missing, Float32}}(missing, 11, 2)
  dout[:,1] .= 1:11
  for i in 1:size(dout)[1]
  idx2 = findall(x->x==dout[i,1], xin)
  dout[i,2] = sum(weights_sub[idx2])/weights_sum
  end
  dout
end

d1 = weightdatafrec(skipmissing(cube_int_dim[:,:])[idx], weights_sub, weights_sum)
d2 = weightdatafrec(skipmissing(cube_int_dim_dec[2,:,:])[idx], weights_sub, weights_sum)
d3 = weightdatafrec(skipmissing(cube_int_dim_dec[3,:,:])[idx], weights_sub, weights_sum)
d4 = weightdatafrec(skipmissing(cube_int_dim_dec[4,:,:])[idx], weights_sub, weights_sum)

## plot histograms
f2 = CairoMakie.Figure()
limits = (1, 11, 0, 0.6)
ax1 = Axis(f2[1, 1], ylabel="Weighted frequency", xticks = 1:11, yticks = 0:0.2:0.6; limits, title=scale_name[1])
ax2 = Axis(f2[2, 1], xticks = 1:11, yticks = 0:0.2:0.6; limits, title=scale_name[2])
ax3 = Axis(f2[3, 1], xticks = 1:11, yticks = 0:0.2:0.6; limits, title=scale_name[3])
ax4 = Axis(f2[4, 1], xlabel="Intrinsic dimensions", xticks = 1:11, yticks = 0:0.2:0.6; limits, title=scale_name[4])
## (a) Original data
x = 1:11
barplot!(ax1, x, d1[:,2]; color=x, colormap=cmap, colorrange=crange)#, weights=weights_idx)
## (b) Long-term variability
barplot!(ax2, x, d2[:,2]; color=x, colormap=cmap, colorrange=crange)
## (c) Seasonal variability
barplot!(ax3, x, d3[:,2]; color=x, colormap=cmap, colorrange=crange)
## (d) Short-term variability
barplot!(ax4, x, d4[:,2]; color=x, colormap=cmap, colorrange=crange)
f2