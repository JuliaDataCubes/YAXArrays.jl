using Optim: optimize, Optim
using ProgressMeter: @showprogress


function readsperchunk(buf_i, cs_i, fullsize_i) 
    #Make the function very shallow for >1
    fac = cs_i/buf_i
    if fac<1
        fac = 1 - (1-fac)/1000
    end
    if buf_i>fullsize_i
        fac = fac + (buf_i -fullsize_i)^2
    elseif buf_i < 1
        fac = fac + (1-buf_i)^2
    end
    fac
end

"""
    optifunc(s, maxbuf, incs, outcs, insize, outsize, writefac)
    
# Internal 
This function is going to be minimized to detect the best possible chunk setting for the rechunking of the data.
"""
function optifunc(s,maxbuf,incs,outcs, insize, outsize, writefac)
    p1 = prod(s)
    s2 = push!(Float64.(s),maxbuf/p1)
    readoverhead(s2,incs,outcs,insize, outsize, writefac)
end
function readoverhead(bufnow,incs,outcs, insize, outsize,writefac)
    prod(readsperchunk.(bufnow,incs,insize)) .+ writefac * prod(readsperchunk.(bufnow,outcs, outsize))
end


function outalign(buf,sout)
    rat = buf/sout
    if rat > 1
        buf2 = round(Int,rat)*sout
        if abs(buf2-buf)/buf < 0.1
            buf2
        else
            round(Int,buf)
        end
    else
        buf2 = sout/round(Int,1/rat)
        if isinteger(buf2) && abs(buf2-buf)/buf < 0.2
            Int(buf2)
        else
            round(Int,buf)
        end
    end
end

"""
    chunk_aligned_buffer(cs, s, maxbuf)

Copy buffer for writing an array of size `s` to chunks of size `cs` when reading
costs nothing (an in-memory source): whole output chunks, as many at a time as fit
in `maxbuf` elements, growing the fastest-varying dimension first so that blocks
of a column-major `Array` are contiguous. A buffer that is not a multiple of the
output chunks makes every chunk on its boundary be written more than once, each
time reading, decoding, merging and re-encoding it.
"""
function chunk_aligned_buffer(cs, s, maxbuf)
    buf = [min(cs[i], s[i]) for i in eachindex(cs)]
    for i in eachindex(buf)
        others = prod(buf) ÷ buf[i]                # elements per unit length along dim i
        k = clamp(fld(fld(maxbuf, others), cs[i]), 1, cld(s[i], cs[i]))
        buf[i] = min(k * cs[i], s[i])
    end
    Tuple(buf)
end

function get_copy_buffer_size(incube, outcube;writefac=4.0, maxbuf = YAXDefaults.max_cache[], align_output=true)
    maxbuf = round(Int,maxbuf/DiskArrays.element_size(incube))
    nd = ndims(incube)
    if nd == 1
        return (min(maxbuf,length(incube)),)
    end
    insize = size(incube)
    outsize = size(outcube)
    totsize = prod(insize)
    incs = DiskArrays.approx_chunksize(eachchunk(incube))
    outcs = DiskArrays.approx_chunksize(eachchunk(outcube))
    if incs == outcs
        return incs
    end
    #Catch case where buffer is larger than cube
    if maxbuf > prod(insize)
        return insize
    end
    # An in-memory source has no read cost and no chunks of its own (DiskArrays only
    # estimates some for it), so there is nothing to trade off: write whole output chunks
    if align_output && !DiskArrays.isdisk(incube)
        return chunk_aligned_buffer(outcs, outsize, maxbuf)
    end
    r = nothing
    
    @debug "Incs: ", incs, " outcs ", outcs
    for method in (Optim.NelderMead(),Optim.LBFGS(),Optim.GradientDescent(), Optim.Newton(),Optim.SimulatedAnnealing())
        init = [insize[i]*(Float64(maxbuf)/totsize)^(1/nd) for i in 1:(nd-1)]
        @debug "Init: ", init
        @debug "Method: ", method
        r = optimize(sz->optifunc(sz,maxbuf,incs,outcs,insize, outsize,writefac),init,method)
        @debug "Optimization result: $(r.minimizer)"
        Optim.converged(r) && break
    end
    Optim.converged(r) || error("Could not determine copy bufer size")
    bufnow = (r.minimizer...,maxbuf/prod(r.minimizer))

    bufcorrected = if align_output
        outalign.(bufnow,outcs)
    else
        bufnow
    end
    bufcorrected = min.(bufcorrected,insize)
    Int.(max.(bufcorrected,1))
end

"""
    copydata(outar, inar, copybuf)
Internal function which copies the data from the input `inar` into the output `outar` at the `copybuf` positions.
"""
function copydata(outar,inar,copybuf)
    @showprogress for ii in copybuf
        outar[ii...] = inar[ii...]
        # Collect the block just copied so memory stays bounded (#265), but only the
        # young generation: a full collection has to mark every live reference, so
        # with a large array of boxed elements (e.g. a String cube) in memory its cost
        # scales with the whole array and is paid once per block. The block
        # temporaries are young, so GC.gc(false) frees them at a cost independent of
        # the heap size.
        GC.gc(false)
    end
end

function copy_diskarray(incube,outcube;writefac=4.0, maxbuf = YAXDefaults.max_cache[], align_output=true)
    size(incube) == size(outcube) || throw(ArgumentError("Input and output cubes must have the same size"))
    bufcorrected = get_copy_buffer_size(incube, outcube;writefac,maxbuf,align_output)
    @debug "Copying with buffer size $bufcorrected"
    #@debug "Input chunk size: $(eachchunk(incube).chunks)"
    #@debug "Output chunk size: $(eachchunk(outcube).chunks)"
    copybuf = DiskArrays.GridChunks(size(outcube),bufcorrected)
    copydata(outcube,incube,copybuf)
end

