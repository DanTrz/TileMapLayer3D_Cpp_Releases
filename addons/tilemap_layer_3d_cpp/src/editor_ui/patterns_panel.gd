@tool
extends PanelContainer
class_name PatternsPanel

const PatternCardScene := preload("res://addons/tilemap_layer_3d_cpp/src/editor_ui/patterns_card.tscn")

signal add_pattern_requested
signal delete_pattern_requested(pattern_index: int)
signal pattern_selected(pattern_index: int)
signal pattern_unselected
## Asks the plugin to (lazily, cache-aware) produce a thumbnail for `pattern` and assign it to `card`.
signal request_pattern_thumbnail(pattern: TML3D_TilePattern, card: PatternCard)

var selected_card: PatternCard = null
var selected_pattern_index: int = -1
var card_list: Array[PatternCard] = []
var active_tile_map_layer3d: TileMapLayer3d_Cpp = null

@onready var cards_flow_container: HFlowContainer = %CardsFlowContainer
@onready var temp_debug_lbl: Label = %TEMP_DEBUG_LBL
@onready var add_pattern_button: Button = %AddPatternBtn
@onready var clear_pattern_selection_button: Button = %ClearPatternSelectionBtn

func _ready() -> void:
	if add_pattern_button and not add_pattern_button.pressed.is_connected(_on_add_pattern_pressed):
		add_pattern_button.pressed.connect(_on_add_pattern_pressed)
	reload_from_storage(active_tile_map_layer3d)

	resize_items()
	


func resize_items() -> void:
	var ui_scale: float = TML3D_GlobalUtil.get_editor_ui_scale()

	add_pattern_button.add_theme_font_size_override("font_size", int(10 * ui_scale))
	clear_pattern_selection_button.add_theme_font_size_override("font_size", int(10 * ui_scale))
	# preview_tex_rect.custom_minimum_size = Vector2(int(54 * ui_scale), int(54))

func set_active_tilemap_layer(tile_map_layer: TileMapLayer3d_Cpp) -> void:
	active_tile_map_layer3d = tile_map_layer
	reload_from_storage(active_tile_map_layer3d)

func reload_from_storage(tile_map_layer: TileMapLayer3d_Cpp = active_tile_map_layer3d) -> void:
	active_tile_map_layer3d = tile_map_layer
	_clear_all_cards()
	selected_card = null
	selected_pattern_index = -1

	var library: TML3D_TilePatternLibrary = _get_pattern_library()
	if library == null:
		_set_debug_text("")
		return

	var patterns: Array[TML3D_TilePattern] = library.get_patterns()
	for i: int in range(patterns.size()):
		var pattern: TML3D_TilePattern = patterns[i]
		if pattern == null:
			continue
		var card: PatternCard = PatternCardScene.instantiate()
		var display_name: String = pattern.pattern_name
		if display_name.is_empty():
			display_name = "Pattern %d" % (i + 1)
		# Card shows immediately with no thumbnail; the plugin fills it in lazily (cache-aware).
		card.setup(i, display_name, null)
		cards_flow_container.add_child(card)
		card_list.append(card)
		_wire_card(card)
		request_pattern_thumbnail.emit(pattern, card)

	_set_debug_text("%d pattern(s)" % card_list.size())

func clear_selection(emit_signal_requested: bool = true) -> void:
	for card: PatternCard in card_list:
		if is_instance_valid(card):
			card.set_selection(false)
	selected_card = null
	selected_pattern_index = -1
	_set_debug_text("Pattern Select")
	if emit_signal_requested:
		pattern_unselected.emit()

func _get_pattern_library() -> TML3D_TilePatternLibrary:
	if not active_tile_map_layer3d:
		return null
	var data: TML3D_TileMapLayerData = active_tile_map_layer3d.get_tile_map_data()
	if data == null:
		return null
	return data.patterns_library

func _wire_card(card: PatternCard) -> void:
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(_on_card_input.bind(card))
	card.delete_card.pressed.connect(_on_delete_card_pressed.bind(card))

func _clear_all_cards() -> void:
	if not cards_flow_container:
		return
	for child: Node in cards_flow_container.get_children():
		cards_flow_container.remove_child(child)
		child.queue_free()
	card_list.clear()

func _on_add_pattern_pressed() -> void:
	add_pattern_requested.emit()

func _on_card_input(event: InputEvent, card: PatternCard) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		select_card(card)

func _on_delete_card_pressed(card: PatternCard) -> void:
	if card and is_instance_valid(card):
		delete_pattern_requested.emit(card.pattern_index)

func select_card(card: PatternCard) -> void:
	if not card or not is_instance_valid(card):
		return

	if selected_card == card:
		clear_selection(true)
		return

	if selected_card and is_instance_valid(selected_card):
		selected_card.set_selection(false)

	selected_card = card
	selected_pattern_index = card.pattern_index
	card.set_selection(true)
	_set_debug_text(card.pattern_name)
	pattern_selected.emit(selected_pattern_index)

func _set_debug_text(value: String) -> void:
	if temp_debug_lbl:
		temp_debug_lbl.text = value
