# Eunoia

Area-proportional **Euler and Venn diagrams** for Julia.

Eunoia fits and draws diagrams in which the areas of overlapping shapes
(circles, ellipses, squares, or rectangles) are made to match a set of input
quantities as closely as possible. It is the Julia binding for
[eunoia](https://github.com/jolars/eunoia), a Rust library, and a sister
package to the R ([eulerr](https://github.com/jolars/eulerr)) and Python
([eunoia-py](https://github.com/jolars/eunoia-py)) bindings.

The fitting engine ships as a native library reached through a small C ABI; its
binaries are delivered as a lazily-downloaded Julia artifact, so installing the
package needs no Rust toolchain.

## Installation

Eunoia is registered in the General registry, so install it with the Julia
package manager:

```julia
using Pkg
Pkg.add("Eunoia")
```

## Quick start

```julia
using Eunoia

# Euler diagram from exclusive areas
fit = euler(Dict("A" => 5, "B" => 3, "A&B" => 1.5))

# Canonical Venn diagram with ellipses
venn(["A", "B", "C"]; shape = "ellipse")
```

`euler` returns an `EulerFit` and `venn` a `VennFit`, both carrying the fitted
shapes, original/fitted values, per-region residuals and `region_error`, the
overall `loss`, and (for complement fits) a `container`. See the [API
Reference](@ref) for the full surface.

## Plotting

Rendering lives in a [Makie](https://docs.makie.org) package extension that
loads automatically once a backend is imported:

```@example
using Eunoia, CairoMakie
CairoMakie.activate!(type = "png") # hide

fit = euler(Dict("A" => 5, "B" => 3, "A&B" => 1.5))
eunoiaplot(fit; quantities = true, legend = true)
```

See the [gallery](@ref "A gallery of Euler and Venn diagrams") for a tour of the
plotting options.
