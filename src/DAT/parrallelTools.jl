function passobj(src::Int, target::Vector{Int}, nm::Symbol;
                 from_mod=Main, to_mod=Main)
    r = RemoteRef(src)
    @spawnat(src, put!(r, getfield(from_mod, nm)))
    @sync for to in target
        @spawnat(to, eval(to_mod, Expr(:(=), nm, fetch(r))))
    end
    nothing
end


function passobj(src::Int, target::Int, nm::Symbol; from_mod=Main, to_mod=Main)
    passobj(src, [target], nm; from_mod=from_mod, to_mod=to_mod)
end


function passobj(src::Int, target, nms::Vector{Symbol};
                 from_mod=Main, to_mod=Main)
    for nm in nms
        passobj(src, target, nm; from_mod=from_mod, to_mod=to_mod)
    end
end

function sendto(p::Int; args...)
    for (nm, val) in args
        @spawnat(p, eval(Main, Expr(:(=), nm, val)))
    end
end


function sendto(ps::Vector{Int}; args...)
    for p in ps
        sendto(p; args...)
    end
end

getfrom(p::Int, nm::Symbol; mod=Main) = fetch(@spawnat(p, getfield(mod, nm)))
using Base.Cartesian
@generated function distributeLoopRanges{N}(block_size::NTuple{N,Int},loopR::Vector)
    quote
        @assert length(loopR)==N
        nsplit=Int[div(l,b) for (l,b) in zip(loopR,block_size)]
        baseR=UnitRange{Int}[1:b for b in block_size]
        a=Array(NTuple{$N,UnitRange{Int}},nsplit...)
        @nloops $N i a begin
            rr=@ntuple $N d->baseR[d]+(i_d-1)*block_size[d]
            @nref($N,a,i)=rr
        end
        a=reshape(a,length(a))
    end
end

function freshworkermodule()
    in(:PMDATMODULE,names(Main)) || eval(Main,:(module PMDATMODULE
        using CABLAB
    end))
    eval(Main,quote
      rs=RemoteRef[]
      for pid in workers()
        n=remotecall_fetch(pid,()->in(:PMDATMODULE,names(Main)))
        if !n
          r1=remotecall(pid,()->(eval(Main,:(using CABLAB));nothing))
          r2=remotecall(pid,()->(eval(Main,:(module PMDATMODULE
          using CABLAB
          end));nothing))
          push!(rs,r1)
          push!(rs,r2)
        end
      end
      [wait(r) for r in rs]
  end)
  nothing
end

macro everywhereelsem(ex)
    quote
        if nprocs()>1
        Base.sync_begin()
        thunk = ()->(eval(Main.PMDATMODULE,$(Expr(:quote,ex))); nothing)
        for pid in workers()
            Base.async_run_thunk(()->remotecall_fetch(pid, thunk))
            yield() # ensure that the remotecall_fetch has been started
        end

        Base.sync_end()
        end
    end
end
