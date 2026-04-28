using PrecompileTools

@recompile_invalidations begin
    # load packages
    using Dates
    using Statistics
    using Zarr
end


@setup_workload begin
    # Putting some things in `@setup_workload` instead of `@compile_workload` can reduce the size of the
    # precompile file and potentially make loading faster.      
    @compile_workload begin
        z0 = YAXArray(rand(10,10))
        nameout = string(tempname(),".zarr")
        z0 = YAXArray(rand(10,10))
        z1 = zcreate(Float64, 10,10, path=nameout)
        z1 .= z0[:,:]
        
        
        
        
        #savecube(z0, nameout)
        # c = Cube(nameout)
        # show(c[1,1])  
        # show(c[1,1:3])
        # show(c[2,1:3])
        # show(c)
        # csum = mapslices(sum, c, dims="Dim_1")
        # cmean = mapslices(mean, c, dims="Dim_1")
       
       
        # z0 = YAXArray(rand(10,10))
        # nameout = string(tempname(),".zarr")
        # z1 = zcreate(Float64, 10,10, path=nameout)
        # z1 .= z0[:,:]
        # z2 = zopen(nameout)
        # show(z2[1,1])  
        # show(z2[1,1:3])
        # show(z2[2,1:3])
        # show(z2)
        # zsum = mapslices(sum, z2, dims=1)
        # zmean = mapslices(mean, z2, dims=2)


        # a = YAXArray(rand(10,10))
        # show(a[1,1])  
        # show(a[Dim_1=1..3])
        # show(a[Dim_2=1..3])
        # show(a)
        # a1 = mapslices(sum, a, dims="Dim_1")
        # a3 = mapslices(mean, a, dims="Dim_2")
    end
end
