@tool
extends PanelContainer
class_name PatternCard

@export var pattern_name: String = ""
@export var preview_tex: Texture2D = null
@export var pattern_index: int = -1

@onready var preview_tex_rect: TextureRect = %Preview
@onready var name_label: Label = %PatternName
@onready var delete_card: Button = %DeleteCard

const _selected_color := Color(0.357, 0.561, 0.839)
const _unselected_color := Color(0.569, 0.569, 0.569, 0.0)
const _BASE_PREVIEW_SIZE := 54.0
const _BASE_CARD_SIZE := 72.0
var card_style_box: StyleBoxFlat

func _ready() -> void:
	_apply_display_data()
	var style_box: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	card_style_box = style_box.duplicate_deep()
	add_theme_stylebox_override("panel", card_style_box)
	set_selection(false)

	resize_items()

func resize_items() -> void:
	var ui_scale: float = TML3D_GlobalUtil.get_editor_ui_scale()
	var preview_size: int = int(round(_BASE_PREVIEW_SIZE * ui_scale))
	var card_size: int = int(round(_BASE_CARD_SIZE * ui_scale))

	name_label.add_theme_font_size_override("font_size", int(6 * ui_scale))
	preview_tex_rect.custom_minimum_size = Vector2(preview_size, preview_size)
	custom_minimum_size = Vector2(card_size, card_size)
	size = custom_minimum_size

func setup(index: int, display_name: String, texture: Texture2D = null) -> void:
	pattern_index = index
	pattern_name = display_name
	preview_tex = texture
	if is_node_ready():
		_apply_display_data()

func _apply_display_data() -> void:
	if name_label:
		name_label.text = pattern_name
	if preview_tex_rect:
		preview_tex_rect.texture = preview_tex

## Assigns the thumbnail after it is generated lazily (ephemeral; never serialized).
func set_preview_texture(texture: Texture2D) -> void:
	preview_tex = texture
	if is_node_ready() and preview_tex_rect:
		preview_tex_rect.texture = texture

	resize_items()

func set_selection(selected: bool) -> void:
	if not card_style_box:
		return
	if selected:
		card_style_box.border_color = _selected_color
	else:
		card_style_box.border_color = _unselected_color
