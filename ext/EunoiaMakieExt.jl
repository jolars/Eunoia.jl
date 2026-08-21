"""
Makie rendering for [`Eunoia`](@ref). This package extension activates when a
Makie backend is loaded (`using CairoMakie`/`GLMakie`/`WGLMakie`). It implements
[`Eunoia.eunoiaplot`](@ref)/[`Eunoia.eunoiaplot!`](@ref) plus an `EunoiaDiagram`
recipe, so `plot(fit)`/`plot!(ax, fit)` also work.

The styling API mirrors the `eunoia-py` sister package's `plot()` (colors, fills,
edges, labels, quantities, legend, complement), adapted to Makie idioms (Makie
attribute names, perceptual OKLab color blending for region fills). All geometry
is read from the native `plot_data` bundle already present on every fit.
"""
module EunoiaMakieExt

using Eunoia
using Makie
using Printf: @sprintf
using GeometryBasics: Polygon, Point2f
import Eunoia: AbstractEulerFit, eunoiaplot, eunoiaplot!

# ---------------------------------------------------------------------------
# Recipe — draws the diagram primitives into an axis. This is what powers the
# bare `plot(fit)`/`plot!(ax, fit)` forms; the publication-ready figure (equal
# aspect, hidden decorations, legend) is assembled by `eunoiaplot` below.
# ---------------------------------------------------------------------------

@recipe EunoiaDiagram (fit,) begin
    "Per-set colors: a vector (shape order), a `Dict(name => color)`, or
    `automatic` for a built-in categorical palette."
    colors = Makie.automatic
    "Per-region fill overrides: `Dict(combo => attrs)` of `poly!` keywords."
    fills = Makie.automatic
    "Set-outline style: a uniform attrs collection, a per-set `Dict`, or a
    vector (one per set, shape order) of `lines!` keywords. Outlines are black
    by default; pass `:match` to color each outline with its set's fill color."
    edges = Makie.automatic
    "Set labels: `false`/`true`/`nothing`, a per-set `Dict`, or a uniform style."
    labels = Makie.automatic
    "Region quantities: `false`/`true`, `\"original\"`/`\"fitted\"`,
    `\"counts\"`/`\"percent\"`, or a `Dict`."
    quantities = false
    "Legend flag — only used here to default in-diagram labels off; the Legend
    block itself is drawn by `eunoiaplot`."
    legend = false
    "Container-box style: `poly!` keywords (drawn only when the fit has one)."
    complement = Makie.automatic
    "Default region-fill transparency."
    alpha = 0.5
    "Base label font size (points). Set names use this; region quantities use a
    slightly smaller size."
    fontsize = 14
    "Internal: when `true` the recipe skips drawing labels/quantities so the
    `eunoiaplot` wrapper can place them collision-aware. Not a public knob."
    defer_labels = false
end

Makie.plottype(::AbstractEulerFit) = EunoiaDiagram
Makie.convert_arguments(::Type{<:EunoiaDiagram}, fit::AbstractEulerFit) = (fit,)
Makie.preferred_axis_type(::EunoiaDiagram) = Makie.Axis

function Makie.plot!(p::EunoiaDiagram)
    fit = to_value(p[1])
    pd = fit.plot_data
    names = String[s.set for s in fit.shapes]
    base = resolve_colors(p.colors[], names)

    draw_complement!(p, fit, p.complement[])
    draw_region_fills!(p, pd, base, p.fills[], p.alpha[])
    draw_outlines!(p, pd, names, base, p.edges[])

    # The `eunoiaplot` wrapper handles labels itself when collision-aware
    # placement is requested (it owns the axis, which the loop needs); skip the
    # raw-anchor pass so labels aren't drawn twice.
    p.defer_labels[] && return p

    show_labels = resolve_label_visibility(p.labels[], p.legend[])
    specs = show_labels ?
        label_specs(p.labels[], names) :
        Dict{String, Any}(n => nothing for n in names)

    # A set label and a region quantity can land on the exact same anchor (the
    # core derives set anchors from region anchors). When both show, stack them:
    # name above, value below. Precompute the two anchor sets to detect overlap.
    qinfo = p.quantities[] === false ? nothing : resolve_quantities(p.quantities[])
    label_points = collect_label_points(pd, names, specs, show_labels)
    quantity_points = collect_quantity_points(pd, fit, qinfo)

    fs = Float64(p.fontsize[])
    show_labels && draw_set_labels!(p, pd, names, specs, quantity_points, fs)
    qinfo === nothing || draw_quantities!(p, pd, fit, qinfo, label_points, fs)
    return p
end

# ---------------------------------------------------------------------------
# Public entry points (methods on the `Eunoia.eunoiaplot`/`!` stubs)
# ---------------------------------------------------------------------------

