class_name UiTheme
extends RefCounted
## Shared UI tokens and draw helpers (see docs/UI_STYLE.md). No assets, no fonts.

const BG := Color("14161B")
const SURFACE := Color("1E2129")
const SURFACE_2 := Color("23262E")
const SURFACE_DIM := Color("191C22")
const LINE := Color("3A3F4B")
const TRACK := Color("2A2E37")
const TEXT := Color("F3F1EC")
const TEXT_DIM := Color("A6ADBB")
const TEXT_FAINT := Color("8A91A0")
const ACCENT := Color("4CC9F0")
const ACCENT_TEXT := Color("0B1B22")
const GOLD := Color("F7C948")
const GOLD_TEXT := Color("2A2410")
const WARN := Color("FFB547")
const WARN_BG := Color("2E2718")
const CRIT := Color("FF5D5D")
const CRIT_BG := Color("3A1D20")
const CRIT_TEXT := Color("FF8A8A")
const REJECT_LINE := Color("FF6B6B")
const REJECT_BG := Color("2A1C1F")
const REJECT_TEXT := Color("FFC2C2")
const PIP_LINE := Color("5B6271")

const DESIGN_W := 720.0
const MOCK_W := 390.0
const MIN_TARGET_MOCK := 44.0


## Mock px (390 wide) -> game px (720 wide design).
static func px(mock: float) -> float:
	return mock * DESIGN_W / MOCK_W


static func min_target() -> float:
	return px(MIN_TARGET_MOCK)


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius_mock: float = 14.0, border_mock: float = 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(0 if border.a == 0.0 else maxi(1, roundi(px(border_mock))))
	sb.set_corner_radius_all(roundi(px(radius_mock)))
	return sb


static func card(warn: bool = false, crit: bool = false) -> StyleBoxFlat:
	if crit:
		return box(CRIT_BG, CRIT, 14.0, 2.0)
	if warn:
		return box(WARN_BG, WARN, 14.0, 2.0)
	return box(SURFACE, LINE)


## kind: "primary", "secondary", "danger", "gold", "icon".
static func style_button(b: Button, kind: String = "secondary", font_size: int = 28) -> void:
	var bg := SURFACE
	var line := LINE
	var fg := TEXT
	match kind:
		"primary":
			bg = ACCENT
			line = ACCENT
			fg = ACCENT_TEXT
		"gold":
			bg = GOLD
			line = GOLD
			fg = GOLD_TEXT
		"danger":
			bg = REJECT_BG
			line = REJECT_LINE
			fg = REJECT_TEXT
		"icon":
			bg = SURFACE
	var press := bg.lightened(0.15)
	b.add_theme_stylebox_override("normal", box(bg, line, 20.0))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.07), line, 20.0))
	b.add_theme_stylebox_override("pressed", box(press, line, 20.0))
	b.add_theme_stylebox_override("focus", box(bg, line, 20.0))
	b.add_theme_stylebox_override("disabled", box(SURFACE_DIM, LINE, 20.0))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	b.add_theme_font_size_override("font_size", font_size)


# --- drawn helpers (call from a CanvasItem's _draw) ---

static func draw_pill(ci: CanvasItem, r: Rect2, bg: Color, border: Color = Color(0, 0, 0, 0)) -> void:
	var sb := box(bg, border, r.size.y, 1.0)
	ci.draw_style_box(sb, r)


static func draw_bar(ci: CanvasItem, r: Rect2, frac: float, fill: Color = ACCENT, track: Color = TRACK) -> void:
	var rad := r.size.y * 0.5
	ci.draw_style_box(box(track, Color(0, 0, 0, 0), rad / DESIGN_W * MOCK_W), r)
	var w := r.size.x * clampf(frac, 0.0, 1.0)
	if w > 0.0:
		var fr := Rect2(r.position, Vector2(maxf(w, r.size.y), r.size.y))
		ci.draw_style_box(box(fill, Color(0, 0, 0, 0), rad / DESIGN_W * MOCK_W), fr)


## Strike pip: outline when unused, filled crit when used.
static func draw_pip(ci: CanvasItem, center: Vector2, radius: float, used: bool) -> void:
	if used:
		ci.draw_circle(center, radius, CRIT)
	else:
		ci.draw_arc(center, radius - 1.0, 0.0, TAU, 24, PIP_LINE, 2.0, true)


static func draw_cog(ci: CanvasItem, c: Vector2, r: float, col: Color = TEXT_DIM) -> void:
	for i in 8:
		var a := TAU * float(i) / 8.0
		var d := Vector2.from_angle(a)
		ci.draw_line(c + d * r * 0.65, c + d * r, col, maxf(2.0, r * 0.3), true)
	ci.draw_arc(c, r * 0.68, 0.0, TAU, 24, col, maxf(2.0, r * 0.2), true)
	ci.draw_circle(c, r * 0.22, col)


static func draw_tick(ci: CanvasItem, c: Vector2, r: float, col: Color = TEXT, w: float = 3.0) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(-r, 0.0), c + Vector2(-r * 0.3, r * 0.7), c + Vector2(r, -r * 0.6)]), col, w, true)


static func draw_x(ci: CanvasItem, c: Vector2, r: float, col: Color = TEXT, w: float = 3.0) -> void:
	ci.draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, w, true)
	ci.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, w, true)


static func draw_magnifier(ci: CanvasItem, c: Vector2, r: float, col: Color = TEXT, w: float = 3.0) -> void:
	var lens := c + Vector2(-r * 0.15, -r * 0.15)
	ci.draw_arc(lens, r * 0.65, 0.0, TAU, 24, col, w, true)
	ci.draw_line(lens + Vector2(r * 0.46, r * 0.46), c + Vector2(r, r), col, w, true)


## dir: -1 = up, +1 = down.
static func draw_arrow(ci: CanvasItem, c: Vector2, r: float, dir: int, col: Color = TEXT) -> void:
	var d := float(dir)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, d * r), c + Vector2(-r, -d * r * 0.6), c + Vector2(r, -d * r * 0.6)]), col)


static func draw_wrench(ci: CanvasItem, c: Vector2, r: float, col: Color = TEXT, w: float = 3.0) -> void:
	ci.draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.3, -r * 0.3), col, w * 1.6, true)
	ci.draw_arc(c + Vector2(r * 0.45, -r * 0.45), r * 0.5, 0.0, TAU, 16, col, w, true)


static func draw_bolt(ci: CanvasItem, c: Vector2, r: float, col: Color = ACCENT) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.2, -r), c + Vector2(-r * 0.6, r * 0.1), c + Vector2(-r * 0.05, r * 0.1), c + Vector2(-r * 0.2, r), c + Vector2(r * 0.6, -r * 0.2), c + Vector2(r * 0.05, -r * 0.2)]), col)
