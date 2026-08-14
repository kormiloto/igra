class_name SkyrollUI
extends RefCounted

const INK := Color("071426")
const PANEL := Color("0b1d36e8")
const PANEL_SOFT := Color("102a48d6")
const TEXT := Color("f5fbff")
const MUTED := Color("b9d1e7")
const GOLD := Color("ffd86b")
const CYAN := Color("75e6ff")
const CORAL := Color("ff7185")

static var _display_font: SystemFont
static var _body_font: SystemFont

static func display_font() -> Font:
	if _display_font == null:
		_display_font = SystemFont.new()
		_display_font.font_names = PackedStringArray(["Bahnschrift", "Aptos Display", "Segoe UI"])
		_display_font.font_weight = 700
		_display_font.allow_system_fallback = true
	return _display_font

static func body_font() -> Font:
	if _body_font == null:
		_body_font = SystemFont.new()
		_body_font.font_names = PackedStringArray(["Aptos", "Segoe UI", "Arial"])
		_body_font.font_weight = 500
		_body_font.allow_system_fallback = true
	return _body_font

static func panel_style(
	background: Color = PANEL,
	border: Color = Color("75e6ff55"),
	radius: int = 20,
	shadow_size: int = 14
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	style.shadow_color = Color("02081288")
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 6)
	return style

static func button_style(background: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color("02081266")
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 4)
	return style

static func apply_button(button: Button, accent: Color = CYAN, height: float = 58.0) -> void:
	button.custom_minimum_size.y = height
	button.add_theme_font_override("font", display_font())
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("8ba0b499"))
	button.add_theme_color_override("font_outline_color", Color("02081299"))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_stylebox_override("normal", button_style(Color("102a48e8"), Color(accent, 0.58)))
	button.add_theme_stylebox_override("hover", button_style(Color(accent, 0.30), accent))
	button.add_theme_stylebox_override("pressed", button_style(accent, Color.WHITE))
	button.add_theme_stylebox_override("focus", button_style(Color(accent, 0.24), Color.WHITE))
	button.add_theme_stylebox_override("disabled", button_style(Color("12223699"), Color("60738955")))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func apply_title(label: Label, size: int, color: Color = TEXT) -> void:
	label.add_theme_font_override("font", display_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("020812cc"))
	label.add_theme_constant_override("outline_size", maxi(4, size / 9))
	label.add_theme_constant_override("line_spacing", 2)

static func apply_body(label: Label, size: int = 19, color: Color = MUTED) -> void:
	label.add_theme_font_override("font", body_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("02081288"))
	label.add_theme_constant_override("outline_size", 2)

static func make_gradient(top: Color, bottom: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1280
	texture.height = 720
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

static func world_accent(world: int) -> Color:
	return [Color("7bf0b5"), Color("74dcff"), Color("ffba69")][clampi(world - 1, 0, 2)]

static func world_gradient(world: int) -> Array[Color]:
	return [
		[Color("0b2f36"), Color("10213c")],
		[Color("123f68"), Color("151d43")],
		[Color("682f46"), Color("1a1836")]
	][clampi(world - 1, 0, 2)]
