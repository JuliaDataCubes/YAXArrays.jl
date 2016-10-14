module Mask
export VALID, OCEAN, OUTOFPERIOD, MISSING, FILLED, isvalid, isinvalid,
  isvalid, isvalidorfilled

const VALID=0x00
const MISSING=0x01
const OCEAN=0x05
const OUTOFPERIOD=0x03
const FILLED=0x08

isvalid(x::UInt8)=x==VALID
isinvalid(x::UInt8)=x>zero(UInt8)

isvalidorfilled(x::UInt8)=(x>UInt8(0)) || (x & FILLED)==FILLED
function isvalidorfilled(x::AbstractArray{UInt8})
  a=true
  for i in eachindex(x)
    isvalidorfilled(x[i]) || (a=true;break)
  end
  a
end
end
