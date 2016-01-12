using CABLAB
using Base.Test
# Create test datacube first
dirname=joinpath(mktempdir(),"Cube")
genscript=joinpath(Pkg.dir("CABLAB"),"deps","tinytestcube.py")
pythoncmd="/Users/fgans/anaconda/bin/python3"
run(`$pythoncmd $genscript $dirname`)
cube=Cube(dirname)
xfloat=getCube(cube,variable="Float_Var")


@test size(xfloat)==(6,3,8)
@test isa(xfloat,CubeMem{Float32,3})
@test xfloat[1,1,:][:]==[2001.0,2001.0,2002.0,2002.0,2003.0,2003.0,2004.0,2004.0]
@test xfloat[:,2,1][:]==Float32[1:6;]



xint=getCube(cube,variable="Int_Var")
@test size(xint)==(6,3,8)
@test isa(xint,CubeMem)
@test xint[1,1,:][:]==[2001,2001,2002,2002,2003,2003,2004,2004]
@test xint[:,2,1][:]==Int[1:6;]
xint[3,1,:]


x2=getCube(cube)
@test isa(x2,Dict{UTF8String,Any})
@test x2["Int_Var"].data==xint.data
@test x2["Float_Var"].data==xfloat.data
