using ImageMagick, Documenter, ESDL, ESDLPlots, Cairo


newcubedir = mktempdir()
YAXdir(newcubedir)
# Download Cube subset
if !isempty(ESDL.YAXDefaults.cubedir[])
  c = S3Cube()
  csa = c[
    region = "South America",
    var = ["country_mask","c_emissions","gross", "net_ecosystem", "air_temperature_2m", "terrestrial_ecosystem", "soil_moisture"],
    time = 2003:2006
  ]
  saveCube(csa,"southamericacube", chunksize=(90,90,92,1))
  ESDL.YAXDefaults.cubedir[] = joinpath(newcubedir,"southamericacube")
end

exampledir = joinpath(@__DIR__,"src","examples")
allex = map(readdir(exampledir)) do fname
  n = splitext(fname)[1]
  n => joinpath("examples",fname)
end


makedocs(
    modules = [ESDL, ESDLPlots],
    clean   = true,
    format   = Documenter.HTML(),
    sitename = "ESDL.jl",
    authors = "Fabian Gans",
    pages    = [ # Compat: `Any` for 0.4 compat
        "Home" => "index.md",
        "Examples" => allex,
        "Manual" => Any[
            "cube_access.md",
            "analysis.md",
            "plotting.md",
            "iotools.md"
        ],
        "Other functions" => "./lib/misc.md"
        ]
)

deploydocs(
    #deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/esa-esdl/ESDL.jl.git",
)
