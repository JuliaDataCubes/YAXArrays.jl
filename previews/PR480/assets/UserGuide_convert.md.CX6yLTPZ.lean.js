import{_ as a,c as i,a2 as n,o as e}from"./chunks/framework.COai9KWC.js";const c=JSON.parse('{"title":"Convert YAXArrays","description":"","frontmatter":{},"headers":[],"relativePath":"UserGuide/convert.md","filePath":"UserGuide/convert.md","lastUpdated":null}'),t={name:"UserGuide/convert.md"};function p(l,s,h,r,k,d){return e(),i("div",null,s[0]||(s[0]=[n(`<h1 id="Convert-YAXArrays" tabindex="-1">Convert YAXArrays <a class="header-anchor" href="#Convert-YAXArrays" aria-label="Permalink to &quot;Convert YAXArrays {#Convert-YAXArrays}&quot;">​</a></h1><p>This section describes how to convert variables from types of other Julia packages into YAXArrays and vice versa.</p><div class="warning custom-block"><p class="custom-block-title">WARNING</p><p>YAXArrays is designed to work with large datasets that are way larger than the memory. However, most types are designed to work in memory. Those conversions are only possible if the entire dataset fits into memory. In addition, metadata might be lost during conversion.</p></div><h2 id="Convert-Base.Array" tabindex="-1">Convert <code>Base.Array</code> <a class="header-anchor" href="#Convert-Base.Array" aria-label="Permalink to &quot;Convert \`Base.Array\` {#Convert-Base.Array}&quot;">​</a></h2><p>Convert <code>Base.Array</code> to <code>YAXArray</code>:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrays</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">m </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">a </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(m)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>┌ 5×10 YAXArray{Float64, 2} ┐</span></span>
<span class="line"><span>├───────────────────────────┴─────────────────────────────────── dims ┐</span></span>
<span class="line"><span>  ↓ Dim_1 Sampled{Int64} Base.OneTo(5) ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Dim_2 Sampled{Int64} Base.OneTo(10) ForwardOrdered Regular Points</span></span>
<span class="line"><span>├─────────────────────────────────────────────────────────── metadata ┤</span></span>
<span class="line"><span>  Dict{String, Any}()</span></span>
<span class="line"><span>├─────────────────────────────────────────────────── loaded in memory ┤</span></span>
<span class="line"><span>  data size: 400.0 bytes</span></span>
<span class="line"><span>└─────────────────────────────────────────────────────────────────────┘</span></span></code></pre></div><p>Convert <code>YAXArray</code> to <code>Base.Array</code>:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">m2 </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> collect</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(a</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">data)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>5×10 Matrix{Float64}:</span></span>
<span class="line"><span> 0.265797  0.789891  0.611084  0.845983  …  0.918555  0.870826   0.348362</span></span>
<span class="line"><span> 0.665723  0.241882  0.426519  0.581312     0.949935  0.0214057  0.152534</span></span>
<span class="line"><span> 0.83556   0.456765  0.197238  0.645758     0.74732   0.652339   0.935631</span></span>
<span class="line"><span> 0.337926  0.151146  0.673373  0.169284     0.75269   0.166212   0.0358348</span></span>
<span class="line"><span> 0.594514  0.364288  0.78467   0.830391     0.128204  0.174934   0.0210077</span></span></code></pre></div><h2 id="Convert-Raster" tabindex="-1">Convert <code>Raster</code> <a class="header-anchor" href="#Convert-Raster" aria-label="Permalink to &quot;Convert \`Raster\` {#Convert-Raster}&quot;">​</a></h2><p>A <code>Raster</code> as defined in <a href="https://rafaqz.github.io/Rasters.jl/stable/" target="_blank" rel="noreferrer">Rasters.jl</a> has a same supertype of a <code>YAXArray</code>, i.e. <code>AbstractDimArray</code>, allowing easy conversion between those types:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Rasters</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">lon, lat </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> X</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">25</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">30</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">), </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Y</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">25</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">30</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">time </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Ti</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">2000</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">2024</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ras </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Raster</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(lon, lat, time))</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">a </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">dims</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(ras), ras</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">data)</span></span></code></pre></div><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ras2 </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Raster</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(a)</span></span></code></pre></div><h2 id="Convert-DimArray" tabindex="-1">Convert <code>DimArray</code> <a class="header-anchor" href="#Convert-DimArray" aria-label="Permalink to &quot;Convert \`DimArray\` {#Convert-DimArray}&quot;">​</a></h2><p>A <code>DimArray</code> as defined in <a href="https://rafaqz.github.io/DimensionalData.jl/dev/dimarrays" target="_blank" rel="noreferrer">DimensionalData.jl</a> has a same supertype of a <code>YAXArray</code>, i.e. <code>AbstractDimArray</code>, allowing easy conversion between those types.</p><p>Convert <code>DimArray</code> to <code>YAXArray</code>:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> DimensionalData</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrayBase</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">dim_arr </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">X</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">), </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Y</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10.0</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">15.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">), metadata </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Dict{String, Any}</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">())</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">a </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> yaxconvert</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(YAXArray, dim_arr)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>┌ 5×6 YAXArray{Float64, 2} ┐</span></span>
<span class="line"><span>├──────────────────────────┴───────────────────────────────── dims ┐</span></span>
<span class="line"><span>  ↓ X Sampled{Int64} 1:5 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Y Sampled{Float64} 10.0:1.0:15.0 ForwardOrdered Regular Points</span></span>
<span class="line"><span>├──────────────────────────────────────────────────────── metadata ┤</span></span>
<span class="line"><span>  Dict{String, Any}()</span></span>
<span class="line"><span>├──────────────────────────────────────────────── loaded in memory ┤</span></span>
<span class="line"><span>  data size: 240.0 bytes</span></span>
<span class="line"><span>└──────────────────────────────────────────────────────────────────┘</span></span></code></pre></div><p>Convert <code>YAXArray</code> to <code>DimArray</code>:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">dim_arr2 </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> yaxconvert</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(DimArray, a)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>┌ 5×6 DimArray{Float64, 2} ┐</span></span>
<span class="line"><span>├──────────────────────────┴───────────────────────────────── dims ┐</span></span>
<span class="line"><span>  ↓ X Sampled{Int64} 1:5 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Y Sampled{Float64} 10.0:1.0:15.0 ForwardOrdered Regular Points</span></span>
<span class="line"><span>├──────────────────────────────────────────────────────── metadata ┤</span></span>
<span class="line"><span>  Dict{String, Any}()</span></span>
<span class="line"><span>└──────────────────────────────────────────────────────────────────┘</span></span>
<span class="line"><span> ↓ →  10.0       11.0        12.0        13.0       14.0       15.0</span></span>
<span class="line"><span> 1     0.862644   0.872575    0.0620649   0.193109   0.475725   0.953391</span></span>
<span class="line"><span> 2     0.203714   0.770949    0.731779    0.71314    0.687891   0.435994</span></span>
<span class="line"><span> 3     0.492817   0.718667    0.0702532   0.926096   0.225542   0.100622</span></span>
<span class="line"><span> 4     0.268675   0.0566881   0.916686    0.973332   0.744521   0.052264</span></span>
<span class="line"><span> 5     0.540514   0.215973    0.617023    0.796375   0.13205    0.366625</span></span></code></pre></div><div class="info custom-block"><p class="custom-block-title">INFO</p><p>At the moment there is no support to save a DimArray directly into disk as a <code>NetCDF</code> or a <code>Zarr</code> file.</p></div>`,23)]))}const g=a(t,[["render",p]]);export{c as __pageData,g as default};