# Create an axis configured for diagram rendering (equal aspect, no decorations)
# in the given figure cell. Shared by both `eunoiaplot` entry points.
function _diagram_axis(gp; axis = (;))
    ax = Axis(gp; aspect = DataAspect(), axis...)
    hidedecorations!(ax)
    hidespines!(ax)
    return ax
end

function eunoiaplot(
    fit::AbstractEulerFit;
    figure = (;),
    axis = (;),
    legend = false,
    kwargs...,
)
    f = Figure(; figure...)
    ax = _diagram_axis(f[1, 1]; axis = axis)
    p = eunoiaplot!(ax, fit; legend = legend, kwargs...)
    add_legend_if_requested!(f, fit, p, legend)
    return Makie.FigureAxisPlot(f, ax, p)
end

# Grid-position form: draw into a diagram-configured axis created in an existing
# layout cell (`eunoiaplot(f[1, 2], fit)`), mirroring Makie's `plot(fig[i, j],
# data)`. Returns a `Makie.AxisPlot`. No `figure`/`legend` here — the figure
# exists already, and legend placement in a hand-built layout is the caller's to
# decide (add a `Legend` yourself).
function eunoiaplot(
    gp::Union{Makie.GridPosition, Makie.GridSubposition},
    fit::AbstractEulerFit;
    axis = (;),
    kwargs...,
)
    ax = _diagram_axis(gp; axis = axis)
    p = eunoiaplot!(ax, fit; kwargs...)
    return Makie.AxisPlot(ax, p)
end

"""
    eunoiaplot!(ax, fit; label_placement=true, set_label_placement=false,
                glyphs=nothing, members=nothing, leader_style=(;), kwargs...)

Draw a fit into an existing axis. By default (`label_placement=true`) labels are
placed collision-aware via raycast (see [`Eunoia.eunoiaplot`](@ref) for the value
forms); the resolved label boxes and any exterior leader polylines are drawn into
`ax`. Pass `label_placement=false` to instead leave labels at their raw anchors.
Set `set_label_placement=true` to move set names outside their shapes. Explicit
`glyphs` and `members` mappings enable the two mutually exclusive glyph modes.
`leader_style` is a collection of `lines!` keywords for leader lines.
"""
function eunoiaplot!(
    ax,
    fit::AbstractEulerFit;
    label_placement = true,
    set_label_placement = false,
    glyphs = nothing,
    glyph_options = (;),
    glyph_style = (;),
    members = nothing,
    member_options = (;),
    member_style = (;),
    leader_style = (;),
    kwargs...,
)
    label_placement isa Union{Bool, NamedTuple, AbstractDict} || throw(
        ArgumentError("eunoia: label_placement must be false, true, a NamedTuple, or a Dict"),
    )
    set_label_placement isa Union{Bool, NamedTuple, AbstractDict} || throw(
        ArgumentError(
            "eunoia: set_label_placement must be false, true, a NamedTuple, or a Dict",
        ),
    )
    glyphs_enabled = !(glyphs === nothing || glyphs === false)
    members_enabled = !(members === nothing || members === false)
    glyphs_enabled && members_enabled &&
        throw(ArgumentError("eunoia: glyphs and members are mutually exclusive"))
    glyphs === true &&
        throw(ArgumentError("eunoia: glyphs requires an explicit region-to-count mapping"))
    members === true &&
        throw(ArgumentError("eunoia: members requires an explicit region-to-names mapping"))

    advanced = set_label_placement !== false || glyphs_enabled || members_enabled
    if label_placement === false && !advanced
        return eunoiadiagram!(ax, fit; kwargs...)
    end
    p = eunoiadiagram!(ax, fit; defer_labels = true, kwargs...)
    place_and_draw_content!(
        ax, p, fit;
        label_placement = label_placement,
        set_label_placement = set_label_placement,
        glyphs = glyphs_enabled ? glyphs : nothing,
        glyph_options = glyph_options,
        glyph_style = glyph_style,
        members = members_enabled ? members : nothing,
        member_options = member_options,
        member_style = member_style,
        leader_style = leader_style,
    )
    return p
end

function add_legend_if_requested!(f, fit, p, legend)
    legend === false && return
    names = String[s.set for s in fit.shapes]
    base = resolve_colors(p.colors[], names)
    a = p.alpha[]
    elements = [PolyElement(color = (base[n], a)) for n in names]
    legkw = legend isa Union{AbstractDict, NamedTuple} ? _kw(legend) : (;)
    Legend(f[1, 2], elements, names; legkw...)
    return
end

# ---------------------------------------------------------------------------
# Colors — categorical palette + perceptual (OKLab) blending of region fills,
# ported from `eunoia-py`'s `_plot.py`.
# ---------------------------------------------------------------------------

const _TAB10 = RGBf[
    parse(RGBf, "#1f77b4"),
    parse(RGBf, "#ff7f0e"),
    parse(RGBf, "#2ca02c"),
    parse(RGBf, "#d62728"),
    parse(RGBf, "#9467bd"),
    parse(RGBf, "#8c564b"),
    parse(RGBf, "#e377c2"),
    parse(RGBf, "#7f7f7f"),
    parse(RGBf, "#bcbd22"),
    parse(RGBf, "#17becf"),
]

