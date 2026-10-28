# Eunoia <a href="https://jolars.github.io/Eunoia.jl/"><img src='docs/src/assets/logo.svg' align="right" height="139" /></a>

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://jolars.github.io/Eunoia.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://jolars.github.io/Eunoia.jl/dev)
[![Build
Status](https://github.com/jolars/Eunoia.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jolars/Eunoia.jl/actions/workflows/CI.yml?query=branch%3Amain)

Area-proportional Euler and Venn diagrams for Julia.

Eunoia fits and draws area-proportional **Euler and Venn diagrams**: it places
circles, ellipses, squares, or rectangles so that the areas of their overlaps
match a set of input quantities as closely as possible.

## Installation

Install Eunoia and a [Makie](https://makie.org/) backend with the Julia package
manager. Here we use CairoMakie to draw the diagrams:

```julia
using Pkg
Pkg.add(["Eunoia", "CairoMakie"])
```

## Getting started

Fit a diagram with `euler`, then draw it with `eunoiaplot`. By default, each
input gives the size of a separate region. In this example, A alone has area 5,
B alone has area 3, and their overlap has area 1.5:

```julia
using Eunoia, CairoMakie

fit = euler(Dict("A" => 5, "B" => 3, "A&B" => 1.5))
eunoiaplot(fit; quantities = true)
```

Inspect `fit` to compare the requested and fitted quantities. You can also
access `fit.shapes`, `fit.fitted_values`, `fit.residuals`, and `fit.loss`.

Customize the plot with colors, a legend, or labels outside the sets:

```julia
eunoiaplot(
    fit;
    colors = Dict("A" => :steelblue, "B" => :orange),
    quantities = true,
    legend = true,
)
eunoiaplot(fit; set_label_placement = true)
```

You can supply set members instead of region sizes. Eunoia counts the members
and their overlaps for you:

```julia
fit = euler(Dict("A" => ["x", "y", "z"], "B" => ["y", "z", "w"]))
eunoiaplot(fit; quantities = true)
```

For a Venn diagram that shows every possible intersection, use `venn`:

```julia
eunoiaplot(venn(["A", "B", "C"]))
```

Common fitting options include:

- `shape`: `"circle"` (default), `"ellipse"`, `"square"`, `"rectangle"`, or
  `"rotated_rectangle"`.
- `input_type`: `"exclusive"` (default) for separate regions, or `"inclusive"`
  when each supplied quantity includes its intersections.
- `complement`: the area outside every set, shown within a surrounding box.
- `seed`: a seed for reproducible fitting.

To draw into an existing Makie axis, use `eunoiaplot!(ax, fit)`. GLMakie and
WGLMakie are also supported in place of CairoMakie.

See the [gallery](https://jolars.github.io/Eunoia.jl/stable/gallery/) for more
examples, including custom fills, member labels, and circular marks representing
counts. The [API reference](https://jolars.github.io/Eunoia.jl/stable/api/)
describes the full set of fitting and plotting options.

## Ecosystem

This package is the Julia member of the [Eunoia](https://eunoia.bz) family.
Related packages include:

  | Project                                            | Language                  | Distribution                                        |
  | -------------------------------------------------- | ------------------------- | --------------------------------------------------- |
  | [Eunoia](https://github.com/jolars/eunoia)         | Rust                      | [crates.io](https://crates.io/crates/eunoia)        |
  | [@jolars/eunoia](https://github.com/jolars/eunoia) | JavaScript and TypeScript | [npm](https://www.npmjs.com/package/@jolars/eunoia) |
  | [Eunoia](https://github.com/jolars/eunoia-py)      | Python                    | [PyPI](https://pypi.org/project/eunoia/)            |
  | [eulerr](https://github.com/jolars/eulerr)         | R                         | [CRAN](https://cran.r-project.org/package=eulerr)   |

Documentation for the whole family lives at
[eunoia.bz/docs/](https://eunoia.bz/docs/).

## Contributing

When writing commit messages, please use the [conventional commits
format](https://www.conventionalcommits.org/en/v1.0.0/).

## Versioning

Eunoia uses [semantic versioning](https://semver.org).
