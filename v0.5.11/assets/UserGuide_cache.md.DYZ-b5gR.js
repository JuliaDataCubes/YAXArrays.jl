import{_ as a,c as i,a2 as e,o as t}from"./chunks/framework.CbgdtCvC.js";const o=JSON.parse('{"title":"Caching YAXArrays","description":"","frontmatter":{},"headers":[],"relativePath":"UserGuide/cache.md","filePath":"UserGuide/cache.md","lastUpdated":null}'),n={name:"UserGuide/cache.md"};function h(l,s,p,r,c,d){return t(),i("div",null,s[0]||(s[0]=[e(`<h1 id="Caching-YAXArrays" tabindex="-1">Caching YAXArrays <a class="header-anchor" href="#Caching-YAXArrays" aria-label="Permalink to &quot;Caching YAXArrays {#Caching-YAXArrays}&quot;">​</a></h1><p>For some applications like interactive plotting of large datasets it can not be avoided that the same data must be accessed several times. In these cases it can be useful to store recently accessed data in a cache. In YAXArrays this can be easily achieved using the <code>cache</code> function. For example, if we open a large dataset from a remote source and want to keep data in a cache of size 500MB one can use:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> YAXArrays, Zarr</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ds </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> open_dataset</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;path/to/source&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">cachesize </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 500</span><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;"> #MB</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">cache</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(ds,maxsize </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> cachesize)</span></span></code></pre></div><p>The above will wrap every array in the dataset into its own cache, where the 500MB are distributed equally across datasets. Alternatively individual caches can be applied to single <code>YAXArray</code>s</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">yax </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> ds</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">avariable</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">cache</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(yax,maxsize </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 1000</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span></code></pre></div>`,5)]))}const g=a(n,[["render",h]]);export{o as __pageData,g as default};
