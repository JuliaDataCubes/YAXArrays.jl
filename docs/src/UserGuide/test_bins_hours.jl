using DimensionalData

mean.(groupby(ds, Ti => Bins(dayofyear, intervals(1:8:370)))) # 8daily means

mean.(groupby(ds, Ti => hours(12; start=6, labels=x -> 6 in x ? :day : :night))) # day and night