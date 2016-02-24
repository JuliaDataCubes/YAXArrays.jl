using CABLAB
using NetCDF
using Base.Test
# Create test datacube first
dirname=joinpath(mktempdir(),"Cube")
genscript=joinpath(Pkg.dir("CABLAB"),"deps","tinytestcube.py")
pythoncmd="/Users/fgans/anaconda/bin/python3"
run(`$pythoncmd $genscript $dirname`)
#Make a land sea mask
mkdir(joinpath(dirname,"mask"))
nccreate(joinpath(dirname,"mask","mask.nc"),"mask","lon",6,"lat",3,t=UInt8)
mask=fill(CABLAB.VALID,6,3)
mask[1,2]=CABLAB.OCEAN
ncwrite(mask,joinpath(dirname,"mask","mask.nc"),"mask")
ncclose()
