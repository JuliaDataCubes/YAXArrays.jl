import OnlineStats
import DiskArrayEngine as DAE

function counter(yax, expected_values=nothing)
    st = if expected_values isa AbstractUnitRange{<:Int}
        compoffs = DAE.KeyConvertDicts.AddConst(Val(1-first(expected_values)))
        mydicttype = DAE.KeyConvertDicts.KeyDictType(eltype(expected_values),Int,compoffs, inv(compoffs),length(expected_values))
        OnlineStats.CountMap{eltype(yax),mydicttype}
    else
        OnlineStats.CountMap{eltype(yax),Dict{eltype(yax),Int}}
    end
    dimargs = ntuple(i->i=>nothing,ndims(yax))
    DAE.aggregate_diskarray(yax.data,st,dimargs)
end