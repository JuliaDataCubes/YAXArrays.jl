import{_ as a,c as n,a2 as i,o as p}from"./chunks/framework.eQVMtpgY.js";const c=JSON.parse('{"title":"Convert YAXArrays","description":"","frontmatter":{},"headers":[],"relativePath":"UserGuide/convert.md","filePath":"UserGuide/convert.md","lastUpdated":null}'),e={name:"UserGuide/convert.md"};function l(t,s,r,h,d,k){return p(),n("div",null,s[0]||(s[0]=[i(`<h1 id="Convert-YAXArrays" tabindex="-1">Convert YAXArrays <a class="header-anchor" href="#Convert-YAXArrays" aria-label="Permalink to &quot;Convert YAXArrays {#Convert-YAXArrays}&quot;">​</a></h1><p>This section describes how to convert variables from types of other Julia packages into YAXArrays and vice versa.</p><div class="warning custom-block"><p class="custom-block-title">WARNING</p><p>YAXArrays is designed to work with large datasets that are way larger than the memory. However, most types are designed to work in memory. Those conversions are only possible if the entire dataset fits into memory. In addition, metadata might be lost during conversion.</p></div><h2 id="Convert-Base.Array" tabindex="-1">Convert <code>Base.Array</code> <a class="header-anchor" href="#Convert-Base.Array" aria-label="Permalink to &quot;Convert \`Base.Array\` {#Convert-Base.Array}&quot;">​</a></h2><p>Convert <code>Base.Array</code> to <code>YAXArray</code>:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrays</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">m </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">a </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(m)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>╭──────────────────────────╮</span></span>
<span class="line"><span>│ 5×10 YAXArray{Float64,2} │</span></span>
<span class="line"><span>├──────────────────────────┴──────────────────────────────────── dims ┐</span></span>
<span class="line"><span>  ↓ Dim_1 Sampled{Int64} Base.OneTo(5) ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Dim_2 Sampled{Int64} Base.OneTo(10) ForwardOrdered Regular Points</span></span>
<span class="line"><span>├─────────────────────────────────────────────────────────── metadata ┤</span></span>
<span class="line"><span>  Dict{String, Any}()</span></span>
<span class="line"><span>├────────────────────────────────────────────────────────── file size ┤ </span></span>
<span class="line"><span>  file size: 400.0 bytes</span></span>
<span class="line"><span>└─────────────────────────────────────────────────────────────────────┘</span></span></code></pre></div><p>Convert <code>YAXArray</code> to <code>Base.Array</code>:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">m2 </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> collect</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(a</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">data)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>5×10 Matrix{Float64}:</span></span>
<span class="line"><span> 0.484561  0.803933  0.189091  0.395566    …  0.962957  0.149532  0.26951</span></span>
<span class="line"><span> 0.126368  0.387986  0.731763  0.693869       0.162052  0.245398  0.778103</span></span>
<span class="line"><span> 0.270034  0.748773  0.450236  0.853685       0.958344  0.390335  0.0344221</span></span>
<span class="line"><span> 0.227521  0.760578  0.416932  0.00610615     0.387394  0.961764  0.197056</span></span>
<span class="line"><span> 0.640734  0.16954   0.845502  0.896575       0.105085  0.750315  0.264853</span></span></code></pre></div><h2 id="Convert-Raster" tabindex="-1">Convert <code>Raster</code> <a class="header-anchor" href="#Convert-Raster" aria-label="Permalink to &quot;Convert \`Raster\` {#Convert-Raster}&quot;">​</a></h2><p>A <code>Raster</code> as defined in <a href="https://rafaqz.github.io/Rasters.jl/stable/" target="_blank" rel="noreferrer">Rasters.jl</a> has a same supertype of a <code>YAXArray</code>, i.e. <code>AbstractDimArray</code>, allowing easy conversion between those types:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Rasters</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">lon, lat </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> X</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">25</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">30</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">), </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Y</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">25</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">30</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">time </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Ti</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">2000</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">2024</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ras </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Raster</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(lon, lat, time))</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">a </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">dims</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(ras), ras</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">data)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>╭────────────────────────────╮</span></span>
<span class="line"><span>│ 6×6×25 YAXArray{Float64,3} │</span></span>
<span class="line"><span>├────────────────────────────┴────────────────────────── dims ┐</span></span>
<span class="line"><span>  ↓ X  Sampled{Int64} 25:1:30 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Y  Sampled{Int64} 25:1:30 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  ↗ Ti Sampled{Int64} 2000:2024 ForwardOrdered Regular Points</span></span>
<span class="line"><span>├─────────────────────────────────────────────────── metadata ┤</span></span>
<span class="line"><span>  Dict{String, Any}()</span></span>
<span class="line"><span>├────────────────────────────────────────────────── file size ┤ </span></span>
<span class="line"><span>  file size: 7.03 KB</span></span>
<span class="line"><span>└─────────────────────────────────────────────────────────────┘</span></span></code></pre></div><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ras2 </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Raster</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(a)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>╭──────────────────────────╮</span></span>
<span class="line"><span>│ 6×6×25 Raster{Float64,3} │</span></span>
<span class="line"><span>├──────────────────────────┴──────────────────────────── dims ┐</span></span>
<span class="line"><span>  ↓ X  Sampled{Int64} 25:1:30 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Y  Sampled{Int64} 25:1:30 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  ↗ Ti Sampled{Int64} 2000:2024 ForwardOrdered Regular Points</span></span>
<span class="line"><span>├─────────────────────────────────────────────────── metadata ┤</span></span>
<span class="line"><span>  Dict{String, Any}()</span></span>
<span class="line"><span>├───────────────────────────────────────────────────── raster ┤</span></span>
<span class="line"><span>  extent: Extent(X = (25, 30), Y = (25, 30), Ti = (2000, 2024))</span></span>
<span class="line"><span></span></span>
<span class="line"><span>└─────────────────────────────────────────────────────────────┘</span></span>
<span class="line"><span>[:, :, 1]</span></span>
<span class="line"><span>  ↓ →  25         26         27         28         29         30</span></span>
<span class="line"><span> 25     0.277672   0.19274    0.968417   0.321261   0.97809    0.475251</span></span>
<span class="line"><span> 26     0.197907   0.276032   0.797333   0.176799   0.217855   0.829992</span></span>
<span class="line"><span> 27     0.752389   0.896784   0.497162   0.110372   0.558261   0.883881</span></span>
<span class="line"><span> 28     0.970757   0.826902   0.77086    0.377284   0.355369   0.235685</span></span>
<span class="line"><span> 29     0.18551    0.74541    0.699567   0.321023   0.771126   0.789024</span></span>
<span class="line"><span> 30     0.288074   0.531563   0.283969   0.292206   0.418466   0.673577</span></span></code></pre></div><h2 id="Convert-DimArray" tabindex="-1">Convert <code>DimArray</code> <a class="header-anchor" href="#Convert-DimArray" aria-label="Permalink to &quot;Convert \`DimArray\` {#Convert-DimArray}&quot;">​</a></h2><p>A <code>DimArray</code> as defined in <a href="https://rafaqz.github.io/DimensionalData.jl/dev/dimarrays" target="_blank" rel="noreferrer">DimensionalData.jl</a> has a same supertype of a <code>YAXArray</code>, i.e. <code>AbstractDimArray</code>, allowing easy conversion between those types.</p><p>Convert <code>DimArray</code> to <code>YAXArray</code>:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> DimensionalData</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrayBase</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">dim_arr </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">X</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">), </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Y</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10.0</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">15.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">), metadata </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Dict{String, Any}</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">())</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">a </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> yaxconvert</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(YAXArray, dim_arr)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>╭─────────────────────────╮</span></span>
<span class="line"><span>│ 5×6 YAXArray{Float64,2} │</span></span>
<span class="line"><span>├─────────────────────────┴────────────────────────────────── dims ┐</span></span>
<span class="line"><span>  ↓ X Sampled{Int64} 1:5 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Y Sampled{Float64} 10.0:1.0:15.0 ForwardOrdered Regular Points</span></span>
<span class="line"><span>├──────────────────────────────────────────────────────── metadata ┤</span></span>
<span class="line"><span>  Dict{String, Any}()</span></span>
<span class="line"><span>├─────────────────────────────────────────────────────── file size ┤ </span></span>
<span class="line"><span>  file size: 240.0 bytes</span></span>
<span class="line"><span>└──────────────────────────────────────────────────────────────────┘</span></span></code></pre></div><p>Convert <code>YAXArray</code> to <code>DimArray</code>:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">dim_arr2 </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> yaxconvert</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(DimArray, a)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>╭─────────────────────────╮</span></span>
<span class="line"><span>│ 5×6 DimArray{Float64,2} │</span></span>
<span class="line"><span>├─────────────────────────┴────────────────────────────────── dims ┐</span></span>
<span class="line"><span>  ↓ X Sampled{Int64} 1:5 ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Y Sampled{Float64} 10.0:1.0:15.0 ForwardOrdered Regular Points</span></span>
<span class="line"><span>├──────────────────────────────────────────────────────── metadata ┤</span></span>
<span class="line"><span>  Dict{String, Any}()</span></span>
<span class="line"><span>└──────────────────────────────────────────────────────────────────┘</span></span>
<span class="line"><span> ↓ →  10.0       11.0       12.0        13.0       14.0       15.0</span></span>
<span class="line"><span> 1     0.264965   0.466014   0.948295    0.728345   0.720552   0.712142</span></span>
<span class="line"><span> 2     0.205441   0.747801   0.0230207   0.569377   0.196434   0.590044</span></span>
<span class="line"><span> 3     0.77522    0.434027   0.586515    0.402482   0.700836   0.55636</span></span>
<span class="line"><span> 4     0.282311   0.926022   0.565839    0.232697   0.513538   0.646746</span></span>
<span class="line"><span> 5     0.865716   0.246708   0.974797    0.690601   0.497239   0.619666</span></span></code></pre></div><div class="info custom-block"><p class="custom-block-title">INFO</p><p>At the moment there is no support to save a DimArray directly into disk as a <code>NetCDF</code> or a <code>Zarr</code> file.</p></div>`,25)]))}const g=a(e,[["render",l]]);export{c as __pageData,g as default};