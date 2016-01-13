olddir=pwd()
cd(joinpath(Pkg.dir("CABLAB"),"deps"))
run(`git clone git@git.bgc-jena.mpg.de:gkraemer/hotspot_outlier_utility_functions.git`)
cd(olddir)
