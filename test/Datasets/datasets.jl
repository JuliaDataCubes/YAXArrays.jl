@testset "Datasets" begin
  data = [rand(4,5,12), rand(4,5,12), rand(4,5)]
  axlist1 = [RangeAxis("XVals",1.0:4.0), CategoricalAxis("YVals",[1,2,3,4,5]), RangeAxis("Time",Date(2001,1,15):Month(1):Date(2001,12,15))]
  axlist2 = [RangeAxis("XVals",1.0:4.0), CategoricalAxis("YVals",[1,2,3,4,5])]
  props = [Dict("att$i"=>i) for i=1:3]
  c1,c2,c3 = (YAXArray(axlist1, data[1], props[1]),
  YAXArray(axlist1, data[2], props[2]),
  YAXArray(axlist2, data[3], props[3])
  )
  ds = Dataset(avar = c1, something = c2, smaller = c3)
  @testset "Basic functions" begin
    b = IOBuffer()
    show(b,ds)
    s = split(String(take!(b)),"\n")
    s2 = """
    YAXArray Dataset
    Dimensions:
    XVals               Axis with 4 Elements from 1.0 to 4.0
    YVals               Axis with 5 elements: 1 2 3 4 5
    Time                Axis with 12 Elements from 2001-01-15 to 2001-12-15
    Variables: avar something smaller """
    s2 = split(s2,"\n")
    @test s[[1,2,6]] == s2[[1,2,6]]
    @test all(i->in(i,s2), s[3:5])
    for n in [:avar, :something, :smaller, :XVals, :Time, :YVals]
      @test n in propertynames(ds)
      @test n in propertynames(ds, true)
    end
    @test :axes ∉ propertynames(ds)
    @test :cubes ∉ propertynames(ds)
    @test :axes ∈ propertynames(ds, true)
    #Test getproperty
    @test all(i->in(i,values(ds.axes)),axlist1)
    @test collect(keys(ds.cubes)) == [:avar, :something, :smaller]
    @test collect(values(ds.cubes)) == [c1,c2,c3]
    @test ds.avar === c1
    @test ds.something === c2
    @test ds.smaller === c3
    @test ds[:avar] === c1
    ds2 = ds[[:avar, :smaller]]
    @test collect(keys(ds2.cubes)) == [:avar, :smaller]
    @test collect(values(ds2.cubes)) == [c1,c3]
    @test YAXArrays.Datasets.fuzzyfind("hal", ["hallo","bla","something"]) == 1
    ds3 = ds[["av", "some"]]
    @test collect(keys(ds3.cubes)) == [:av, :some]
    @test collect(values(ds3.cubes)) == [c1,c2]
    @test ds["avar"] === c1
  end
  @testset "Dataset interface" begin
    struct MockDataset
      vars
      dims
      attrs
      path
    end
    Base.getindex(d::MockDataset,i) = d.vars[i]
    Base.haskey(d::MockDataset,i) = haskey(d.vars,i)
    YAXArrayBase.get_varnames(d::MockDataset) = (keys(d.vars)...,)
    YAXArrayBase.get_var_dims(d::MockDataset,name) = d.dims[name]
    YAXArrayBase.get_var_attrs(d::MockDataset, name) = d.attrs[name]
    YAXArrayBase.create_empty(::Type{MockDataset},path) = MockDataset(Dict(),Dict(),Dict(),path)
    function YAXArrayBase.add_var(ds::MockDataset, T, name, s, dimlist, atts;kwargs...)
      ds.vars[name] = zeros(T,s...)
      ds.dims[name] = dimlist
      ds.atts[name] = atts
    end
    YAXArrayBase.backendlist[:mock] = MockDataset
    push!(YAXArrayBase.backendregex,r".mock$"=>MockDataset)
    data1,data2,d1,d2,d3 = (rand(12,5,2),rand(12,5),1:12, 0.1:0.1:0.5, ["One","Two"])
    att1 =  Dict("att1"=>5,"_ARRAY_OFFSET"=>(2,0,0))
    att2 =  Dict("att2"=>6,"_ARRAY_OFFSET"=>(2,0))
    attd1 = Dict("_ARRAY_OFFSET"=>2, "units"=>"days since 2001-01-01", "calendar"=>"gregorian")
    attd2 = Dict("attd"=>"d")
    attd3 = Dict("attd"=>"d")
    m = MockDataset(
    Dict("Var1"=>data1, "Var2"=>data2, "time"=>d1,"d2"=>d2, "d3"=>d3),
    Dict("Var1"=>("time","d2","d3"),"Var2"=>("time","d2"),"time"=>("time",),"d2"=>["d2"],"d3"=>["d3"]),
    Dict("Var1"=>att1,"Var2"=>att2,"time"=>attd1,"d2"=>attd2,"d3"=>attd3),
    "testpath.mock"
    )
    @testset "collectdims" begin
      dcollect = YAXArrays.Datasets.collectdims(m)
      @test dcollect["time"].ax isa RangeAxis
      @test YAXArrays.Cubes.Axes.axname(dcollect["time"].ax) == "time"
      @test dcollect["time"].ax.values == DateTime(2001,1,4):Day(1):DateTime(2001,1,13)
      @test dcollect["time"].offs == 2
      @test dcollect["d2"].ax isa RangeAxis
      @test YAXArrays.Cubes.Axes.axname(dcollect["d2"].ax) == "d2"
      @test dcollect["d2"].ax.values == 0.1:0.1:0.5
      @test dcollect["d2"].offs == 0
      @test dcollect["d3"].ax isa CategoricalAxis
      @test YAXArrays.Cubes.Axes.axname(dcollect["d3"].ax) == "d3"
      @test dcollect["d3"].ax.values == ["One","Two"]
      @test dcollect["d3"].offs == 0
    end

  end
end
