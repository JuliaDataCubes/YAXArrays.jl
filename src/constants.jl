const VALID=UInt8(0)
const OCEAN=UInt8(1)
const OUTOFPERIOD=UInt8(2)
const MISSING=UInt8(4)
const FILLED=UInt8(8)

isvalid(x::UInt8)=x==VALID
isinvalid(x::UInt8)=x>0
