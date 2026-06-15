# Agent instructions

This file provides guidance to Claude Code (claude.ai/code) and other agents
when working in this repository.

## What this is

Eunoia.jl is the Julia binding for [eunoia](https://github.com/jolars/eunoia), a
Rust library for area-proportional **Euler and Venn diagrams**. It is a sister
package to the Python binding [eunoia-py](https://github.com/jolars/eunoia-py).

The package is a thin, typed Julia surface over the `eunoia-capi` cdylib, which
speaks a small JSON-in/JSON-out C ABI (`eunoia_euler`, `eunoia_venn`,
`eunoia_place_labels`, `eunoia_version`, `eunoia_free`). All the real algorithms
(fitting, geometry, region extraction, label placement) live in the Rust core;
this repository only marshals input, calls the ABI, and parses the result into
typed structs — plus a Makie rendering extension.

**The native code is NOT in this repository.** `eunoia-capi` lives in the
[jolars/eunoia](https://github.com/jolars/eunoia) monorepo. The C ABI is the
contract between the two repos; treat it as such. There is no Cargo workspace
here, so the library cannot be built from this checkout (see "The native
library" below).

## Repository layout

  | Path                        | Contents                                                                           |
  | --------------------------- | ---------------------------------------------------------------------------------- |
  | `src/Eunoia.jl`             | Module entry: library loading (`dlopen`), `euler`/`venn`/`version`/`place_labels`. |
  | `src/parse.jl`              | Input parsing (membership lists, inclusive↔exclusive, venn forms).                 |
  | `src/types.jl`              | Typed result model (`EulerFit`/`VennFit`, shapes, `LabelPlacement`) + `Base.show`. |
  | `ext/EunoiaMakieExt.jl`     | Makie rendering extension (recipe + `eunoiaplot`). Weakdep-triggered.              |
  | `gen/generate_artifacts.jl` | Regenerates `Artifacts.toml` from a `v*` release in jolars/eunoia.                 |
  | `test/`                     | `runtests.jl` (default), `aqua.jl`, and `test/makie/` (opt-in env).                |
  | `docs/`                     | Documenter.jl site.                                                                |

Source uses 4-space indentation. Package name is `Eunoia` (UpperCamelCase); the
module, `src/Eunoia.jl`, and `Project.toml`'s `name` must all agree.

## The native library

At load time `src/Eunoia.jl` resolves the cdylib in this order:

1. `ENV["EUNOIA_CAPI_LIB"]` — an explicit path to a locally built
   `libeunoia_capi.{so,dylib}` / `eunoia_capi.dll`. **This is the dev path.**
2. The `eunoia` artifact in `Artifacts.toml` (lazily downloaded on first use;
   this is what end users get). No `Artifacts.toml` is committed until a binary
   release exists.

Because the capi source is in another repo, local development means building it
there and pointing this package at it:

```sh
# in a checkout of jolars/eunoia
cargo build -p eunoia-capi --release
export EUNOIA_CAPI_LIB="$PWD/target/release/libeunoia_capi.so"  # .dylib on macOS
```

`EUNOIA_CAPI_LIB` always wins over the artifact, so it is also how you test a
local Rust ABI change against the Julia surface.

## Commands

```sh
make test    # Pkg.test() in the package env (needs EUNOIA_CAPI_LIB set)
make docs    # build the Documenter site locally
```

- **Run the test suite:** `julia --project=. -e 'using Pkg; Pkg.test()'` with
  `EUNOIA_CAPI_LIB` set. The default run is light: core API + `Aqua`.
- **Makie extension tests** are opt-in (heavy precompile) and live in the
  dedicated `test/makie/` environment. Run them with `EUNOIA_TEST_MAKIE=true`;
  `runtests.jl` activates `test/makie` and renders headlessly with CairoMakie (a
  software backend, so no display is needed).
- CI (`.github/workflows/CI.yml`) builds `eunoia-capi` from jolars/eunoia via
  the `.github/actions/build-capi` composite action and exports
  `EUNOIA_CAPI_LIB`, then runs the matrix (Julia LTS + stable × Linux/macOS/
  Windows), the Makie job, and the docs deploy.

## Releasing & registration (the two-repo dance)

The capi binaries and the Julia package version separately, and the binary
release is in the *other* repo. To cut a release:

1. **In jolars/eunoia:** cut a normal crate release (versionary `v*` tag). The
   `julia-artifacts` workflow triggers on that tag, cross-compiles
   `libeunoia_capi-<triplet>.tar.gz` for every platform, and attaches them to
   the same GitHub release — no extra step. (To rebuild/attach binaries to an
   existing release out of band, run `julia-artifacts` manually with its
   `release_tag` input.)

2. **Here:** regenerate and commit the artifact hashes, pointing at that release
   tag:
   ```sh
   julia -e 'import Pkg; Pkg.add("ArtifactUtils")'
   julia --project=. gen/generate_artifacts.jl v<version>
   ```

3. Bump `version` in `Project.toml` (independent semver — not tied to the Rust
   crate's version) and merge.

4. Register: comment `@JuliaRegistrator register` on the release commit.
   `TagBot` then creates the matching GitHub tag/release; end users `add Eunoia`
   and the right binary is fetched lazily — no Rust toolchain required.

## Conventions

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org).
- **Versioning:** [SemVer](https://semver.org), independent of the Rust crate.
- The package must stay loadable without Makie (the extension is a weakdep);
  `eunoiaplot` is a stub in the core that errors until a Makie backend triggers
  the extension.
- American English spelling; the Oxford comma.
