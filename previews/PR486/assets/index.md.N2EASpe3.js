import{_ as s,c as a,a2 as t,o as e}from"./chunks/framework.piKCME0r.js";const g=JSON.parse(`{"title":"","description":"","frontmatter":{"layout":"home","hero":{"name":"YAXArrays.jl","text":"Yet another xarray-like Julia package","tagline":"A package for operating on out-of-core labeled arrays, based on stores like NetCDF, Zarr or GDAL.","image":{"src":"/logo.png","alt":"VitePress"},"actions":[{"theme":"brand","text":"Get Started","link":"/get_started"},{"theme":"alt","text":"View on Github","link":"https://github.com/JuliaDataCubes/YAXArrays.jl"},{"theme":"alt","text":"API reference","link":"/api"}]},"features":[{"title":"Flexible I/O capabilities","details":"Open and operate on <font color=\\"#D27D2D\\">NetCDF</font> and <font color=\\"#D27D2D\\">Zarr</font> datasets directly. Or bring in data from other sources with ArchGDAL.jl, GRIBDatasets.jl, GeoJSON.jl, HDF5.jl, Shapefile.jl, GeoParquet.jl, etc.","link":"/UserGuide/read"},{"title":"Interoperability","details":"Well integrated with Julia's ecosystem, i.e., distributed operations are native. And plotting with <font color=\\"#D27D2D\\">Makie.jl</font> is well supported.","link":"/tutorials/plottingmaps"},{"title":"Named dimensions and GroupBy(in memory)","details":"Apply operations over named dimensions, select values by labels and integers as well as efficient split-apply-combine operations with <font color=\\"#D27D2D\\">groupby</font> via DimensionalData.jl.","link":"/UserGuide/group"},{"title":"Efficiency","details":"Efficient <font color=\\"#D27D2D\\">mapslices(x) </font> and <font color=\\"#D27D2D\\">mapCube</font> operations on huge multiple arrays, optimized for high-latency data access (object storage, compressed datasets).","link":"/UserGuide/compute"}]},"headers":[],"relativePath":"index.md","filePath":"index.md","lastUpdated":null}`),l={name:"index.md"};function n(p,i,h,r,k,o){return e(),a("div",null,i[0]||(i[0]=[t(`<h2 id="How-to-Install-YAXArrays.jl?" tabindex="-1">How to Install YAXArrays.jl? <a class="header-anchor" href="#How-to-Install-YAXArrays.jl?" aria-label="Permalink to &quot;How to Install YAXArrays.jl? {#How-to-Install-YAXArrays.jl?}&quot;">​</a></h2><p>Since <code>YAXArrays.jl</code> is registered in the Julia General registry, you can simply run the following command in the Julia REPL:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Pkg</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Pkg</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">add</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;YAXArrays.jl&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;"># or</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> ] </span><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;"># &#39;]&#39; should be pressed</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">pkg</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> add YAXArrays</span></span></code></pre></div><p>If you want to use the latest unreleased version, you can run the following command:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">pkg</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> add YAXArrays</span><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;">#master</span></span></code></pre></div><h2 id="Want-interoperability?" tabindex="-1">Want interoperability? <a class="header-anchor" href="#Want-interoperability?" aria-label="Permalink to &quot;Want interoperability? {#Want-interoperability?}&quot;">​</a></h2><p>Install the following package(s) for:</p><div class="vp-code-group vp-adaptive-theme"><div class="tabs"><input type="radio" name="group-6Kgtz" id="tab-jRYFgQL" checked><label data-title=" .tif " for="tab-jRYFgQL"> .tif </label><input type="radio" name="group-6Kgtz" id="tab-kZ9I3vC"><label data-title=" .netcdf " for="tab-kZ9I3vC"> .netcdf </label><input type="radio" name="group-6Kgtz" id="tab-6Ev5hYi"><label data-title=" .zarr " for="tab-6Ev5hYi"> .zarr </label><input type="radio" name="group-6Kgtz" id="tab-OhZL6ev"><label data-title=" plotting " for="tab-OhZL6ev"> plotting </label></div><div class="blocks"><div class="language-julia vp-adaptive-theme active"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Pkg</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">Pkg</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">add</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;ArchGDAL&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span></code></pre></div><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Pkg</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">Pkg</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">add</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;NetCDF&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span></code></pre></div><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Pkg</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">Pkg</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">add</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;Zarr&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span></code></pre></div><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Pkg</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">Pkg</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">add</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">([</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;GLMakie&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;GeoMakie&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;AlgebraOfGraphics&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;DimensionalData&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">])</span></span></code></pre></div></div></div>`,8)]))}const E=s(l,[["render",n]]);export{g as __pageData,E as default};
