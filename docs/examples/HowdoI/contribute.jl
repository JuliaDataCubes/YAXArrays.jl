# ## Contribute to Documentation
# Contributing with examples can be done by first creating a new file example
# [here](https://github.com/JuliaDataCubes/YAXArrays.jl/tree/master/docs/examples/UserGuide)

# ::: info new file
#
#     - `your_new_file.jl` at `docs/examples/UserGuide/`
#
# :::

# Once this is done you need to add a new entry [here](https://github.com/JuliaDataCubes/YAXArrays.jl/blob/master/docs/mkdocs.yml)
# at the bottom and the appropriate level.

# ::: info add entry to docs
#     Your new entry should look like:
#     - `"Your title example" : "examples/generated/UserGuide/your_new_file.md"`

# ## Build docs locally
# If you want to take a look at the docs locally before doing a PR
# follow the next steps:

# ::: warning build docs locally
#     Install the following dependencies in your system via pip, i.e.
#     - 
#     - 
#     -
# 
# :::

# Then simply go to your `docs` env and activate it, i.e.

# ```
# docs> julia
#
# ```

# `julia> ]`

# `(docs) pkg> activate .`

# Next, run the scripts:

# ::: info Julia env: docs
# 
#     Generate files and build docs by running:
#     - `include("genfiles.jl")`
#     - `include("make.jl")`
#
# :::

# Now go to your `terminal` in the same path `docs>` and run:

# `npm run docs:dev`

# This should ouput `http://localhost:5173`, copy/paste this into your
# browser and you are all set.