_as_rgb(x) = (c = Makie.to_color(x); RGBf(c.r, c.g, c.b))

function resolve_colors(colors, names)
    if colors === Makie.automatic
        return Dict(n => _TAB10[mod1(i, 10)] for (i, n) in enumerate(names))
    elseif colors isa AbstractDict
        return Dict(
            n => (haskey(colors, n) ? _as_rgb(colors[n]) : _TAB10[mod1(i, 10)])
            for (i, n) in enumerate(names)
        )
    else
        length(colors) < length(names) &&
            error(
                "eunoia: colors has $(length(colors)) entries but there are $(length(names)) sets",
            )
        return Dict(n => _as_rgb(colors[i]) for (i, n) in enumerate(names))
    end
end

_srgb_to_linear(c) = c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)^2.4
_linear_to_srgb(c) = clamp(c <= 0.0031308 ? 12.92c : 1.055 * c^(1 / 2.4) - 0.055, 0.0, 1.0)

function _srgb_to_oklab(r, g, b)
    lr = _srgb_to_linear(r)
    lg = _srgb_to_linear(g)
    lb = _srgb_to_linear(b)
    lc = 0.4122214708lr + 0.5363325363lg + 0.0514459929lb
    mc = 0.2119034982lr + 0.6806995451lg + 0.1073969566lb
    sc = 0.0883024619lr + 0.2817188376lg + 0.6299787005lb
    l_ = cbrt(lc)
    m_ = cbrt(mc)
    s_ = cbrt(sc)
    return (
        0.2104542553l_ + 0.793617785m_ - 0.0040720468s_,
        1.9779984951l_ - 2.428592205m_ + 0.4505937099s_,
        0.0259040371l_ + 0.7827717662m_ - 0.808675766s_,
    )
end

function _oklab_to_srgb(big_l, a, b)
    l_ = big_l + 0.3963377774a + 0.2158037573b
    m_ = big_l - 0.1055613458a - 0.0638541728b
    s_ = big_l - 0.0894841775a - 1.291485548b
    lc = l_^3
    mc = m_^3
    sc = s_^3
    lr = 4.0767416621lc - 3.3077115913mc + 0.2309699292sc
    lg = -1.2684380046lc + 2.6097574011mc - 0.3413193965sc
    lb = -0.0041960863lc - 0.7034186147mc + 1.707614701sc
    return (_linear_to_srgb(lr), _linear_to_srgb(lg), _linear_to_srgb(lb))
end

function blend_region_color(cols)
    isempty(cols) && return RGBf(0.5, 0.5, 0.5)
    n = length(cols)
    labs = [_srgb_to_oklab(c.r, c.g, c.b) for c in cols]
    big_l = sum(t -> t[1], labs) / n
    a = sum(t -> t[2], labs) / n
    b = sum(t -> t[3], labs) / n
    r, g, bb = _oklab_to_srgb(big_l, a, b)
    return RGBf(r, g, bb)
end

# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

_ring(r) = Point2f[Point2f(pt[1], pt[2]) for pt in r]

function piece_to_polygon(piece)
    outer = _ring(piece.outer)
    holes = [_ring(h) for h in piece.holes]
    return isempty(holes) ? Polygon(outer) : Polygon(outer, holes)
end

# Normalize a user style collection (Dict with String/Symbol keys, or a
# NamedTuple) to a NamedTuple of `Symbol => value` kwargs.
_kw(d::AbstractDict) = (; (Symbol(k) => v for (k, v) in d)...)
_kw(nt::NamedTuple) = nt
_kw(::Nothing) = (;)

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

function draw_complement!(p, fit, complement)
    fit.container === nothing && return
    c = fit.container
    rect = Makie.Rect2f(
        c.center.x - c.width / 2,
        c.center.y - c.height / 2,
        c.width,
        c.height,
    )
    attrs = merge(
        (
            color = RGBf(0.94, 0.94, 0.94),
            strokecolor = RGBf(0.4, 0.4, 0.4),
            strokewidth = 1.0,
        ),
        _kw(complement === Makie.automatic ? (;) : complement),
    )
    poly!(p, rect; attrs...)
    return
end

function draw_region_fills!(p, pd, base, fills, default_alpha)
    haskey(pd, :region_pieces) || return
    for (key, pieces) in pairs(pd.region_pieces)
        combo = String(key)
        isempty(combo) && continue # complement region — box covers it
        members = String.(split(combo, '&'))
        cols = RGBf[base[m] for m in members if haskey(base, m)]
        override = (fills isa AbstractDict && haskey(fills, combo)) ?
            _kw(fills[combo]) :
            (;)
        attrs = merge(
            (color = blend_region_color(cols), alpha = default_alpha, strokewidth = 0),
            override,
        )
        for piece in pieces
            poly!(p, piece_to_polygon(piece); attrs...)
        end
    end
    return
