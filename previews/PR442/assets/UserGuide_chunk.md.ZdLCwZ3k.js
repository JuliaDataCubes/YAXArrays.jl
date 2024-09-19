import{_ as a,c as i,a2 as n,o as p}from"./chunks/framework.CkDn3w7d.js";const g=JSON.parse('{"title":"Chunk YAXArrays","description":"","frontmatter":{},"headers":[],"relativePath":"UserGuide/chunk.md","filePath":"UserGuide/chunk.md","lastUpdated":null}'),l={name:"UserGuide/chunk.md"};function h(e,s,t,k,r,d){return p(),i("div",null,s[0]||(s[0]=[n(`<h1 id="Chunk-YAXArrays" tabindex="-1">Chunk YAXArrays <a class="header-anchor" href="#Chunk-YAXArrays" aria-label="Permalink to &quot;Chunk YAXArrays {#Chunk-YAXArrays}&quot;">​</a></h1><div class="important custom-block github-alert"><p class="custom-block-title">Thinking about chunking is important when it comes to analyzing your data, because in most situations this will not fit into memory, hence having the fastest read access to it is crucial for your workflows. For example, for geo-spatial data do you want fast access on time or space, or... think about it.</p><p></p></div><p>To determine the chunk size of the array representation on disk, call the <code>setchunks</code> function prior to saving.</p><h2 id="Chunking-YAXArrays" tabindex="-1">Chunking YAXArrays <a class="header-anchor" href="#Chunking-YAXArrays" aria-label="Permalink to &quot;Chunking YAXArrays {#Chunking-YAXArrays}&quot;">​</a></h2><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrays, Zarr</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">a </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">20</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">))</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">a_chunked </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> setchunks</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(a, (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">))</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">a_chunked</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">chunks</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>2×2 DiskArrays.GridChunks{2, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:</span></span>
<span class="line"><span> (1:5, 1:10)   (1:5, 11:20)</span></span>
<span class="line"><span> (6:10, 1:10)  (6:10, 11:20)</span></span></code></pre></div><p>And the saved file is also splitted into Chunks.</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">f </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> tempname</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">()</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">savecube</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(a_chunked, f, backend</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">:zarr</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Cube</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(f)</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">chunks</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>2×2 DiskArrays.GridChunks{2, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:</span></span>
<span class="line"><span> (1:5, 1:10)   (1:5, 11:20)</span></span>
<span class="line"><span> (6:10, 1:10)  (6:10, 11:20)</span></span></code></pre></div><p>Alternatively chunk sizes can be given by dimension name, so the following results in the same chunks:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">a_chunked </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> setchunks</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(a, (Dim_2</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, Dim_1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">))</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">a_chunked</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">chunks</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>2×2 DiskArrays.GridChunks{2, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:</span></span>
<span class="line"><span> (1:5, 1:10)   (1:5, 11:20)</span></span>
<span class="line"><span> (6:10, 1:10)  (6:10, 11:20)</span></span></code></pre></div><h2 id="Chunking-Datasets" tabindex="-1">Chunking Datasets <a class="header-anchor" href="#Chunking-Datasets" aria-label="Permalink to &quot;Chunking Datasets {#Chunking-Datasets}&quot;">​</a></h2><p>Setchunks can also be applied to a <code>Dataset</code>.</p><h3 id="Set-Chunks-by-Axis" tabindex="-1">Set Chunks by Axis <a class="header-anchor" href="#Set-Chunks-by-Axis" aria-label="Permalink to &quot;Set Chunks by Axis {#Set-Chunks-by-Axis}&quot;">​</a></h3><p>Set chunk size for each axis occuring in a <code>Dataset</code>. This will be applied to all variables in the dataset:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrays, Zarr</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ds </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Dataset</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(x </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">20</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)), y </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)), z </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">20</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)))</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">dschunked </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> setchunks</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(ds, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Dict</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;Dim_1&quot;</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;Dim_2&quot;</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;Dim_3&quot;</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">2</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">))</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Cube</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(dschunked)</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">chunks</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>2×2×3 DiskArrays.GridChunks{3, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:</span></span>
<span class="line"><span>[:, :, 1] =</span></span>
<span class="line"><span> (1:5, 1:10, 1:2)   (1:5, 11:20, 1:2)</span></span>
<span class="line"><span> (6:10, 1:10, 1:2)  (6:10, 11:20, 1:2)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>[:, :, 2] =</span></span>
<span class="line"><span> (1:5, 1:10, 3:4)   (1:5, 11:20, 3:4)</span></span>
<span class="line"><span> (6:10, 1:10, 3:4)  (6:10, 11:20, 3:4)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>[:, :, 3] =</span></span>
<span class="line"><span> (1:5, 1:10, 5:5)   (1:5, 11:20, 5:5)</span></span>
<span class="line"><span> (6:10, 1:10, 5:5)  (6:10, 11:20, 5:5)</span></span></code></pre></div><p>Saving...</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">f </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> tempname</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">()</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">savedataset</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(dschunked, path</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">f, driver</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">:zarr</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>YAXArray Dataset</span></span>
<span class="line"><span>Shared Axes: </span></span>
<span class="line"><span>  (↓ Dim_1 Sampled{Int64} Base.OneTo(10) ForwardOrdered Regular Points)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Variables: </span></span>
<span class="line"><span>y</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Variables with additional axes:</span></span>
<span class="line"><span>  Additional Axes: </span></span>
<span class="line"><span>  (↓ Dim_2 Sampled{Int64} Base.OneTo(20) ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Dim_3 Sampled{Int64} Base.OneTo(5) ForwardOrdered Regular Points)</span></span>
<span class="line"><span>  Variables: </span></span>
<span class="line"><span>  z</span></span>
<span class="line"><span></span></span>
<span class="line"><span>  Additional Axes: </span></span>
<span class="line"><span>  (↓ Dim_2 Sampled{Int64} Base.OneTo(20) ForwardOrdered Regular Points)</span></span>
<span class="line"><span>  Variables: </span></span>
<span class="line"><span>  x</span></span></code></pre></div><h3 id="Set-chunking-by-Variable" tabindex="-1">Set chunking by Variable <a class="header-anchor" href="#Set-chunking-by-Variable" aria-label="Permalink to &quot;Set chunking by Variable {#Set-chunking-by-Variable}&quot;">​</a></h3><p>The following will set the chunk size for each Variable separately and results in exactly the same chunking as the example above</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrays, Zarr</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ds </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Dataset</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(x </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">20</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)), y </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)), z </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">20</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)))</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">dschunked </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> setchunks</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(ds,(x </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">), y </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Dict</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;Dim_1&quot;</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">), z </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> (Dim_1 </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, Dim_2 </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, Dim_3 </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 2</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)))</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Cube</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(dschunked)</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">chunks</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>2×2×3 DiskArrays.GridChunks{3, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:</span></span>
<span class="line"><span>[:, :, 1] =</span></span>
<span class="line"><span> (1:5, 1:10, 1:2)   (1:5, 11:20, 1:2)</span></span>
<span class="line"><span> (6:10, 1:10, 1:2)  (6:10, 11:20, 1:2)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>[:, :, 2] =</span></span>
<span class="line"><span> (1:5, 1:10, 3:4)   (1:5, 11:20, 3:4)</span></span>
<span class="line"><span> (6:10, 1:10, 3:4)  (6:10, 11:20, 3:4)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>[:, :, 3] =</span></span>
<span class="line"><span> (1:5, 1:10, 5:5)   (1:5, 11:20, 5:5)</span></span>
<span class="line"><span> (6:10, 1:10, 5:5)  (6:10, 11:20, 5:5)</span></span></code></pre></div><p>saving...</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">f </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> tempname</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">()</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">savedataset</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(dschunked, path</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">f, driver</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">:zarr</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>YAXArray Dataset</span></span>
<span class="line"><span>Shared Axes: </span></span>
<span class="line"><span>  (↓ Dim_1 Sampled{Int64} Base.OneTo(10) ForwardOrdered Regular Points)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Variables: </span></span>
<span class="line"><span>y</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Variables with additional axes:</span></span>
<span class="line"><span>  Additional Axes: </span></span>
<span class="line"><span>  (↓ Dim_2 Sampled{Int64} Base.OneTo(20) ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Dim_3 Sampled{Int64} Base.OneTo(5) ForwardOrdered Regular Points)</span></span>
<span class="line"><span>  Variables: </span></span>
<span class="line"><span>  z</span></span>
<span class="line"><span></span></span>
<span class="line"><span>  Additional Axes: </span></span>
<span class="line"><span>  (↓ Dim_2 Sampled{Int64} Base.OneTo(20) ForwardOrdered Regular Points)</span></span>
<span class="line"><span>  Variables: </span></span>
<span class="line"><span>  x</span></span></code></pre></div><h3 id="Set-chunking-for-all-variables" tabindex="-1">Set chunking for all variables <a class="header-anchor" href="#Set-chunking-for-all-variables" aria-label="Permalink to &quot;Set chunking for all variables {#Set-chunking-for-all-variables}&quot;">​</a></h3><p>The following code snippet only works when all member variables of the dataset have the same shape and sets the output chunks for all arrays.</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrays, Zarr</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ds </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Dataset</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(x </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">20</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)), y </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">20</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)), z </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> YAXArray</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">20</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)))</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">dschunked </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> setchunks</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(ds,(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">5</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">))</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Cube</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(dschunked)</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">chunks</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>2×2×3 DiskArrays.GridChunks{3, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:</span></span>
<span class="line"><span>[:, :, 1] =</span></span>
<span class="line"><span> (1:5, 1:10, 1:1)   (1:5, 11:20, 1:1)</span></span>
<span class="line"><span> (6:10, 1:10, 1:1)  (6:10, 11:20, 1:1)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>[:, :, 2] =</span></span>
<span class="line"><span> (1:5, 1:10, 2:2)   (1:5, 11:20, 2:2)</span></span>
<span class="line"><span> (6:10, 1:10, 2:2)  (6:10, 11:20, 2:2)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>[:, :, 3] =</span></span>
<span class="line"><span> (1:5, 1:10, 3:3)   (1:5, 11:20, 3:3)</span></span>
<span class="line"><span> (6:10, 1:10, 3:3)  (6:10, 11:20, 3:3)</span></span></code></pre></div><p>saving...</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">f </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> tempname</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">()</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">savedataset</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(dschunked, path</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">f, driver</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">:zarr</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span></code></pre></div><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>YAXArray Dataset</span></span>
<span class="line"><span>Shared Axes: </span></span>
<span class="line"><span>  (↓ Dim_1 Sampled{Int64} Base.OneTo(10) ForwardOrdered Regular Points,</span></span>
<span class="line"><span>  → Dim_2 Sampled{Int64} Base.OneTo(20) ForwardOrdered Regular Points)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Variables: </span></span>
<span class="line"><span>x, y, z</span></span></code></pre></div><p>Suggestions on how to improve or add to these examples is welcome.</p>`,36)]))}const c=a(l,[["render",h]]);export{g as __pageData,c as default};
