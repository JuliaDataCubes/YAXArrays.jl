module Mask
export VALID, OCEAN, OUTOFPERIOD, MISSING, FILLED, isvalid, isinvalid,
  isvalid, isvalidorfilled
const VALID=UInt8(0)
const OCEAN=UInt8(1)
const OUTOFPERIOD=UInt8(2)
const MISSING=UInt8(4)
const FILLED=UInt8(8)

isvalid(x::UInt8)=x==VALID
isinvalid(x::UInt8)=x>0

isvalidorfilled(x::UInt8)=(x>UInt8(0)) || (x & FILLED)==FILLED
function isvalidorfilled(x::AbstractArray{UInt8})
  a=true
  for i in eachindex(x)
    isvalidorfilled(x[i]) || (a=true;break)
  end
  a
end
end