end

# Borders default to black; `edges = :match`/`"match"` colors each set's outline
# with its fill color instead (the pre-1.0 default). Either way, an explicit
# `color` in the per-set/uniform `edges` style still wins.
_edges_match(edges) = edges === :match || edges == "match"

function draw_outlines!(p, pd, names, base, edges)
    haskey(pd, :shape_outlines) || return
    match = _edges_match(edges)
    for (i, n) in enumerate(names)
        haskey(pd.shape_outlines, Symbol(n)) || continue
        pts = _ring(pd.shape_outlines[Symbol(n)])
        length(pts) < 3 && continue
        push!(pts, pts[1]) # close the open polyline
        default_color = match ? base[n] : :black
        attrs = merge((color = default_color, linewidth = 1.5), edge_style(n, edges, i))
        lines!(p, pts; attrs...)
    end
    return
end

function edge_style(name, edges, i)
    (edges === Makie.automatic || _edges_match(edges)) && return (;)
    if edges isa AbstractDict
        if !isempty(edges) && all(v -> v isa Union{AbstractDict, NamedTuple}, values(edges))
            return haskey(edges, name) ? _kw(edges[name]) : (;)   # per-set
        end
        return _kw(edges)                     # uniform
    elseif edges isa AbstractVector
        length(edges) < i &&
            error("eunoia: edges sequence is shorter than the number of sets")
        return _kw(edges[i])
    end
    return (;)
end

# ---- labels ----------------------------------------------------------------

# Region quantities render at this fraction of the set-label font size (matches
# the web app's `labelSize * 0.75`).
const QUANTITY_FONT_FACTOR = 0.75

function resolve_label_visibility(labels, legend)
    labels === false && return false
    labels isa AbstractDict && return true
    (labels === nothing || labels === Makie.automatic) && return legend === false
    return labels === true
end

# Per-set label resolution → Dict(name => (text, style)) or `nothing` to hide.
function label_specs(labels, names)
    base = Dict{String, Any}(n => (n, (;)) for n in names)
    labels isa AbstractDict || return base    # automatic/true/nothing → defaults
    nameset = Set(names)
    known = [String(k) for k in keys(labels) if String(k) in nameset]
    if isempty(known)
        # uniform style applied to all
        style = _kw(labels)
        return Dict{String, Any}(n => (n, style) for n in names)
    end
    for (k, v) in labels
        ks = String(k)
        ks in nameset || continue
        if v === nothing || v === false
            base[ks] = nothing
        elseif v isa AbstractString
            base[ks] = (String(v), (;))
        elseif v isa Union{AbstractDict, NamedTuple}
            d = _kw(v)
            txt = haskey(d, :text) ? String(d.text) : ks
            base[ks] = (txt, Base.structdiff(d, NamedTuple{(:text,)}))
        else
            error(
                "eunoia: labels[$ks] must be a String, Dict, NamedTuple, nothing, or false",
            )
        end
    end
    return base
end

function collect_label_points(pd, names, specs, show_labels)
    pts = Set{Tuple{Float64, Float64}}()
    (show_labels && haskey(pd, :set_anchors)) || return pts
    for n in names
        specs[n] === nothing && continue
        haskey(pd.set_anchors, Symbol(n)) || continue
        a = pd.set_anchors[Symbol(n)]
        push!(pts, (Float64(a[1]), Float64(a[2])))
    end
    return pts
end

function draw_set_labels!(p, pd, names, specs, quantity_points, fontsize)
    haskey(pd, :set_anchors) || return
    for n in names
        spec = specs[n]
        spec === nothing && continue
        haskey(pd.set_anchors, Symbol(n)) || continue
        a = pd.set_anchors[Symbol(n)]
        text, style = spec
        valign = (Float64(a[1]), Float64(a[2])) in quantity_points ? :bottom : :center
        attrs = merge((align = (:center, valign), fontsize = fontsize), _kw(style))
        text!(p, Point2f(a[1], a[2]); text = text, attrs...)
    end
    return
end

# ---- quantities ------------------------------------------------------------

function resolve_quantities(q)
    source = "original"
    types = ["counts"]
    style = (;)
    if q === true
        # defaults
    elseif q isa AbstractString
        if q in ("original", "fitted")
            source = q
        elseif q in ("counts", "percent")
            types = [q]
        else
            error(
                "eunoia: quantities string must be original/fitted/counts/percent; got $q",
            )
        end
    elseif q isa Union{AbstractDict, NamedTuple}
        d = _kw(q)
        source = haskey(d, :source) ? String(d.source) : "original"
        source in ("original", "fitted") ||
            error("eunoia: quantities source must be original or fitted; got $source")
        rawtype = haskey(d, :type) ? d.type : "counts"
        types = rawtype isa AbstractString ?
            [String(rawtype)] :
            [String(t) for t in rawtype]
        all(t -> t in ("counts", "percent"), types) ||
            error("eunoia: quantities type entries must be counts or percent")
        style = Base.structdiff(d, NamedTuple{(:source, :type)})
    end
    return (source, types, style)
