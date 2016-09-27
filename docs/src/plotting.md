# Plotting

```@meta
CurrentModule = CABLAB.Plot
```

## Plot geographical maps

```@docs
plotMAP
```

## Other plots

```@docs
plotXY
```

## Examples

```@eval
using Patchwork
using Documenter
Documenter.Documents.RawHTML("<script>$(Patchwork.js_runtime())</script>")
```

```@setup 1
using Vega
using Documenter
```


```@eval
using Vega
using Documenter
a=lineplot(x=1:10,y=1:10);
b=IOBuffer()
writemime(b,MIME"text/html"(),a)
Documenter.Documents.RawHTML(bytestring(b.data))
nothing
```
