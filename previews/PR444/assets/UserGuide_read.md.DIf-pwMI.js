import{_ as a,c as n,a2 as t,o as i}from"./chunks/framework.BekRqfPH.js";const c=JSON.parse('{"title":"Read YAXArrays and Datasets","description":"","frontmatter":{},"headers":[],"relativePath":"UserGuide/read.md","filePath":"UserGuide/read.md","lastUpdated":null}'),e={name:"UserGuide/read.md"};function p(l,s,o,r,d,u){return i(),n("div",null,s[0]||(s[0]=[t(`<h1 id="Read-YAXArrays-and-Datasets" tabindex="-1">Read YAXArrays and Datasets <a class="header-anchor" href="#Read-YAXArrays-and-Datasets" aria-label="Permalink to &quot;Read YAXArrays and Datasets {#Read-YAXArrays-and-Datasets}&quot;">​</a></h1><p>This section describes how to read files, URLs, and directories into YAXArrays and datasets.</p><h2 id="Read-Zarr" tabindex="-1">Read Zarr <a class="header-anchor" href="#Read-Zarr" aria-label="Permalink to &quot;Read Zarr {#Read-Zarr}&quot;">​</a></h2><p>Open a Zarr store as a <code>Dataset</code>:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrays</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Zarr</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">path</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;gs://cmip6/CMIP6/ScenarioMIP/DKRZ/MPI-ESM1-2-HR/ssp585/r1i1p1f1/3hr/tas/gn/v20190710/&quot;</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">store </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> zopen</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(path, consolidated</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">true</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ds </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> open_dataset</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(store)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>YAXArray Dataset</span></span>
<span class="line"><span>Shared Axes: </span></span>
<span class="line"><span>None</span></span>
<span class="line"><span>Variables: </span></span>
<span class="line"><span>height</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Variables with additional axes:</span></span>
<span class="line"><span>  Additional Axes: </span></span>
<span class="line"><span>  (↓ lon Sampled{Float64} 0.0:0.9375:359.0625 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → lat Sampled{Float64} [-89.28422753251364, -88.35700351866494, …, 88.35700351866494, 89.28422753251364] ForwardOrdered Irregular Points,</span></span>
<span class="line"><span>  ↗ Ti  Sampled{DateTime} [2015-01-01T03:00:00, …, 2101-01-01T00:00:00] ForwardOrdered Irregular Points)</span></span>
<span class="line"><span>  Variables: </span></span>
<span class="line"><span>  tas</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Properties: Dict{String, Any}(&quot;initialization_index&quot; =&gt; 1, &quot;realm&quot; =&gt; &quot;atmos&quot;, &quot;variable_id&quot; =&gt; &quot;tas&quot;, &quot;external_variables&quot; =&gt; &quot;areacella&quot;, &quot;branch_time_in_child&quot; =&gt; 60265.0, &quot;data_specs_version&quot; =&gt; &quot;01.00.30&quot;, &quot;history&quot; =&gt; &quot;2019-07-21T06:26:13Z ; CMOR rewrote data to be consistent with CMIP6, CF-1.7 CMIP-6.2 and CF standards.&quot;, &quot;forcing_index&quot; =&gt; 1, &quot;parent_variant_label&quot; =&gt; &quot;r1i1p1f1&quot;, &quot;table_id&quot; =&gt; &quot;3hr&quot;…)</span></span></code></pre></div><p>We can set <code>path</code> to a URL, a local directory, or in this case to a cloud object storage path.</p><p>A zarr store may contain multiple arrays. Individual arrays can be accessed using subsetting:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ds</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">tas</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>╭────────────────────────────────────╮</span></span>
<span class="line"><span>│ 384×192×251288 YAXArray{Float32,3} │</span></span>
<span class="line"><span>├────────────────────────────────────┴─────────────────────────────────── dims ┐</span></span>
<span class="line"><span>  ↓ lon Sampled{Float64} 0.0:0.9375:359.0625 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → lat Sampled{Float64} [-89.28422753251364, -88.35700351866494, …, 88.35700351866494, 89.28422753251364] ForwardOrdered Irregular Points,</span></span>
<span class="line"><span>  ↗ Ti  Sampled{DateTime} [2015-01-01T03:00:00, …, 2101-01-01T00:00:00] ForwardOrdered Irregular Points</span></span>
<span class="line"><span>├──────────────────────────────────────────────────────────────────── metadata ┤</span></span>
<span class="line"><span>  Dict{String, Any} with 10 entries:</span></span>
<span class="line"><span>  &quot;units&quot;         =&gt; &quot;K&quot;</span></span>
<span class="line"><span>  &quot;history&quot;       =&gt; &quot;2019-07-21T06:26:13Z altered by CMOR: Treated scalar dime…</span></span>
<span class="line"><span>  &quot;name&quot;          =&gt; &quot;tas&quot;</span></span>
<span class="line"><span>  &quot;cell_methods&quot;  =&gt; &quot;area: mean time: point&quot;</span></span>
<span class="line"><span>  &quot;cell_measures&quot; =&gt; &quot;area: areacella&quot;</span></span>
<span class="line"><span>  &quot;long_name&quot;     =&gt; &quot;Near-Surface Air Temperature&quot;</span></span>
<span class="line"><span>  &quot;coordinates&quot;   =&gt; &quot;height&quot;</span></span>
<span class="line"><span>  &quot;standard_name&quot; =&gt; &quot;air_temperature&quot;</span></span>
<span class="line"><span>  &quot;_FillValue&quot;    =&gt; 1.0f20</span></span>
<span class="line"><span>  &quot;comment&quot;       =&gt; &quot;near-surface (usually, 2 meter) air temperature&quot;</span></span>
<span class="line"><span>├─────────────────────────────────────────────────────────────────── file size ┤</span></span>
<span class="line"><span>  file size: 69.02 GB</span></span>
<span class="line"><span>└──────────────────────────────────────────────────────────────────────────────┘</span></span></code></pre></div><h2 id="Read-NetCDF" tabindex="-1">Read NetCDF <a class="header-anchor" href="#Read-NetCDF" aria-label="Permalink to &quot;Read NetCDF {#Read-NetCDF}&quot;">​</a></h2><p>Open a NetCDF file as a <code>Dataset</code>:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrays</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> NetCDF</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Downloads</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> download</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">path </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> download</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;https://www.unidata.ucar.edu/software/netcdf/examples/tos_O1_2001-2002.nc&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;example.nc&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ds </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> open_dataset</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(path)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>YAXArray Dataset</span></span>
<span class="line"><span>Shared Axes: </span></span>
<span class="line"><span>  (↓ lon Sampled{Float64} 1.0:2.0:359.0 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → lat Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  ↗ Ti  Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Variables: </span></span>
<span class="line"><span>tos</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Properties: Dict{String, Any}(&quot;cmor_version&quot; =&gt; 0.96f0, &quot;references&quot; =&gt; &quot;Dufresne et al, Journal of Climate, 2015, vol XX, p 136&quot;, &quot;realization&quot; =&gt; 1, &quot;Conventions&quot; =&gt; &quot;CF-1.0&quot;, &quot;contact&quot; =&gt; &quot;Sebastien Denvil, sebastien.denvil@ipsl.jussieu.fr&quot;, &quot;history&quot; =&gt; &quot;YYYY/MM/JJ: data generated; YYYY/MM/JJ+1 data transformed  At 16:37:23 on 01/11/2005, CMOR rewrote data to comply with CF standards and IPCC Fourth Assessment requirements&quot;, &quot;table_id&quot; =&gt; &quot;Table O1 (13 November 2004)&quot;, &quot;source&quot; =&gt; &quot;IPSL-CM4_v1 (2003) : atmosphere : LMDZ (IPSL-CM4_IPCC, 96x71x19) ; ocean ORCA2 (ipsl_cm4_v1_8, 2x2L31); sea ice LIM (ipsl_cm4_v&quot;, &quot;title&quot; =&gt; &quot;IPSL  model output prepared for IPCC Fourth Assessment SRES A2 experiment&quot;, &quot;experiment_id&quot; =&gt; &quot;SRES A2 experiment&quot;…)</span></span></code></pre></div><p>A NetCDF file may contain multiple arrays. Individual arrays can be accessed using subsetting:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ds</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">tos</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>╭────────────────────────────────────────────────╮</span></span>
<span class="line"><span>│ 180×170×24 YAXArray{Union{Missing, Float32},3} │</span></span>
<span class="line"><span>├────────────────────────────────────────────────┴─────────────────────── dims ┐</span></span>
<span class="line"><span>  ↓ lon Sampled{Float64} 1.0:2.0:359.0 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → lat Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  ↗ Ti  Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points</span></span>
<span class="line"><span>├──────────────────────────────────────────────────────────────────── metadata ┤</span></span>
<span class="line"><span>  Dict{String, Any} with 10 entries:</span></span>
<span class="line"><span>  &quot;units&quot;          =&gt; &quot;K&quot;</span></span>
<span class="line"><span>  &quot;missing_value&quot;  =&gt; 1.0f20</span></span>
<span class="line"><span>  &quot;history&quot;        =&gt; &quot; At   16:37:23 on 01/11/2005: CMOR altered the data in t…</span></span>
<span class="line"><span>  &quot;cell_methods&quot;   =&gt; &quot;time: mean (interval: 30 minutes)&quot;</span></span>
<span class="line"><span>  &quot;name&quot;           =&gt; &quot;tos&quot;</span></span>
<span class="line"><span>  &quot;long_name&quot;      =&gt; &quot;Sea Surface Temperature&quot;</span></span>
<span class="line"><span>  &quot;original_units&quot; =&gt; &quot;degC&quot;</span></span>
<span class="line"><span>  &quot;standard_name&quot;  =&gt; &quot;sea_surface_temperature&quot;</span></span>
<span class="line"><span>  &quot;_FillValue&quot;     =&gt; 1.0f20</span></span>
<span class="line"><span>  &quot;original_name&quot;  =&gt; &quot;sosstsst&quot;</span></span>
<span class="line"><span>├─────────────────────────────────────────────────────────────────── file size ┤</span></span>
<span class="line"><span>  file size: 2.8 MB</span></span>
<span class="line"><span>└──────────────────────────────────────────────────────────────────────────────┘</span></span></code></pre></div><h2 id="Read-GDAL-(GeoTIFF,-GeoJSON)" tabindex="-1">Read GDAL (GeoTIFF, GeoJSON) <a class="header-anchor" href="#Read-GDAL-(GeoTIFF,-GeoJSON)" aria-label="Permalink to &quot;Read GDAL (GeoTIFF, GeoJSON) {#Read-GDAL-(GeoTIFF,-GeoJSON)}&quot;">​</a></h2><p>All GDAL compatible files can be read as a <code>YAXArrays.Dataset</code> after loading <a href="https://yeesian.com/ArchGDAL.jl/latest/" target="_blank" rel="noreferrer">ArchGDAL</a>:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrays</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> ArchGDAL</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Downloads</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> download</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">path </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> download</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;https://github.com/yeesian/ArchGDALDatasets/raw/307f8f0e584a39a050c042849004e6a2bd674f99/gdalworkshop/world.tif&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;world.tif&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ds </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> open_dataset</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(path)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>YAXArray Dataset</span></span>
<span class="line"><span>Shared Axes: </span></span>
<span class="line"><span>  (↓ X Sampled{Float64} -180.0:0.17578125:179.82421875 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Y Sampled{Float64} 90.0:-0.17578125:-89.82421875 ReverseOrdered Regular Points)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Variables: </span></span>
<span class="line"><span>Blue, Green, Red</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Properties: Dict{String, Any}(&quot;projection&quot; =&gt; &quot;GEOGCS[\\&quot;WGS 84\\&quot;,DATUM[\\&quot;WGS_1984\\&quot;,SPHEROID[\\&quot;WGS 84\\&quot;,6378137,298.257223563,AUTHORITY[\\&quot;EPSG\\&quot;,\\&quot;7030\\&quot;]],AUTHORITY[\\&quot;EPSG\\&quot;,\\&quot;6326\\&quot;]],PRIMEM[\\&quot;Greenwich\\&quot;,0,AUTHORITY[\\&quot;EPSG\\&quot;,\\&quot;8901\\&quot;]],UNIT[\\&quot;degree\\&quot;,0.0174532925199433,AUTHORITY[\\&quot;EPSG\\&quot;,\\&quot;9122\\&quot;]],AXIS[\\&quot;Latitude\\&quot;,NORTH],AXIS[\\&quot;Longitude\\&quot;,EAST],AUTHORITY[\\&quot;EPSG\\&quot;,\\&quot;4326\\&quot;]]&quot;)</span></span></code></pre></div>`,21)]))}const k=a(e,[["render",p]]);export{c as __pageData,k as default};