end

function collect_quantity_points(pd, fit, qinfo)
    pts = Set{Tuple{Float64, Float64}}()
    (qinfo !== nothing && haskey(pd, :region_anchors)) || return pts
    source, _, _ = qinfo
    vals = source == "fitted" ? fit.fitted_values : fit.original_values
    for (key, anchor) in pairs(pd.region_anchors)
        combo = String(key)
        (isempty(combo) || !haskey(vals, combo)) && continue
        push!(pts, (Float64(anchor[1]), Float64(anchor[2])))
    end
    return pts
end

function format_quantity(v, total, types)
    parts = String[]
    "counts" in types && push!(parts, @sprintf("%.3g", v))
    if "percent" in types
        pct = total > 0 ? v / total * 100 : 0.0
        s = @sprintf("%.3g%%", pct)
        push!(parts, "counts" in types ? "($s)" : s)
    end
    return join(parts, "\n")
end

# ---------------------------------------------------------------------------
# Collision-aware placement (the `label_placement=` path of `eunoiaplot`)
#
# `place_labels` (the native core) needs each region's label box in *layout*
# units, but Makie text metrics come back in pixels and the data↔pixel scale is
# only known once the axis is laid out — and it shifts as exterior labels push
# the limits out. So we iterate: measure (px) → convert with the current scale →
# place → grow the limits to fit → recompute the scale, until it converges.
# ---------------------------------------------------------------------------

const MAX_PLACE_ITERS = 8
const PLACE_EXTENT_TOL = 0.02   # converged when the view extent moves < 2%
# Divergence guard: a label larger than the viewport makes the fixed point
# expand without bound (each zoom-out enlarges the fixed-px box in data units).
# Cap the view at this multiple of the geometry and keep the last sane layout.
const MAX_BBOX_FACTOR = 25.0

# Which region hosts each set's label anchor, as a set → combination map. The
# core computes this (`PlotData::set_anchor_regions`); capis ≥ 1.4 expose it
# directly, so use it. Older capis lack the field: fall back to matching set
# anchors to region anchors by position (a set's anchor is its host region's
# anchor, so the JSON floats match under `==` — except where the two are
# computed separately and differ in their last bits, which is exactly why the
# native field exists).
function set_host_regions(pd)
    if haskey(pd, :set_anchor_regions)
        return Dict{String, String}(
            String(s) => String(r)
            for (s, r) in pairs(pd.set_anchor_regions)
        )
    end
    hosts = Dict{String, String}()
    (haskey(pd, :set_anchors) && haskey(pd, :region_anchors)) || return hosts
    for (s, sa) in pairs(pd.set_anchors)
        sx, sy = Float64(sa[1]), Float64(sa[2])
        for (r, ra) in pairs(pd.region_anchors)
            if Float64(ra[1]) == sx && Float64(ra[2]) == sy
                hosts[String(s)] = String(r)
                break
            end
        end
    end
    return hosts
end

# Per-region label content as ordered `(text, fontsize, style)` lines: hosted set
# names first (mirroring the web's `nestedSets`/`regionTitleLines`), then the
# quantity. Regions with no content are absent from the result.
function region_label_lines(pd, fit, names, specs, show_labels, qinfo, fontsize)
    out = Dict{String, Vector{Tuple{String, Float64, Any}}}()
    region_keys = haskey(pd, :region_anchors) ?
        Set(String(k) for k in keys(pd.region_anchors)) :
        Set{String}()

    if show_labels
        hosts = set_host_regions(pd)
        nested = Dict{String, Vector{String}}()
        for s in names
            h = get(hosts, s, nothing)
            (h === nothing || !occursin('&', h)) && continue
            push!(get!(nested, h, String[]), s)
        end
        for combo in region_keys
            isempty(combo) && continue
            titlesets = occursin('&', combo) ? get(nested, combo, String[]) : [combo]
            for s in titlesets
                sp = get(specs, s, nothing)
                sp === nothing && continue
                txt, style = sp
                push!(get!(out, combo, Tuple{String, Float64, Any}[]), (
                    txt,
                    fontsize,
                    style,
                ))
            end
        end
    end

    if qinfo !== nothing
        source, types, style = qinfo
        vals = source == "fitted" ? fit.fitted_values : fit.original_values
        total = sum(values(vals); init = 0.0)
        cstyle = merge((color = RGBf(0.41, 0.41, 0.41),), _kw(style))
        for combo in region_keys
            (isempty(combo) || !haskey(vals, combo)) && continue
            txt = format_quantity(vals[combo], total, types)
            push!(get!(out, combo, Tuple{String, Float64, Any}[]), (
                txt,
                fontsize * QUANTITY_FONT_FACTOR,
                cstyle,
            ))
        end
    end
    return out
