@tool
extends PanelContainer
class_name TML3D_AnimatedTileManager

## Animated-tile editor panel (C++ build). The headless anim WRITE path lives on
## TileMapLayer3d_Cpp (save_tile_info → _tile_anim_indices/_tile_anim_data); this panel
## only manages the animated-tile records in settings.animate_tiles_list + UI.

@onready var anim_tile_row: SpinBox = %AnimTileRow
@onready var anim_tile_col: SpinBox = %AnimTileCol
@onready var anim_tile_frames: SpinBox = %AnimTileFrames
@onready var anim_tile_speed: SpinBox = %AnimTileSpeed
@onready var anim_tile_display_name: LineEdit = %AnimTileDisplayName

@onready var create_anim_tile_button: Button = %CreateAnimTileButton
@onready var delete_anim_tile_button: Button = %DeleteAnimTileButton
@onready var anim_tile_items_list: ItemList = %AnimTileItemsList

## Emitted when user selects an AnimTile record, carrying the frame 0 tiles to auto-select
signal anim_tile_frame0_selected(tiles: Array[Rect2])

var selected_tiles: Array[Rect2] = []
var base_tile_size: Vector2 = Vector2.ZERO
var current_texture: Texture2D = null

var active_tile_map_layer3d: TileMapLayer3d_Cpp = null


func _ready() -> void:
	_connect_signals()
	_load_default_ui_values()


## Editor-only button theming (legacy GlobalUtil.apply_button_theme reimplemented locally).
func _apply_button_theme(button: Button, icon_name: String, size: float) -> void:
	if not Engine.is_editor_hint():
		return
	var ui_scale: float = TML3D_GlobalUtil.get_editor_ui_scale()
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	var icon_size: float = size * ui_scale
	button.custom_minimum_size = Vector2(icon_size, icon_size)
	button.add_theme_font_size_override("font_size", int(10 * ui_scale))
	if editor_theme and editor_theme.has_icon(icon_name, "EditorIcons"):
		button.icon = editor_theme.get_icon(icon_name, "EditorIcons")
	else:
		button.text = icon_name


