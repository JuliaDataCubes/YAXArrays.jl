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

  axlist=axes(cube)
  axlabels=map(axname,axlist)
  fixedvarsEx=quote end
  widgets=Any[]
  argvars=Symbol[]
  fixedAxes=CubeAxis[]
  signals=Signal[]

  ixaxis = setPlotAxis(xaxis,:ixaxis,axlist,fixedvarsEx,fixedAxes)
  igroup = setPlotAxis(group,:igroup,axlist,fixedvarsEx,fixedAxes)
  for (sy,val) in kwargs
    setPlotAxis(string(sy),Symbol("v_$i"),axlist,fixedvarsEx,fixedAxes)
  end

  availableIndices=find(ax->!in(ax,fixedAxes),axlist)
  availableAxis=axlist[availableIndices]

  createWidgets(axlist,availableAxis,availableIndices,fixedvarsEx,axlabels,widgets,signals,argvars,[(ixaxis,:ixaxis,"X Axis",true),(igroup, :igroup, "Group",false)])

  nax=length(axlist)

  plotfun2=quote
    axlist=axes(cube)

    $fixedvarsEx
    ndim=length(axlist)
    subcubedims=@ntuple $nax d->(d==ixaxis || d==igroup) ? length(axlist[d]) : 1

    a           = zeros(eltype(cube), subcubedims)
    m           = zeros(UInt8,        subcubedims)
    indstart    = @ntuple $nax d->(d==ixaxis || d==igroup) ? 1 : axVal2Index(axlist[d],v_d,fuzzy=true)
    indend      = @ntuple $nax d->(d==ixaxis || d==igroup) ? subcubedims[d] : axVal2Index(axlist[d],v_d,fuzzy=true)
    _read(cube,(a,m),CartesianRange(CartesianIndex(indstart),CartesianIndex(indend)))

    sd2 = filter(i->i>1,subcubedims)
    a,m = reshape(a,sd2...),reshape(m,sd2...)

    if igroup > 0
      plotf = isa(axlist[ixaxis],CategoricalAxis) ? StatPlots.groupedbar : Plots.plot
      p=plotf(axlist[ixaxis].values,a,lab=reshape(string.(axlist[igroup].values),(1,length(axlist[igroup]))))
    else
      plotf = isa(axlist[ixaxis],CategoricalAxis) ? Plots.bar : Plots.plot
      p=plotf(axlist[ixaxis].values,a)
    end
    p
  end
  if length(argvars)==0
    x=eval(:(cube->$plotfun2))
    return x(cube)
  end
  lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun2)
  liftex = Expr(:call,:map,lambda,signals...)
  #println(liftex)
  myfun=eval(
  quote
    local li
    li(cube)=$liftex
  end
  )
  for w in widgets display(w) end
  display(myfun(cube))
