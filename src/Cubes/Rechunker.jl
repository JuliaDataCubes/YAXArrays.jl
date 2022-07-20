using Optim

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

function get_copy_buffer_size(incube, outcube;writefac=4.0, maxbuf = 1e9, align_output=true)
    maxbuf = round(Int,maxbuf/sizeof(eltype(incube)))
    nd = ndims(incube)
    if nd == 1
        return (min(maxbuf,length(incube)),)
    end
    init = fill(maxbuf^(1/nd),nd-1)
    incs = DiskArrays.approx_chunksize(eachchunk(incube))
    outcs = DiskArrays.approx_chunksize(eachchunk(outcube))
    insize = size(incube)
    outsize = size(outcube)
    r = optimize(sz->optifunc(sz,maxbuf,incs,outcs,insize, outsize,writefac),init, iterations=100)
    bufnow = (r.minimizer...,maxbuf/prod(r.minimizer))

    bufcorrected = if align_output
        outalign.(bufnow,outcs)
    else
        bufnow
    end
    bufcorrected
end

using ProgressMeter
function copydata(outar,inar,copybuf)
    @showprogress for ii in copybuf
        outar[ii...] = inar[ii...]
    end
end

function copy_diskarray(incube,outcube;writefac=4.0, maxbuf = 1e9, align_output=true)
    size(incube) == size(outcube) || throw(ArgumentError("Input and output cubes must have the same size"))
    bufcorrected = get_copy_buffer_size(incube, outcube;writefac,maxbuf,align_output)
    copybuf = DiskArrays.GridChunks(size(outcube),bufcorrected)
    copydata(outcube,incube,copybuf)
end