func _load_default_ui_values() -> void:
	anim_tile_items_list.clear()
	anim_tile_row.value = 1
	anim_tile_col.value = 1
	anim_tile_frames.value = 1
	anim_tile_speed.value = 1.0
	anim_tile_display_name.text = "AnimTile Name..."

	var ui_scale: float = TML3D_GlobalUtil.get_editor_ui_scale()
	anim_tile_row.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))
	anim_tile_col.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))
	anim_tile_frames.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))
	anim_tile_speed.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))

	anim_tile_display_name.add_theme_font_size_override("font_size", int(10 * ui_scale))

	_apply_button_theme(create_anim_tile_button, "New", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)
	_apply_button_theme(delete_anim_tile_button, "Remove", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	anim_tile_items_list.add_theme_font_size_override("font_size", int(10 * ui_scale))


func _connect_signals() -> void:
	if not anim_tile_items_list.item_selected.is_connected(_on_anim_tile_selected):
		anim_tile_items_list.item_selected.connect(_on_anim_tile_selected)

	if not create_anim_tile_button.pressed.is_connected(_on_create_anim_tile_btn_pressed):
		create_anim_tile_button.pressed.connect(_on_create_anim_tile_btn_pressed)

	if not delete_anim_tile_button.pressed.is_connected(_on_delete_anim_tile_btn_pressed):
		delete_anim_tile_button.pressed.connect(_on_delete_anim_tile_btn_pressed)

	anim_tile_items_list.empty_clicked.connect(func(_pos: Vector2, _btn: int) -> void: set_anim_tile_selection(false))


## Resolves an ItemList UI index to the persistent dictionary key (item_id).
func _get_item_id_at(ui_index: int) -> int:
	if not active_tile_map_layer3d or not active_tile_map_layer3d.settings:
		return -1
	var keys: Array = active_tile_map_layer3d.settings.animate_tiles_list.keys()
	if ui_index < 0 or ui_index >= keys.size():
		return -1
	return keys[ui_index]


## Returns max(existing_keys) + 1 to avoid ID collisions after deletions.
func _generate_next_id(settings: TML3D_TileMapLayerSettings) -> int:
	if settings.animate_tiles_list.is_empty():
		return 0
	var max_id: int = 0
	for key: int in settings.animate_tiles_list.keys():
		if key > max_id:
			max_id = key
	return max_id + 1


func _tile_data_at(atlas: TileSetAtlasSource, coords: Vector2i) -> TileData:
	if not atlas or not atlas.has_tile(coords):
		return null
	return atlas.get_tile_data(coords, 0)


func _group_coords_from_rects(rects: Array[Rect2], source_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for rect: Rect2 in rects:
		var coords := TML3D_TileAtlasResolver.pixel_rect_to_atlas_coords(active_tile_map_layer3d, source_id, rect)
		if not TML3D_TileAtlasResolver.coords_match_registered_cell(active_tile_map_layer3d, source_id, coords, rect):
			return []
		result.append(coords)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)
	return result


func _packed_group(coords: Array[Vector2i]) -> PackedVector2Array:
	var result := PackedVector2Array()
	for coord: Vector2i in coords:
		result.append(Vector2(coord))
	return result


## Writes group identity only while a definition is created. Existing definitions are left
## untouched deliberately; recreating one is the compatibility-safe way to opt it in.
func _write_animated_group_metadata(anim_data: TML3D_AnimatedTileData) -> void:
	var tile_set: TileSet = active_tile_map_layer3d.get_tileset()
	var source_id: int = active_tile_map_layer3d.settings.active_source_id
	if not tile_set or not tile_set.has_source(source_id):
		push_warning("TML3D: AnimatedGroup metadata unavailable: active TileSet source was not found.")
		return

	TML3D_TileAtlasResolver.initialize_custom_data_for_tileset(tile_set)
	var group_layer_name := TML3D_GlobalConstants.get_CUSTOM_DATA_ANIMATED_GROUP()
	var group_layer_index := tile_set.get_custom_data_layer_by_name(group_layer_name)
	if group_layer_index < 0 or tile_set.get_custom_data_layer_type(group_layer_index) != TYPE_PACKED_VECTOR2_ARRAY:
		push_warning("TML3D: Animation definition created, but AnimatedGroup runtime controls are unavailable because the custom-data layer has an incompatible type.")
		return
	var atlas := tile_set.get_source(source_id) as TileSetAtlasSource
	if not atlas:
		push_warning("TML3D: AnimatedGroup metadata unavailable: active source is not a TileSetAtlasSource.")
		return

	# Animated remains the broad cell marker. Like CollectionTiles, every frame-zero member
	# receives the same AnimatedGroup array identifying the complete placed footprint.
	for rect: Rect2 in anim_data.selection_uv_rects:
		var coords := TML3D_TileAtlasResolver.pixel_rect_to_atlas_coords(active_tile_map_layer3d, source_id, rect)
		var tile_data := _tile_data_at(atlas, coords)
		if tile_data and TML3D_TileAtlasResolver.coords_match_registered_cell(active_tile_map_layer3d, source_id, coords, rect):
			tile_data.set_custom_data(TML3D_GlobalConstants.get_CUSTOM_DATA_ANIMATED(), true)

	var frame0_rects: Array[Rect2] = TML3D_GlobalUtil.get_anim_frame0_tiles(anim_data)
	var frame0_coords := _group_coords_from_rects(frame0_rects, source_id)
	if frame0_coords.is_empty() or frame0_coords.size() != frame0_rects.size():
		push_warning("TML3D: Animation definition created, but AnimatedGroup runtime controls are unavailable because one or more atlas cells could not be resolved.")
		tile_set.emit_changed()
		EditorInterface.set_object_edited(tile_set, true)
		return

	var group := _packed_group(frame0_coords)
	var conflicts: Array[PackedVector2Array] = []
	for coords: Vector2i in frame0_coords:
		var tile_data := _tile_data_at(atlas, coords)
		var existing: PackedVector2Array = tile_data.get_custom_data(group_layer_name)
		if not existing.is_empty() and existing != group and not conflicts.has(existing):
			conflicts.append(existing)

	# Remove every frame-zero member of each displaced group before assigning the new one.
	for old_group: PackedVector2Array in conflicts:
		for old_coord_value: Vector2 in old_group:
			var old_tile_data := _tile_data_at(atlas, Vector2i(old_coord_value))
			if old_tile_data:
				var current: PackedVector2Array = old_tile_data.get_custom_data(group_layer_name)
				if current == old_group:
					old_tile_data.set_custom_data(group_layer_name, PackedVector2Array())

	for coords: Vector2i in frame0_coords:
		_tile_data_at(atlas, coords).set_custom_data(group_layer_name, group)

	if not conflicts.is_empty():
		push_warning("TML3D: New AnimatedGroup metadata replaced %d overlapping group assignment(s)." % conflicts.size())
	tile_set.emit_changed()
	EditorInterface.set_object_edited(tile_set, true)


func on_tileset_selection_changed(selected_uv_tiles: Array[Rect2], _tile_size: Vector2, programmatically: bool) -> void:
	selected_tiles = selected_uv_tiles
	base_tile_size = _tile_size
	if not programmatically:
		set_anim_tile_selection(false)


func set_anim_tile_selection(selected: bool) -> void:
	if active_tile_map_layer3d and active_tile_map_layer3d.settings:
		active_tile_map_layer3d.settings.has_animated_tile_selected = selected
		if not selected:
			active_tile_map_layer3d.settings.active_animated_tile = -1
			deselect_all()


func load_animated_tile_settings(_current_texture: Texture2D, _default_idx_selected: int = 0) -> void:
	anim_tile_items_list.clear()

	if not active_tile_map_layer3d or not active_tile_map_layer3d.settings or not _current_texture:
		return

	current_texture = _current_texture
	var settings: TML3D_TileMapLayerSettings = active_tile_map_layer3d.settings

	for item_id: int in settings.animate_tiles_list.keys():
		var anim_data: TML3D_AnimatedTileData = settings.animate_tiles_list[item_id]

		var item_icon: Texture = null
		if _current_texture:
			if not anim_data.selection_uv_rects.is_empty():
				item_icon = TML3D_GlobalUtil.get_first_frame_texture(_current_texture, anim_data)

		anim_tile_items_list.add_item(anim_data.display_name, item_icon, true)

	if anim_tile_items_list.item_count > 0:
		var clamped_index: int = clampi(_default_idx_selected, 0, anim_tile_items_list.item_count - 1)
		anim_tile_items_list.select(clamped_index)
		var in_anim_mode: bool = (
			active_tile_map_layer3d != null and
			active_tile_map_layer3d.settings != null and
			active_tile_map_layer3d.settings.main_app_mode == TML3D_GlobalConstants.APP_ANIMATED_TILES
		)
		if in_anim_mode:
			_on_anim_tile_selected(clamped_index)


func _on_anim_tile_selected(selected_item_index: int) -> void:
	if not active_tile_map_layer3d:
		return
	var settings: TML3D_TileMapLayerSettings = active_tile_map_layer3d.settings
	if not settings:
		return
	var item_id: int = _get_item_id_at(selected_item_index)
	if item_id < 0:
		return
	if not settings.animate_tiles_list.has(item_id):
		push_warning("AnimatedTileManager: Animation ID not found in settings: " + str(item_id))
		return

	set_anim_tile_selection(true)
	var anim_data: TML3D_AnimatedTileData = settings.animate_tiles_list[item_id]
	if anim_data:
		settings.active_animated_tile = item_id
		anim_tile_row.value = anim_data.rows
		anim_tile_col.value = anim_data.columns
		anim_tile_frames.value = anim_data.frames
		anim_tile_speed.value = anim_data.speed
		anim_tile_display_name.text = anim_data.display_name

		var frame0_tiles: Array[Rect2] = TML3D_GlobalUtil.get_anim_frame0_tiles(anim_data)
		if not frame0_tiles.is_empty():
			anim_tile_frame0_selected.emit(frame0_tiles)


func _on_create_anim_tile_btn_pressed() -> void:
	if not active_tile_map_layer3d:
		return

	var settings: TML3D_TileMapLayerSettings = active_tile_map_layer3d.settings
	if not settings:
		return

	var new_anim_data: TML3D_AnimatedTileData = TML3D_AnimatedTileData.new()
	new_anim_data.item_id = _generate_next_id(settings)
	new_anim_data.display_name = "New AnimTile - ID: " + str(new_anim_data.item_id)
	new_anim_data.selection_uv_rects = selected_tiles.duplicate()
	new_anim_data.rows = int(anim_tile_row.value)
	# The runtime COLOR payload and existing undo representation both reserve one byte.
	# Clamp only newly created definitions so legacy resources keep their authored values.
	new_anim_data.columns = clampi(int(anim_tile_col.value), 1, 255)
	new_anim_data.frames = clampi(int(anim_tile_frames.value), 1, 255)
	new_anim_data.speed = anim_tile_speed.value
	new_anim_data.base_tile_size = base_tile_size
	new_anim_data.display_name = anim_tile_display_name.text

	settings.animate_tiles_list[new_anim_data.item_id] = new_anim_data
	_write_animated_group_metadata(new_anim_data)
	# Dictionary modified in-place so the setter never fires -- emit manually.
	settings.emit_changed()
	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()

	var new_index: int = settings.animate_tiles_list.size() - 1
	load_animated_tile_settings(current_texture, new_index)


func _on_delete_anim_tile_btn_pressed() -> void:
	if not active_tile_map_layer3d:
		return

	var settings: TML3D_TileMapLayerSettings = active_tile_map_layer3d.settings
	if not settings:
		return

	var selected_indices: PackedInt32Array = anim_tile_items_list.get_selected_items()
	if selected_indices.is_empty():
		return

	var selected_ui_index: int = selected_indices[0]
	var item_id: int = _get_item_id_at(selected_ui_index)
	if item_id < 0:
		return

	if settings.animate_tiles_list.has(item_id):
		var anim_data: TML3D_AnimatedTileData = settings.animate_tiles_list[item_id]
		var display_name: String = anim_data.display_name if anim_data else "ID:%d" % item_id
		push_warning("Deleting animation definition. Existing placed tiles keep their baked animation data: " + display_name)
		settings.animate_tiles_list.erase(item_id)
		anim_tile_items_list.remove_item(selected_ui_index)
		settings.emit_changed()
		if Engine.is_editor_hint():
			EditorInterface.mark_scene_as_unsaved()

	var new_select_index: int = maxi(selected_ui_index - 1, 0)

	if anim_tile_items_list.item_count > 0:
		load_animated_tile_settings(current_texture, new_select_index)
	else:
		_load_default_ui_values()
		settings.active_animated_tile = -1


func deselect_all() -> void:
	if not active_tile_map_layer3d:
		return
	anim_tile_items_list.deselect_all()