end

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
function plotScatter{T}(cube::AbstractCubeData{T};group=0,vsaxis=VariableAxis,xaxis=0,yaxis=0,alongaxis=0,kwargs...)

  axlist=axes(cube)
  axlabels=map(axname,axlist)
  fixedvarsEx=quote end
  widgets=Any[]
  argvars=Symbol[]
  fixedAxes=CubeAxis[]
  signals=Signal[]

  ivsaxis=findAxis(vsaxis,axlist)
  if ivsaxis>0
    push!(fixedvarsEx.args,:(ivsaxis=$ivsaxis))
    push!(fixedAxes,axlist[ivsaxis])
    vsaxis = axlist[ivsaxis]
  else
    throw(ArgumentError("Could not find axis $vsaxis in data cube."))
  end
  if length(vsaxis)<2
    error("Scatterplot not possible because $(vsaxis) has only one element.")
  elseif length(vsaxis)==2
    ixaxis=1
    iyaxis=2
    push!(fixedvarsEx.args,:(xval=1))
    push!(fixedvarsEx.args,:(yval=2))
    xfixed=true
    yfixed=true
  else
    if xaxis!=0
      ixaxis=axVal2Index(vsaxis,xaxis,fuzzy=true)
      push!(fixedvarsEx.args,:(xval=$ixaxis))
      1<=ixaxis<=length(vsaxis) || error("invalid value for x axis chosen")
    else
      ixaxis=0
    end
    if yaxis!=0
      iyaxis=axVal2Index(vsaxis,yaxis,fuzzy=true)
      push!(fixedvarsEx.args,:(yval=$iyaxis))
      1<=iyaxis<=length(vsaxis) || error("invalid value for y axis chosen")
    else
      iyaxis=0
    end
  end
  if alongaxis!=0
    ialongaxis=findAxis(alongaxis,axlist)
    ialongaxis>0 || error("Axis $alongaxis not found!")
    push!(fixedvarsEx.args,:(ialongaxis=$ialongaxis))
    push!(fixedAxes,axlist[ialongaxis])
  else
    ialongaxis=0
  end
  if group!=0
    igroup=findAxis(group,axlist)
    igroup>0 || error("Axis $group not found!")
    push!(fixedvarsEx.args,:(igroup=$igroup))
    push!(fixedAxes,axlist[igroup])
  else
    igroup=0
  end
  for (sy,val) in kwargs
    ivalaxis=findAxis(string(sy),axlist)
    ivalaxis>0 || error("Axis $sy not found")
    s=Symbol("v_$ivalaxis")
    push!(fixedvarsEx.args,:($s=$val))
    push!(fixedAxes,axlist[ivalaxis])
  end

  availableIndices=find(ax->!in(ax,fixedAxes),axlist)
  availableAxis=axlist[availableIndices]

  if ixaxis==0
    w=getWidget(vsaxis,label="X Axis")
    push!(widgets,w)
    push!(signals,signal(w))
    push!(argvars,:xval)
  end
  if iyaxis==0
    w=getWidget(vsaxis,label="Y Axis")
    push!(widgets,w)
    push!(signals,signal(w))
    push!(argvars,:yval)
  end

  if length(availableAxis) > 0

    if ialongaxis==0
      alongmenu=dropdown(OrderedDict(zip(axlabels[availableIndices],availableIndices)),label="Scatter along",value=availableIndices[1],value_label=axlabels[availableIndices[1]])
      alongsig=signal(alongmenu)
      push!(widgets,alongmenu)
      push!(argvars,:ialongaxis)
      push!(signals,alongsig)
    end
    if igroup==0
      groupmenu=dropdown(OrderedDict(zip(["None";axlabels[availableIndices]],[0;availableIndices])),label="Group",value=0,value_label="None")
      groupsig=signal(groupmenu)
      push!(widgets,groupmenu)
      push!(argvars,:igroup)
      push!(signals,groupsig)
    end
    for i in availableIndices
      w=getWidget(axlist[i])
      push!(widgets,w)
      push!(signals,signal(w))
      push!(argvars,Symbol(string("v_",i)))
    end
  end
  nax=length(axlist)

  plotfun2=quote
    axlist=axes(cube)
    $fixedvarsEx
    ndim=length(axlist)
    subcubedims = @ntuple $nax d->(d==ialongaxis || d==igroup) ? length(axlist[d]) : 1
    sliceargsx  = @ntuple $nax d->(d==ialongaxis || d==igroup) ? (1:length(axlist[d])) : (d==ivsaxis) ? axVal2Index(axlist[d],xval,fuzzy=true) : axVal2Index(axlist[d],v_d,fuzzy=true)
    sliceargsy  = @ntuple $nax d->(d==ialongaxis || d==igroup) ? (1:length(axlist[d])) : (d==ivsaxis) ? axVal2Index(axlist[d],yval,fuzzy=true) : axVal2Index(axlist[d],v_d,fuzzy=true)
    cax = getMemHandle(cube,1,CartesianIndex(subcubedims))
    cay = getMemHandle(cube,1,CartesianIndex(subcubedims))
    dataslicex=getSubRange(cax,sliceargsx...)[1]
    dataslicey=getSubRange(cay,sliceargsy...)[1]

    xvals = r1(dataslicex)
    yvals = r1(dataslicey)

    nPoints = length(yvals)
    pointSize = min(25000/nPoints,50)

    if igroup > 0
      plotf = scatterplot
      jgroup = count_to(x->isa(x,Range),sliceargsx,igroup)
      gvals=repAx(dataslicex,jgroup,prepAx(axlist[igroup]))
      p=plotf(x=xvals,y=yvals,group=gvals,pointSize=pointSize)
    else
      plotf = scatterplot
      p=plotf(x=xvals,y=yvals,pointSize=pointSize)
    end
    xlab!(p,title=string(axlist[ivsaxis].values[xval]),ticks=10,tickSizeMajor= 5)
    ylab!(p,title=string(axlist[ivsaxis].values[yval]),ticks=10,tickSizeMajor= 5)
    p
  end
  if length(argvars)==0
    (igroup==0) && push!(fixedvarsEx.args,:(igroup=0))
    x=eval(:(cube->$plotfun2))
    return x(cube)
  end
  lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun2)
  liftex = Expr(:call,:map,lambda,signals...)
  myfun=eval(quote
  local li
  li(cube)=$liftex
end)
for w in widgets display(w) end
display(myfun(cube))
end
