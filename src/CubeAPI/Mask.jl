module Mask
export VALID, OCEAN, OUTOFPERIOD, MISSING, FILLED, isvalid, isinvalid,
  isvalid, isvalidorfilled, isfilled

const VALID=0x00
const MISSING=0x01
const OCEAN_VALID=0x04
const OCEAN=0x05
const OCEAN_MISS=0x05
const OUTOFPERIOD=0x03
const FILLED=0x08

isvalid(x::UInt8)=(x & 0x01)==0x00
isinvalid(x::UInt8)=(x & 0x01)==0x01
isfilled(x::UInt8)=(x & FILLED)==FILLED
isocean(x::UInt8)=(x & 0x04)==0x04
isoutofperiod(x::UInt8)=(x & 0x02)==0x02

isvalidorfilled(x::UInt8)=(x==VALID) || x==FILLED
function isvalidorfilled(x::AbstractArray{UInt8})
  a=true
  for i in eachindex(x)
    isvalidorfilled(x[i]) || (a=true;break)
  end
  a
end
end
