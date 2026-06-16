# Live preview of the documentation. Watches docs/src/ (and Eunoia's
# docstrings), re-runs docs/make.jl on every change, and live-reloads the
# browser — the Documenter equivalent of a Quarto/pkgdown preview.
#
# Run from the repository root with the native library available:
#
#     export EUNOIA_CAPI_LIB="/path/to/eunoia/target/release/libeunoia_capi.so"
#     julia --project=docs docs/serve.jl
#
# then open the printed http://localhost:8000 URL.

using LiveServer

servedocs()
