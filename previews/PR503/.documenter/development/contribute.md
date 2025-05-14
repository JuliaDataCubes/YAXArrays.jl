
# Contribute to YAXArrays.jl {#Contribute-to-YAXArrays.jl}

Pull requests and bug reports are always welcome at the [YAXArrays.jl GitHub repository](https://github.com/JuliaDataCubes/YAXArrays.jl).

## Contribute to Documentation {#Contribute-to-Documentation}

Contributing with examples can be done by first creating a new file example [here](https://github.com/JuliaDataCubes/YAXArrays.jl/tree/master/docs/examples/UserGuide)

::: info new file
- `your_new_file.md` at `docs/src/UserGuide/`
  

:::

Once this is done you need to add a new entry [here](https://github.com/JuliaDataCubes/YAXArrays.jl/blob/master/docs/src/.vitepress/config.mts) at the appropriate level.

::: info add entry to docs

Your new entry should look like:
- \{ text: &#39;Your title example&#39;, link: &#39;/UserGuide/your_new_file.md&#39; \}
  

:::

### Build docs locally {#Build-docs-locally}

If you want to take a look at the docs locally before doing a PR follow the next steps:

Install the dependencies in your system, locate yourself at the `docs` level folder, then do

```sh
npm i
```


Then simply go to your `docs` env and activate it, i.e.

```sh
docs> julia
julia> ]
pkg> activate .
```


Next, run the scripts. Generate files and build docs by running:

```sh
include("make.jl")
```


Now go to your `terminal` in the same path `docs>` and run:

```sh
npm run docs:dev
```


This should ouput `http://localhost:5173/YAXArrays.jl/`, copy/paste this into your browser and you are all set.