end

# The font `text!` will render with — best-effort from the scene theme, falling
# back to Makie's default (metrics only feed placement, which tolerates slack).
function _label_font(ax)
    try
        return Makie.to_font(to_value(get(ax.scene.theme, :font, "TeX Gyre Heros Makie")))
    catch
        return Makie.to_font("TeX Gyre Heros Makie")
    end
end

_line_dims(text, fs, font) = Tuple(Makie.widths(Makie.text_bb(text, font, Float32(
    fs,
)))[1:2])

# Stacked-box dimensions in pixels: widest line × summed heights + inter-line gaps.
function measure_box(lines, font, gap)
    isempty(lines) && return (0.0, 0.0)
    dims = [_line_dims(t, fs, font) for (t, fs, _) in lines]
    w = maximum(d -> d[1], dims)
    h = sum(d -> d[2], dims) + gap * (length(lines) - 1)
    return (Float64(w), Float64(h))
end

# data-units-per-pixel of the axis, separately per axis (≈ equal under DataAspect).
function axis_scale(ax)
    fl = ax.finallimits[]
    vp = ax.scene.viewport[]
    wd = Makie.widths(fl)
    wp = Makie.widths(vp)
    sx = wp[1] > 0 ? wd[1] / wp[1] : 1.0
    sy = wp[2] > 0 ? wd[2] / wp[2] : 1.0
    return (Float64(sx), Float64(sy))
end

# Geometry-only bounding box (region pieces + container), in layout units.
function geom_bbox(fit)
    pd = fit.plot_data
    xmin = ymin = Inf
    xmax = ymax = -Inf
    if haskey(pd, :region_pieces)
        for (_, pieces) in pairs(pd.region_pieces), piece in pieces
            for pt in piece.outer
                xmin = min(xmin, pt[1])
                xmax = max(xmax, pt[1])
                ymin = min(ymin, pt[2])
                ymax = max(ymax, pt[2])
            end
        end
    end
    if fit.container !== nothing
        c = fit.container
        xmin = min(xmin, c.center.x - c.width / 2)
        xmax = max(xmax, c.center.x + c.width / 2)
        ymin = min(ymin, c.center.y - c.height / 2)
        ymax = max(ymax, c.center.y + c.height / 2)
    end
    return (xmin, xmax, ymin, ymax)
end

# Extend `geom` to cover every placed label box and leader vertex.
function placement_bbox(geom, placements, sizes_data)
    xmin, xmax, ymin, ymax = geom
    consume(x, y) = (
        xmin = min(xmin, x);
        xmax = max(xmax, x);
        ymin = min(ymin, y);
        ymax = max(ymax, y)
    )
    for (combo, pl) in placements
        haskey(sizes_data, combo) || continue
        w, h = sizes_data[combo]
        consume(pl.anchor.x - w / 2, pl.anchor.y - h / 2)
        consume(pl.anchor.x + w / 2, pl.anchor.y + h / 2)
        pl.tether === nothing || consume(pl.tether.x, pl.tether.y)
        pl.leader_end === nothing || consume(pl.leader_end.x, pl.leader_end.y)
        for pt in pl.leader_waypoints
            consume(pt.x, pt.y)
        end
    end
    return (xmin, xmax, ymin, ymax)
end

function raw_region_placements(pd, lines_by_region)
    out = Dict{String, Eunoia.LabelPlacement}()
    haskey(pd, :region_anchors) || return out
    for combo in keys(lines_by_region)
        haskey(pd.region_anchors, Symbol(combo)) || continue
        anchor = pd.region_anchors[Symbol(combo)]
        out[combo] = Eunoia.LabelPlacement(
            Eunoia.Point(Float64(anchor[1]), Float64(anchor[2])),
            :interior, nothing, nothing, Eunoia.Point[],
        )
    end
    return out
end

function option_obstacles(options, automatic)
    opts = _kw(options)
    supplied = haskey(opts, :obstacles) && opts.obstacles !== nothing ?
        collect(opts.obstacles) : Eunoia.BoundingBox[]
    rest = haskey(opts, :obstacles) ?
        Base.structdiff(opts, NamedTuple{(:obstacles,)}) : opts
    obstacles = vcat(supplied, automatic)
    return isempty(obstacles) ? rest : merge(rest, (; obstacles))
end

function placement_obstacles(placements, sizes, padding)
    isempty(placements) && return Eunoia.BoundingBox[]
    return Eunoia.label_boxes(placements, sizes; padding = padding)
end

function outside_set_lines(names, specs, show_labels, fontsize)
    out = Dict{String, Vector{Tuple{String, Float64, Any}}}()
    show_labels || return out
    for name in names
        spec = specs[name]
        spec === nothing && continue
        text, style = spec
        out[name] = [(text, fontsize, style)]
    end
    return out
