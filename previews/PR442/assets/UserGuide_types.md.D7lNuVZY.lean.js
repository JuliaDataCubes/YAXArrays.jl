import{_ as a,c as t,a2 as r,o as s}from"./chunks/framework.CkDn3w7d.js";const u=JSON.parse('{"title":"Types","description":"","frontmatter":{},"headers":[],"relativePath":"UserGuide/types.md","filePath":"UserGuide/types.md","lastUpdated":null}'),o={name:"UserGuide/types.md"};function n(i,e,d,l,c,h){return s(),t("div",null,e[0]||(e[0]=[r('<h1 id="types" tabindex="-1">Types <a class="header-anchor" href="#types" aria-label="Permalink to &quot;Types&quot;">​</a></h1><p>This section describes the data structures used to work with n-dimensional arrays in YAXArrays.</p><h2 id="yaxarray" tabindex="-1">YAXArray <a class="header-anchor" href="#yaxarray" aria-label="Permalink to &quot;YAXArray&quot;">​</a></h2><p>An <code>Array</code> stores a sequence of ordered elements of the same type usually across multiple dimensions or axes. For example, one can measure temperature across all time points of the time dimension or brightness values of a picture across X and Y dimensions. A one dimensional array is called <code>Vector</code> and a two dimensional array is called a <code>Matrix</code>. In many Machine Learning libraries, arrays are also called tensors. Arrays are designed to store dense spatial-temporal data stored in a grid, whereas a collection of sparse points is usually stored in data frames or relational databases.</p><p>A <code>DimArray</code> as defined by <a href="https://rafaqz.github.io/DimensionalData.jl/dev/dimarrays" target="_blank" rel="noreferrer">DimensionalData.jl</a> adds names to the dimensions and their axes ticks for a given <code>Array</code>. These names can be used to access the data, e.g., by date instead of just by integer position.</p><p>A <code>YAXArray</code> is a subtype of a <code>AbstractDimArray</code> and adds functions to load and process the named arrays. For example, it can also handle very large arrays stored on disk that are too big to fit in memory. In addition, it provides functions for parallel computation.</p><h2 id="dataset" tabindex="-1">Dataset <a class="header-anchor" href="#dataset" aria-label="Permalink to &quot;Dataset&quot;">​</a></h2><p>A <code>Dataset</code> is an ordered dictionary of <code>YAXArrays</code> that usually share dimensions. For example, it can bundle arrays storing temperature and precipitation that are measured at the same time points and the same locations. One also can store a picture in a Dataset with three arrays containing brightness values for red green and blue, respectively. Internally, those arrays are still separated allowing to chose different element types for each array. Analog to the (NetCDF Data Model)[<a href="https://docs.unidata.ucar.edu/netcdf-c/current/netcdf_data_model.html" target="_blank" rel="noreferrer">https://docs.unidata.ucar.edu/netcdf-c/current/netcdf_data_model.html</a>], a Dataset usually represents variables belonging to the same group.</p><h2 id="(Data)-Cube" tabindex="-1">(Data) Cube <a class="header-anchor" href="#(Data)-Cube" aria-label="Permalink to &quot;(Data) Cube {#(Data)-Cube}&quot;">​</a></h2><p>A (Data) Cube is just a <code>YAXArray</code> in which arrays from a dataset are combined together by introducing a new dimension containing labels of which array the corresponding element came from. Unlike a <code>Dataset</code>, all arrays must have the same element type to be converted into a cube. This data structure is useful when we want to use all variables at once. For example, the arrays temperature and precipitation which are measured at the same locations and dates can be combined into a single cube. A more formal definition of Data Cubes are given in <a href="https://doi.org/10.5194/esd-11-201-2020" target="_blank" rel="noreferrer">Mahecha et al. 2020</a></p><h2 id="dimension" tabindex="-1">Dimension <a class="header-anchor" href="#dimension" aria-label="Permalink to &quot;Dimension&quot;">​</a></h2><p>A <code>Dimension</code> or axis as defined by <a href="https://rafaqz.github.io/DimensionalData.jl/dev/dimensions" target="_blank" rel="noreferrer">DimensionalData.jl</a> adds tick labels, e.g., to each row or column of an array. It&#39;s name is used to access particular subsets of that array.</p>',12)]))}const p=a(o,[["render",n]]);export{u as __pageData,p as default};
