using Pkg

using PrecompileTools

@recompile_invalidations begin
    # load packages
    using Dates
    using Statistics
    using Zarr
    # using YAXArrays
end


@setup_workload begin
    # Putting some things in `@setup_workload` instead of `@compile_workload` can reduce the size of the
    # precompile file and potentially make loading faster.      
    @compile_workload begin

        t =  Date("2020-01-01"):Month(1):Date("2022-12-31")

        ## create cube axes
        axes = [RangeAxis("Lon", 1:10), RangeAxis("Lat", 1:10), RangeAxis("Time", t)]

        ## assign values to a cube
        z0 = YAXArray(axes, reshape(1:3600, (10,10,36)))

        # saving and opening Zarr files
        nameout = string(tempname(),".zarr")
        z1 = zcreate(Float64, 10,10,36, path=nameout)
        z1 .= z0[:,:,:]
        z2 = zopen(nameout)

        # simple data visualization
        show(z2[1,1,1])
        show(z2[1,1:3,1])
        show(z2[2,1:3,1])
        show(z2)

        # simple statistics across different axes
        zsum = mapslices(sum, z2, dims=1)
        zmean = mapslices(mean, z2, dims=2)
        zmean = mapslices(mean, z2, dims=3)

    end 
end