end

function place_and_draw_content!(
    ax,
    p,
    fit;
    label_placement,
    set_label_placement,
    glyphs,
    glyph_options,
    glyph_style,
    members,
    member_options,
    member_style,
    leader_style,
)
    pd = fit.plot_data
    names = String[s.set for s in fit.shapes]
    base = resolve_colors(p.colors[], names)
    fontsize = Float64(p.fontsize[])
    show_labels = resolve_label_visibility(p.labels[], p.legend[])
    specs = show_labels ?
        label_specs(p.labels[], names) :
        Dict{String, Any}(n => nothing for n in names)
    qinfo = p.quantities[] === false ? nothing : resolve_quantities(p.quantities[])

    outside_sets = set_label_placement !== false
    lines_by_region = region_label_lines(
        pd,
        fit,
        names,
        specs,
        show_labels && !outside_sets,
        qinfo,
        fontsize,
    )
    set_lines = outside_set_lines(names, specs, show_labels && outside_sets, fontsize)

    font = _label_font(ax)
    gap = 0.15 * fontsize
    boxes_px = Dict(
        combo => measure_box(lines, font, gap) for (combo, lines) in lines_by_region
    )
    set_boxes_px =
        Dict(name => measure_box(lines, font, gap) for (name, lines) in set_lines)
    strat = label_placement isa Union{NamedTuple, AbstractDict} ? _kw(label_placement) : (;)
    set_strat = set_label_placement isa Union{NamedTuple, AbstractDict} ?
        _kw(set_label_placement) : (;)
    geom = geom_bbox(fit)

    geom_extent = max(geom[2] - geom[1], geom[4] - geom[3])
    max_extent = MAX_BBOX_FACTOR * geom_extent

    Makie.reset_limits!(ax)
    placements = Dict{String, Eunoia.LabelPlacement}()
    set_placements = Dict{String, Eunoia.LabelPlacement}()
    sizes_data = Dict{String, Tuple{Float64, Float64}}()
    set_sizes_data = Dict{String, Tuple{Float64, Float64}}()
    prev_extent = nothing
    for _ in 1:MAX_PLACE_ITERS
        sx, sy = axis_scale(ax)
        cand_sizes = Dict(combo => (w * sx, h * sy) for (combo, (w, h)) in boxes_px)
        cand = label_placement === false ? raw_region_placements(pd, lines_by_region) :
            Eunoia.place_labels(fit, cand_sizes; strat...)
        label_padding = 0.15 * fontsize * max(sx, sy)
        region_obstacles = placement_obstacles(cand, cand_sizes, label_padding)

        cand_set_sizes = Dict(name => (w * sx, h * sy)
            for (name, (w, h)) in set_boxes_px)
        cand_sets = if isempty(cand_set_sizes)
            Dict{String, Eunoia.LabelPlacement}()
        else
            opts = option_obstacles(set_strat, region_obstacles)
            Eunoia.place_set_labels(fit, cand_set_sizes; opts...)
        end

        xmin, xmax, ymin, ymax = placement_bbox(geom, cand, cand_sizes)
        xmin, xmax, ymin, ymax = placement_bbox(
            (xmin, xmax, ymin, ymax), cand_sets, cand_set_sizes,
        )
        extent = max(xmax - xmin, ymax - ymin)
        !isempty(placements) && extent > max_extent && break
        placements, sizes_data = cand, cand_sizes
        set_placements, set_sizes_data = cand_sets, cand_set_sizes
        prev_extent !== nothing &&
            abs(extent - prev_extent) <= PLACE_EXTENT_TOL * prev_extent &&
            break
        prev_extent = extent
        pad = 0.03 * extent
        Makie.limits!(ax, xmin - pad, xmax + pad, ymin - pad, ymax + pad)
        Makie.reset_limits!(ax)
    end

    sx, sy = axis_scale(ax)
    padding = 0.15 * fontsize * max(sx, sy)
    obstacles = vcat(
        placement_obstacles(placements, sizes_data, padding),
        placement_obstacles(set_placements, set_sizes_data, padding),
    )
    glyphs === nothing || draw_glyphs!(
        p, fit, glyphs, glyph_options, glyph_style, obstacles, base,
    )
    members === nothing || draw_members!(
        ax, p, fit, members, member_options, member_style, obstacles, fontsize, font,
    )
    draw_placed_labels!(p, lines_by_region, placements, font, gap, leader_style)
    draw_placed_set_labels!(p, set_lines, set_placements)
    return
end

function combo_color(combo, base)
    sets = String.(split(combo, '&'))
    return blend_region_color(RGBf[base[name] for name in sets if haskey(base, name)])
end

