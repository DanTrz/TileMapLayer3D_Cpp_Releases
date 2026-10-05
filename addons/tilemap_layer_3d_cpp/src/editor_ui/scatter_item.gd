@tool
extends PanelContainer
class_name ScatterItem

signal selected(item_id: int)
signal activation_changed(item_id: int, enabled: bool)
signal delete_requested(item_id: int)

@onready var preview: TextureRect = %Preview
@onready var item_name_label: Label = %ItemName
@onready var delete_button: Button = %DeleteItem
@onready var enabled_check_box: CheckBox = %EnabledCheckBox

var definition: TML3D_ScatterItemDefinition = null
var _selected: bool = false
var _updating: bool = false


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	delete_button.pressed.connect(_on_delete_pressed)
	enabled_check_box.toggled.connect(_on_enabled_toggled)
	resize_items()


func resize_items() -> void:
	var ui_scale: float = TML3D_GlobalUtil.get_editor_ui_scale()
	self.custom_minimum_size = Vector2(64 * ui_scale, 64 * ui_scale)
	enabled_check_box.custom_maximum_size = Vector2(-1, 20 * ui_scale)#
	enabled_check_box.add_theme_font_size_override("font_size", int(8 * ui_scale))
	enabled_check_box.add_theme_constant_override("icon_max_width", int(8 * ui_scale))
	item_name_label.add_theme_font_size_override("font_size", int(8 * ui_scale))

	
func setup(item: TML3D_ScatterItemDefinition, thumbnail: Texture2D, selected_item: bool) -> void:
	definition = item
	_updating = true
	set_thumbnail(thumbnail)
	item_name_label.text = item.item_name
	enabled_check_box.button_pressed = item.paint_enabled
	_updating = false
	set_selected(selected_item)


func set_selected(value: bool) -> void:
	_selected = value
	modulate = Color(1.0, 1.0, 1.0, 1.0) if value else Color(0.82, 0.82, 0.82, 1.0)


func set_thumbnail(thumbnail: Texture2D) -> void:
	if not thumbnail:
		preview.texture = null
		return
	var thumb_img: Image = thumbnail.get_image()
	if thumb_img:
		preview.texture = ImageTexture.create_from_image(thumb_img)


func refresh_from_definition(thumbnail: Texture2D) -> void:
	if not definition:
		return
	_updating = true
	item_name_label.text = definition.item_name
	enabled_check_box.button_pressed = definition.paint_enabled
	set_thumbnail(thumbnail)
	_updating = false


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and definition:
		selected.emit(definition.item_id)


func _on_enabled_toggled(enabled: bool) -> void:
	if _updating or not definition:
		return
	definition.paint_enabled = enabled
	activation_changed.emit(definition.item_id, enabled)


func _on_delete_pressed() -> void:
	if definition:
		delete_requested.emit(definition.item_id)
