type XYPlot <: CABLABPlots
  xaxis
  group

end
plotAxVars(p::XYPlot)=[FixedAx(p.xaxis,:ixaxis,"X Axis",true,false),FixedAx(p.group,:igroup,"Group",false,false)]
match_subCubeDims(::XYPlot) = quote (d==ixaxis || d==igroup) => length(axlist[d]); _=>1 end
match_indstart(::XYPlot)    = quote (d==ixaxis || d==igroup) => 1; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
match_indend(::XYPlot)      = quote (d==ixaxis || d==igroup) => subcubedims[d]; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
plotCall(p::XYPlot) = quote
  if igroup > 0
    igroup < ixaxis && (a_1=transpose(a_1))
    plotf = isa(axlist[ixaxis],CategoricalAxis) ? StatPlots.groupedbar : Plots.plot
    p=plotf(axlist[ixaxis].values,a_1,
    lab=reshape(string.(axlist[igroup].values),(1,length(axlist[igroup]))),
    xlabel=axname(axlist[ixaxis]))
  else
    plotf = isa(axlist[ixaxis],CategoricalAxis) ? Plots.bar : Plots.plot
    p=plotf(axlist[ixaxis].values,a_1,xlabel=axname(axlist[ixaxis]))
  end
  p
end
nplotCubes(::XYPlot)=1

"""
`plotXY(cube::AbstractCubeData; group=0, xaxis=-1, kwargs...)`

Generic plotting tool for cube objects, can be called on any type of cube data.

### Keyword arguments

* `xaxis` which axis is to be used as x axis. Can be either an axis Datatype or a string. Short versions of axes names are possible as long as the axis can be uniquely determined.
* `group` it is possible to group the plot by a categorical axis. Can be either an axis data type or a string.
* `dim=value` can set other dimensions to certain values, for example `lon=51.5` will fix the longitude for the resulting plot

If a dimension is not the x axis or group variable and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.
"""
function plotXY{T}(cube::AbstractCubeData{T};group=nothing,xaxis=nothing,kwargs...)

  return plotGeneric(XYPlot(xaxis,group),cube;kwargs...)

end

type ScatterPlot <: CABLABPlots
  vsaxis
  alongaxis
  group
  c_1
  c_2
end
plotAxVars(p::ScatterPlot)=[
  FixedAx(p.vsaxis,:ivsaxis,"VS Axis",true,true),
  FixedAx(p.alongaxis,:ialongaxis,"Along",true,false),
  FixedAx(p.group,:igroup,"Group",false,false),
  FixedVar(p.vsaxis,p.c_1,:c_1,"X Axis",true),
  FixedVar(p.vsaxis,p.c_2,:c_2,"Y Axis",true)
  ]
match_subCubeDims(::ScatterPlot) = quote (d==ialongaxis || d==igroup) => length(axlist[d]); _=>1 end
match_indstart(::ScatterPlot)    = quote (d==ialongaxis || d==igroup) => 1; d==ivsaxis => axVal2Index(axlist[d],c_f,fuzzy=true); _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
match_indend(::ScatterPlot)      = quote (d==ialongaxis || d==igroup) => subcubedims[d]; d==ivsaxis => axVal2Index(axlist[d],c_f,fuzzy=true); _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
plotCall(p::ScatterPlot) = quote
  nPoints = length(a_1)
  pointSize = min(5000/nPoints,3)
  msw=pointSize > 2 ? 1 : 0
  #fmt=nPoints>20000 ? :png : :svg
  fmt=:svg
  if igroup > 0 && (igroup != ialongaxis)
    igroup < ialongaxis && (a_1=transpose(a_1);a_2=transpose(a_2))
    p=Plots.scatter(a_1,a_2,
      xlabel=string(axlist[ivsaxis].values[c_1]),
      ylabel=string(axlist[ivsaxis].values[c_2]),
      lab=reshape(string.(axlist[igroup].values),(1,length(axlist[igroup]))),
      fmt=fmt,
      ms=pointSize,
      markerstrokewidth=msw
      )
  else
    p=Plots.scatter(a_1,a_2,
      xlabel=string(axlist[ivsaxis].values[c_1]),
      ylabel=string(axlist[ivsaxis].values[c_2]),
      lab="",
      fmt=fmt,
      ms=pointSize,
      markerstrokewidth=msw
      )
  end
  p
end
nplotCubes(::ScatterPlot)=2

"""
`plotScatter(cube::AbstractCubeData; vsaxis=VariableAxis, alongaxis=0, group=0, xaxis=0, yaxis=0, kwargs...)`

Generic plotting tool for cube objects to generate scatter plots, like variable `A` against variable `B`. Can be called on any type of cube data.

### Keyword arguments

* `vsaxis` determines the axis from which the x and y variables are drawn.
* `alongaxis` determines the axis along which the variables are plotted. E.g. if you choose `TimeAxis`, a dot will be plotted for each time step.
* `xaxis` index or value of the variable to plot on the x axis
* `yaxis` index or value of the variable to plot on the y axis
* `group` it is possible to group the plot by an axis. Can be either an axis data type or a string. *Caution: This will increase the number of plotted data points*
* `dim=value` can set other dimensions to certain values, for example `lon=51.5` will fix the longitude for the resulting plot

If a dimension is not the `vsaxis` or `alongaxis` or `group` and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.
"""
function plotScatter{T}(cube::AbstractCubeData{T};group=nothing,vsaxis=VariableAxis,xaxis=nothing,yaxis=nothing,alongaxis=nothing,kwargs...)

  return plotGeneric(ScatterPlot(vsaxis,alongaxis,group,xaxis,yaxis),cube)

end
