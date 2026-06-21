# Eunoia <a href="https://jolars.github.io/Eunoia.jl/"><img src='docs/src/assets/logo.svg' align="right" height="139" /></a>

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://jolars.github.io/Eunoia.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://jolars.github.io/Eunoia.jl/dev)
[![Build
Status](https://github.com/jolars/Eunoia.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jolars/Eunoia.jl/actions/workflows/CI.yml?query=branch%3Amain)

Area-Proportional Euler and Venn Diagrams.

Eunoia fits and draws area-proportional **Euler and Venn diagrams**: it places
circles, ellipses, squares, or rectangles so that the areas of their overlaps
match a set of input quantities as closely as possible. It is the Julia binding
for [eunoia](https://github.com/jolars/eunoia), a Rust library (itself a
ground-up rewrite of the R package [eulerr](https://github.com/jolars/eulerr)),
and is a sister package to the Python binding
[eunoia-py](https://github.com/jolars/eunoia-py).

The fitting engine is the native `eunoia-capi` library, reached through a small
JSON-in/JSON-out C ABI. Its binaries ship as a Julia **artifact** and are
fetched lazily on first use, so installing the package needs no Rust toolchain.

## Installation

Eunoia is registered in the General registry, so install it with the Julia
package manager:

```julia
using Pkg
Pkg.add("Eunoia")
```

## Usage

```julia
using Eunoia

# Euler diagram from exclusive areas
fit = euler(Dict("A" => 5, "B" => 3, "A&B" => 1.5))
fit.shapes          # fitted Circle/Ellipse/Square/Rectangle structs
fit.loss            # fit quality (lower is better)
fit                 # `show` prints the residual table

# Membership lists are accepted too (counted into exclusive regions)
euler(Dict("A" => ["x", "y", "z"], "B" => ["y", "z", "w"]))

# Ellipses, with a "universe" complement (adds a container frame)
euler(Dict("A" => 4, "B" => 2, "A&B" => 1); shape = "ellipse", complement = 3)

# Canonical Venn diagrams: an Int, a name vector, or a membership mapping
venn(3)                          # three sets named A, B, C
venn(["A", "B", "C"]; shape = "ellipse")
```

`euler` returns an `EulerFit`, `venn` a `VennFit`; both carry the fitted
`shapes`, the original and fitted values, per-region residuals and
`region_error`, the overall `loss`, and (for complement fits) the `container`.

Common keyword arguments:

- `shape` — `"circle"` (default), `"ellipse"`, `"square"`, or `"rectangle"`.
- `input_type` — `"exclusive"` (default) or `"inclusive"`; with `"inclusive"`
  the fitted values read back in the same scale you supplied.
- `complement` — opt into "universe" fitting against a target leftover area.
- `seed` — make the stochastic fit reproducible.

Fitting can be tuned further (`loss`, `n_restarts`, `optimizer`, `mds_solver`,
`max_sets`, …) and the plot geometry adjusted (`n_vertices`, `label_precision`,
`sliver_threshold`); see the
[documentation](https://jolars.github.io/Eunoia.jl/).

## Plotting

Rendering lives in a **Makie package extension** that loads automatically once a
Makie backend is imported, so the core package stays plot-free:

```julia
using Eunoia, CairoMakie   # or GLMakie/WGLMakie

fit = euler(Dict("A" => 5, "B" => 3, "A&B" => 1.5))
eunoiaplot(fit)                                # publication-ready figure
eunoiaplot(fit; quantities = true, legend = true)
```

`eunoiaplot(fit)` returns a `Makie.FigureAxisPlot` with equal aspect and no axis
decorations; `eunoiaplot!(ax, fit)` draws into an existing axis, and the bare
Makie `plot(fit)`/`plot!(ax, fit)` recipe forms work too. Styling keywords
mirror the `eunoia-py` `plot()` API:

- `colors`: a vector (set order) or `Dict(name => color)`; region fills blend
  the member colors perceptually (OKLab).
- `fills`, `edges`: per-region/per-set style overrides.
- `labels`: `false`/true`, a per-set`Dict\`, or a uniform style.
- `quantities`: `false`/`true`, `"original"`/`"fitted"`, `"counts"`/`"percent"`,
  or a `Dict`.
- `legend`: `false`/`true` or a `Dict` of `Legend` keywords.
- `complement`: container-box style (drawn only for complement fits).
- `placement`: opt into collision-aware label placement with leader lines.

## The native library

The fitting engine is the `eunoia-capi` cdylib from the
[eunoia](https://github.com/jolars/eunoia) repository, cross-compiled for every
Julia-supported platform and attached to that repo's `v*` releases. The matching
`Artifacts.toml` makes Julia download the right binary lazily on first use.

To develop against a local Rust build instead, point `EUNOIA_CAPI_LIB` at it; it
always wins over the bundled artifact:

```sh
# in a checkout of jolars/eunoia
cargo build -p eunoia-capi --release
export EUNOIA_CAPI_LIB="$PWD/target/release/libeunoia_capi.so"  # .dylib on macOS
```

## Ecosystem

This package is the Python member of the [Eunoia](https://eunoia.bz) family. The
same Rust core powers bindings in several other languages:

  | Project                                            | Language             | Distribution                                        |
  | -------------------------------------------------- | -------------------- | --------------------------------------------------- |
  | [Eunoia](https://github.com/jolars/eunoia)         | Rust (core)          | [crates.io](https://crates.io/crates/eunoia)        |
  | [@jolars/eunoia](https://github.com/jolars/eunoia) | JavaScript/TS (WASM) | [npm](https://www.npmjs.com/package/@jolars/eunoia) |
  | [Eunoia](https://github.com/jolars/eunoia-py)      | Python               | [PyPI](https://pypi.org/project/eunoia/)            |
  | [eulerr](https://github.com/jolars/eulerr)         | R                    | [CRAN](https://cran.r-project.org/package=eulerr)   |

Narrative documentation for the whole family lives at
[eunoia.bz/docs/](https://eunoia.bz/docs/); the Rust API reference is at
[docs.rs/eunoia](https://docs.rs/eunoia/).

## Contributing

When writing commit messages, please use the [conventional commits
format](https://www.conventionalcommits.org/en/v1.0.0/).

## Versioning

Eunoia uses [semantic versioning](https://semver.org).