function draw_glyphs!(p, fit, counts, options, style, obstacles, base)
    counts isa AbstractDict ||
        throw(ArgumentError("eunoia: glyphs must be a region-to-count mapping"))
    opts = option_obstacles(options, obstacles)
    placed = Eunoia.place_glyphs(fit, counts; opts...)
    override = _kw(style)
    for (combo, points) in placed.positions
        isempty(points) && continue
        color = combo_color(combo, base)
        attrs = merge(
            (
                marker = :circle,
                markersize = 2 * placed.radius,
                markerspace = :data,
                color = color,
                strokecolor = color,
                strokewidth = 0.5,
            ),
            override,
        )
        scatter!(p, Point2f[Point2f(pt.x, pt.y) for pt in points]; attrs...)
    end
    return placed
end

function draw_members!(ax, p, fit, members, options, style, obstacles, fontsize, font)
    members isa AbstractDict ||
        throw(ArgumentError("eunoia: members must be a region-to-names mapping"))
    labels = Dict{String, Vector{String}}(
        string(combo) => string.(collect(names)) for (combo, names) in members
    )
    attrs = _kw(style)
    reference_size = haskey(attrs, :fontsize) ? Float64(attrs.fontsize) :
        fontsize * QUANTITY_FONT_FACTOR
    draw_attrs = haskey(attrs, :fontsize) ?
        Base.structdiff(attrs, NamedTuple{(:fontsize,)}) : attrs
    sx, sy = axis_scale(ax)
    sizes = Dict{String, Vector{Tuple{Float64, Float64}}}(
        combo => [
            (
                Float64(_line_dims(text, reference_size, font)[1]) * sx,
                Float64(_line_dims(text, reference_size, font)[2]) * sy,
            ) for text in texts
        ] for (combo, texts) in labels
    )
    opts = option_obstacles(options, obstacles)
    placed = Eunoia.place_glyph_boxes(fit, sizes; opts...)
    for (combo, boxes) in placed.boxes
        texts = get(labels, combo, String[])
        for (i, box) in enumerate(boxes)
            i > length(texts) && break
            text!(
                p,
                Point2f(box.center.x, box.center.y);
                text = texts[i],
                align = (:center, :center),
                fontsize = reference_size * placed.scale,
                draw_attrs...,
            )
        end
    end
    return placed
end

function draw_placed_set_labels!(p, lines_by_set, placements)
    for (name, lines) in lines_by_set
        haskey(placements, name) || continue
        text, fontsize, style = only(lines)
        anchor = placements[name].anchor
        attrs = merge((align = (:center, :center), fontsize = fontsize), _kw(style))
        text!(p, Point2f(anchor.x, anchor.y); text = text, attrs...)
    end
    return
end

function draw_placed_labels!(p, lines_by_region, placements, font, gap, leader_style)
    lattrs = merge((color = RGBf(0.45, 0.45, 0.45), linewidth = 1.0), _kw(leader_style))
    for (combo, lines) in lines_by_region
        haskey(placements, combo) || continue
        pl = placements[combo]
        anchor = Point2f(pl.anchor.x, pl.anchor.y)

        if pl.tether !== nothing && pl.leader_end !== nothing
            pts = Point2f[Point2f(pl.tether.x, pl.tether.y)]
            for w in pl.leader_waypoints
                push!(pts, Point2f(w.x, w.y))
            end
            push!(pts, Point2f(pl.leader_end.x, pl.leader_end.y))
            lines!(p, pts; lattrs...)
        end

        # Stack the lines top-to-bottom, centered on the anchor. `offset` is in
        # pixels (text's default `markerspace = :pixel`), matching the metrics.
        _, h_px = measure_box(lines, font, gap)
        cursor = h_px / 2
        for (text, fs, style) in lines
            lh = _line_dims(text, fs, font)[2]
            cy = cursor - lh / 2
            cursor -= lh + gap
            attrs = merge(
                (
                    align = (:center, :center),
                    fontsize = fs,
                    offset = (0.0f0, Float32(cy)),
                    markerspace = :pixel,
                ),
                _kw(style),
            )
            text!(p, anchor; text = text, attrs...)
        end
    end
    return
end

function draw_quantities!(p, pd, fit, qinfo, label_points, fontsize)
    haskey(pd, :region_anchors) || return
    source, types, style = qinfo
    vals = source == "fitted" ? fit.fitted_values : fit.original_values
    total = sum(values(vals); init = 0.0)
    for (key, anchor) in pairs(pd.region_anchors)
        combo = String(key)
        (isempty(combo) || !haskey(vals, combo)) && continue
        valign = (Float64(anchor[1]), Float64(anchor[2])) in label_points ? :top : :center
        attrs = merge(
            (
                align = (:center, valign),
                fontsize = fontsize * QUANTITY_FONT_FACTOR,
                color = RGBf(0.41, 0.41, 0.41),
            ),
            _kw(style),
        )
        text!(
            p,
            Point2f(anchor[1], anchor[2]);
            text = format_quantity(vals[combo], total, types),
            attrs...,
        )
    end
    return
end

end # module
