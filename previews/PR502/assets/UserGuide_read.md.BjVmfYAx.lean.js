import{_ as d,C as l,c as r,o,j as s,al as p,G as n,a,w as e}from"./chunks/framework.C6dRi87J.js";const b=JSON.parse('{"title":"Read YAXArrays and Datasets","description":"","frontmatter":{},"headers":[],"relativePath":"UserGuide/read.md","filePath":"UserGuide/read.md","lastUpdated":null}'),g={name:"UserGuide/read.md"},E={class:"jldocstring custom-block",open:""};function c(u,i,y,F,m,C){const h=l("Badge"),t=l("PluginTabsTab"),k=l("PluginTabs");return o(),r("div",null,[i[7]||(i[7]=s("h1",{id:"Read-YAXArrays-and-Datasets",tabindex:"-1"},[a("Read YAXArrays and Datasets "),s("a",{class:"header-anchor",href:"#Read-YAXArrays-and-Datasets","aria-label":'Permalink to "Read YAXArrays and Datasets {#Read-YAXArrays-and-Datasets}"'},"​")],-1)),i[8]||(i[8]=s("p",null,"This section describes how to read files, URLs, and directories into YAXArrays and datasets.",-1)),i[9]||(i[9]=s("h2",{id:"open-dataset",tabindex:"-1"},[a("open_dataset "),s("a",{class:"header-anchor",href:"#open-dataset","aria-label":'Permalink to "open_dataset"'},"​")],-1)),i[10]||(i[10]=s("p",null,[a("The usual method for reading any format is using this function. See its "),s("code",null,"docstring"),a(" for more information.")],-1)),s("details",E,[s("summary",null,[i[0]||(i[0]=s("a",{id:"YAXArrays.Datasets.open_dataset",href:"#YAXArrays.Datasets.open_dataset"},[s("span",{class:"jlbinding"},"YAXArrays.Datasets.open_dataset")],-1)),i[1]||(i[1]=a()),n(h,{type:"info",class:"jlObjectType jlFunction",text:"Function"})]),i[3]||(i[3]=p("",6)),n(h,{type:"info",class:"source-link",text:"source"},{default:e(()=>i[2]||(i[2]=[s("a",{href:"https://github.com/JuliaDataCubes/YAXArrays.jl/blob/a4638a16a9a5ad69f2cc8da7bd3cae6d021a8601/src/DatasetAPI/Datasets.jl#L420-L436",target:"_blank",rel:"noreferrer"},"source",-1)])),_:1})]),i[11]||(i[11]=p("",27)),n(k,null,{default:e(()=>[n(t,{label:"single variable"},{default:e(()=>i[4]||(i[4]=[s("div",{class:"language-julia vp-adaptive-theme"},[s("button",{title:"Copy Code",class:"copy"}),s("span",{class:"lang"},"julia"),s("pre",{class:"shiki shiki-themes github-light github-dark vp-code",tabindex:"0"},[s("code",null,[s("span",{class:"line"},[s("span",{style:{"--shiki-light":"#005CC5","--shiki-dark":"#79B8FF"}},"readcubedata"),s("span",{style:{"--shiki-light":"#24292E","--shiki-dark":"#E1E4E8"}},"(ds"),s("span",{style:{"--shiki-light":"#D73A49","--shiki-dark":"#F97583"}},"."),s("span",{style:{"--shiki-light":"#24292E","--shiki-dark":"#E1E4E8"}},"tos)")])])])],-1),s("div",{class:"language- vp-adaptive-theme"},[s("button",{title:"Copy Code",class:"copy"}),s("span",{class:"lang"}),s("pre",{class:"shiki shiki-themes github-light github-dark vp-code",tabindex:"0"},[s("code",null,[s("span",{class:"line"},[s("span",null,"┌ 180×170×24 YAXArray{Union{Missing, Float32}, 3} ┐")]),a(`
`),s("span",{class:"line"},[s("span",null,"├─────────────────────────────────────────────────┴────────────────────── dims ┐")]),a(`
`),s("span",{class:"line"},[s("span",null,"  ↓ lon  Sampled{Float64} 1.0:2.0:359.0 ForwardOrdered Regular Points,")]),a(`
`),s("span",{class:"line"},[s("span",null,"  → lat  Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points,")]),a(`
`),s("span",{class:"line"},[s("span",null,"  ↗ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points")]),a(`
`),s("span",{class:"line"},[s("span",null,"├──────────────────────────────────────────────────────────────────── metadata ┤")]),a(`
`),s("span",{class:"line"},[s("span",null,"  Dict{String, Any} with 10 entries:")]),a(`
`),s("span",{class:"line"},[s("span",null,'  "units"          => "K"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "missing_value"  => 1.0f20')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "cell_methods"   => "time: mean (interval: 30 minutes)"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "name"           => "tos"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "long_name"      => "Sea Surface Temperature"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "original_units" => "degC"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "standard_name"  => "sea_surface_temperature"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "_FillValue"     => 1.0f20')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "original_name"  => "sosstsst"')]),a(`
`),s("span",{class:"line"},[s("span",null,"├──────────────────────────────────────────────────────────── loaded in memory ┤")]),a(`
`),s("span",{class:"line"},[s("span",null,"  data size: 2.8 MB")]),a(`
`),s("span",{class:"line"},[s("span",null,"└──────────────────────────────────────────────────────────────────────────────┘")])])])],-1)])),_:1}),n(t,{label:"with the `:` operator"},{default:e(()=>i[5]||(i[5]=[s("div",{class:"language-julia vp-adaptive-theme"},[s("button",{title:"Copy Code",class:"copy"}),s("span",{class:"lang"},"julia"),s("pre",{class:"shiki shiki-themes github-light github-dark vp-code",tabindex:"0"},[s("code",null,[s("span",{class:"line"},[s("span",{style:{"--shiki-light":"#24292E","--shiki-dark":"#E1E4E8"}},"ds"),s("span",{style:{"--shiki-light":"#D73A49","--shiki-dark":"#F97583"}},"."),s("span",{style:{"--shiki-light":"#24292E","--shiki-dark":"#E1E4E8"}},"tos[:, :, :]")])])])],-1),s("div",{class:"language- vp-adaptive-theme"},[s("button",{title:"Copy Code",class:"copy"}),s("span",{class:"lang"}),s("pre",{class:"shiki shiki-themes github-light github-dark vp-code",tabindex:"0"},[s("code",null,[s("span",{class:"line"},[s("span",null,"┌ 180×170×24 YAXArray{Union{Missing, Float32}, 3} ┐")]),a(`
`),s("span",{class:"line"},[s("span",null,"├─────────────────────────────────────────────────┴────────────────────── dims ┐")]),a(`
`),s("span",{class:"line"},[s("span",null,"  ↓ lon  Sampled{Float64} 1.0:2.0:359.0 ForwardOrdered Regular Points,")]),a(`
`),s("span",{class:"line"},[s("span",null,"  → lat  Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points,")]),a(`
`),s("span",{class:"line"},[s("span",null,"  ↗ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points")]),a(`
`),s("span",{class:"line"},[s("span",null,"├──────────────────────────────────────────────────────────────────── metadata ┤")]),a(`
`),s("span",{class:"line"},[s("span",null,"  Dict{String, Any} with 10 entries:")]),a(`
`),s("span",{class:"line"},[s("span",null,'  "units"          => "K"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "missing_value"  => 1.0f20')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "cell_methods"   => "time: mean (interval: 30 minutes)"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "name"           => "tos"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "long_name"      => "Sea Surface Temperature"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "original_units" => "degC"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "standard_name"  => "sea_surface_temperature"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "_FillValue"     => 1.0f20')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "original_name"  => "sosstsst"')]),a(`
`),s("span",{class:"line"},[s("span",null,"├──────────────────────────────────────────────────────────── loaded in memory ┤")]),a(`
`),s("span",{class:"line"},[s("span",null,"  data size: 2.8 MB")]),a(`
`),s("span",{class:"line"},[s("span",null,"└──────────────────────────────────────────────────────────────────────────────┘")])])])],-1),s("p",null,"In this case, you should know in advance how many dimensions there are and how long they are, which shouldn't be hard to determine since this information is already displayed when querying such variables.",-1)])),_:1}),n(t,{label:"Complete Dataset"},{default:e(()=>i[6]||(i[6]=[s("div",{class:"language-julia vp-adaptive-theme"},[s("button",{title:"Copy Code",class:"copy"}),s("span",{class:"lang"},"julia"),s("pre",{class:"shiki shiki-themes github-light github-dark vp-code",tabindex:"0"},[s("code",null,[s("span",{class:"line"},[s("span",{style:{"--shiki-light":"#24292E","--shiki-dark":"#E1E4E8"}},"ds_loaded "),s("span",{style:{"--shiki-light":"#D73A49","--shiki-dark":"#F97583"}},"="),s("span",{style:{"--shiki-light":"#005CC5","--shiki-dark":"#79B8FF"}}," readcubedata"),s("span",{style:{"--shiki-light":"#24292E","--shiki-dark":"#E1E4E8"}},"(ds)")]),a(`
`),s("span",{class:"line"},[s("span",{style:{"--shiki-light":"#24292E","--shiki-dark":"#E1E4E8"}},"ds_loaded["),s("span",{style:{"--shiki-light":"#032F62","--shiki-dark":"#9ECBFF"}},'"tos"'),s("span",{style:{"--shiki-light":"#24292E","--shiki-dark":"#E1E4E8"}},"] "),s("span",{style:{"--shiki-light":"#6A737D","--shiki-dark":"#6A737D"}},"# Load the variable of interest; the loaded status is shown for each variable.")])])])],-1),s("div",{class:"language- vp-adaptive-theme"},[s("button",{title:"Copy Code",class:"copy"}),s("span",{class:"lang"}),s("pre",{class:"shiki shiki-themes github-light github-dark vp-code",tabindex:"0"},[s("code",null,[s("span",{class:"line"},[s("span",null,"┌ 180×170×24 YAXArray{Union{Missing, Float32}, 3} ┐")]),a(`
`),s("span",{class:"line"},[s("span",null,"├─────────────────────────────────────────────────┴────────────────────── dims ┐")]),a(`
`),s("span",{class:"line"},[s("span",null,"  ↓ lon  Sampled{Float64} 1.0:2.0:359.0 ForwardOrdered Regular Points,")]),a(`
`),s("span",{class:"line"},[s("span",null,"  → lat  Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points,")]),a(`
`),s("span",{class:"line"},[s("span",null,"  ↗ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points")]),a(`
`),s("span",{class:"line"},[s("span",null,"├──────────────────────────────────────────────────────────────────── metadata ┤")]),a(`
`),s("span",{class:"line"},[s("span",null,"  Dict{String, Any} with 10 entries:")]),a(`
`),s("span",{class:"line"},[s("span",null,'  "units"          => "K"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "missing_value"  => 1.0f20')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "cell_methods"   => "time: mean (interval: 30 minutes)"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "name"           => "tos"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "long_name"      => "Sea Surface Temperature"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "original_units" => "degC"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "standard_name"  => "sea_surface_temperature"')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "_FillValue"     => 1.0f20')]),a(`
`),s("span",{class:"line"},[s("span",null,'  "original_name"  => "sosstsst"')]),a(`
`),s("span",{class:"line"},[s("span",null,"├──────────────────────────────────────────────────────────── loaded in memory ┤")]),a(`
`),s("span",{class:"line"},[s("span",null,"  data size: 2.8 MB")]),a(`
`),s("span",{class:"line"},[s("span",null,"└──────────────────────────────────────────────────────────────────────────────┘")])])])],-1)])),_:1})]),_:1}),i[12]||(i[12]=p("",21))])}const D=d(g,[["render",c]]);export{b as __pageData,D as default};
