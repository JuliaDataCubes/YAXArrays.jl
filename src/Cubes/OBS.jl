module OBS
import ..Cubes: S3Cube, Dataset, Cube
import Zarr: S3Store, zopen, aws_config, ConsolidatedStore
import Dates
import Dates: now

global aws, cubesdict

function __init__()
  global aws, cubesdict
  aws = aws_config(creds=nothing, region="eu-de", service_name="obs", service_host="otc.t-systems.com")
  cubesdict = Dict(
    ("low","ts","global") => ("obs-esdc-v2.0.0","esdc-8d-0.25deg-184x90x90-2.0.0.zarr"),
    ("low","map","global") => ("obs-esdc-v2.0.0","esdc-8d-0.25deg-1x720x1440-2.0.0.zarr"),
    ("high","ts","global") => ("obs-esdc-v2.0.0","esdc-8d-0.083deg-184x270x270-2.0.0.zarr"),
    ("high","map","global") => ("obs-esdc-v2.0.0","esdc-8d-0.083deg-1x2160x4320-2.0.0.zarr"),
    ("low","ts","Colombia") => ("obs-esdc-v2.0.1","Cube_2019lowColombiaCube_184x60x60.zarr"),
    ("low","map","Colombia") => ("obs-esdc-v2.0.1","Cube_2019lowColombiaCube_1x336x276.zarr/"),
    ("high","ts","Colombia") => ("obs-esdc-v2.0.1","Cube_2019highColombiaCube_184x120x120.zarr"),
    ("high","map","Colombia") => ("obs-esdc-v2.0.1","Cube_2019highColombiaCube_1x3360x2760.zarr"),
  )
end

"""
    function S3Dataset(;kwargs...)

Opens a datacube from the Telecom Object Storage Service as a Dataset. This works on any system, but
might involve some latency depending on connection speed. One can either specify a `bucket`
and `store` or pick a resolution, chunking and cube region.

### Keyword arguments

  * `bucket=nothing` specify an OBS bucket for example "obs-esdc-v2.0.0"
  * `store=""` specify the root path of the cube, for example "esdc-8d-0.25deg-184x90x90-2.0.0.zarr"
  * `res="low"` pick a datacube resolution (`"low"` or `"high"`)
  * `chunks="ts"` choose a chunking (`"ts"` for time series access or `"map"` for spatial analyses)
  * `region="global"` choose a datacube (either `"global"` or `"Colombia"`)

"""
function S3Dataset(;bucket=nothing, store="", res="low", chunks="ts", region="global")
  if bucket==nothing
    bucket, store = cubesdict[(res,chunks,region)]
  end
  Dataset(zopen(S3Store(bucket,store,2,aws)))
  #Dataset(zopen(ConsolidatedStore(S3Store(bucket,store,2,aws))))
end

"""
    function S3Cube(;kwargs...)

Opens a datacube from the Telecom Object Storage Service as a Dataset. This works on any system, but
might involve some latency depending on connection speed. One can either specify a `bucket`
and `store` or pick a resolution, chunking and cube region.

### Keyword arguments

  * `bucket=nothing` specify an OBS bucket for example "obs-esdc-v2.0.0"
  * `store=""` specify the root path of the cube, for example "esdc-8d-0.25deg-184x90x90-2.0.0.zarr"
  * `res="low"` pick a datacube resolution (`"low"` or `"high"`)
  * `chunks="ts"` choose a chunking (`"ts"` for time series access or `"map"` for spatial analyses)
  * `region="global"` choose a datacube (either `"global"` or `"Colombia"`)

"""
S3Cube(;kwargs...) = Cube(S3Dataset(;kwargs...))
end
