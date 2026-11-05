# Eunoia

Area-proportional **Euler and Venn diagrams** for Julia.

Eunoia fits and draws diagrams in which the areas of overlapping shapes
(circles, ellipses, squares, rectangles, or rotated rectangles) are made to
match a set of input quantities as closely as possible. It is the Julia binding
for
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

## Citation

If you use Eunoia.jl in your research, please cite the paper:

> Larsson, J., & Lee, N. M. (2026). *Eunoia: Area-Proportional Euler and Venn
> Diagrams in Rust, Julia, Python, R, and JavaScript* (arXiv:2611.02198). arXiv.
> <https://doi.org/10.48550/arXiv.2611.02198>

```bibtex
@misc{larsson2026f,
  title         = {Eunoia: {{Area}}-Proportional {{Euler}} and {{Venn}} Diagrams in {{Rust}}, {{Julia}}, {{Python}}, {{R}}, and {{JavaScript}}},
  shorttitle    = {Eunoia},
  author        = {Larsson, Johan and Lee, Nicole M.},
  year          = {2026},
  month         = nov,
  number        = {arXiv:2611.02198},
  eprint        = {2611.02198},
  primaryclass  = {stat.CO},
  publisher     = {arXiv},
  doi           = {10.48550/arXiv.2611.02198},
  archiveprefix = {arXiv}
}
```

```@raw html
<details>
<summary>BibLaTeX</summary>
```

```bibtex
@online{larsson2026f,
  title       = {Eunoia: {{Area}}-Proportional {{Euler}} and {{Venn}} Diagrams in {{Rust}}, {{Julia}}, {{Python}}, {{R}}, and {{JavaScript}}},
  shorttitle  = {Eunoia},
  author      = {Larsson, Johan and Lee, Nicole M.},
  date        = {2026-11-01},
  eprint      = {2611.02198},
  eprinttype  = {arXiv},
  eprintclass = {stat.CO},
  doi         = {10.48550/arXiv.2611.02198},
  pubstate    = {prepublished}
}
```

```@raw html
</details>
```

[CITATION.cff](https://github.com/jolars/Eunoia.jl/blob/main/CITATION.cff) contains the software metadata and preferred paper
citation. The [Eunoia citation page](https://eunoia.bz/cite/) renders the paper
in APA, BibTeX, BibLaTeX, and other formats.
