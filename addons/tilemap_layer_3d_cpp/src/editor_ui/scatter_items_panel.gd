@tool
extends PanelContainer
class_name ScatterItemPanel

const ScatterItemScene: PackedScene = preload("res://addons/tilemap_layer_3d_cpp/src/editor_ui/scatter_item.tscn")

signal library_changed()
signal selection_changed(item_id: int)

@onready var add_button: Button = %AddScatterItemBtn
@onready var clear_button: Button = %ClearScatterBtn
@onready var items_flow: HFlowContainer = %ItemsFlowContainer

var active_tile_map_layer3d: TileMapLayer3d_Cpp = null
var _thumbnail_cache: Dictionary[String, Texture2D] = {}
var _queued_preview_keys: Dictionary[String, bool] = {}
var _thumbnail_revisions: Dictionary[int, int] = {}
var _definition_thumbnail_keys: Dictionary[int, String] = {}
var _connected_meshes: Dictionary[int, Mesh] = {}
var _connected_materials: Dictionary[int, Material] = {}


func _ready() -> void:
	add_button.pressed.connect(_on_add_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	# _create_mesh_dialog()
	resize_items() 
	

func resize_items() -> void:
	var ui_scale: float = TML3D_GlobalUtil.get_editor_ui_scale()
	add_button.add_theme_font_size_override("font_size", int(10 * ui_scale))
	clear_button.add_theme_font_size_override("font_size", int(10 * ui_scale))
	


func set_active_node(node: TileMapLayer3d_Cpp) -> void:
	_disconnect_definition_signals()
	_thumbnail_cache.clear()
	_queued_preview_keys.clear()
	_thumbnail_revisions.clear()
	_definition_thumbnail_keys.clear()
	active_tile_map_layer3d = node
	_ensure_library()
	reload_items()


func _disconnect_definition_signals() -> void:
	if not active_tile_map_layer3d or not active_tile_map_layer3d.tile_map_data or not active_tile_map_layer3d.tile_map_data.scatter_library:
		return
	for item: TML3D_ScatterItemDefinition in active_tile_map_layer3d.tile_map_data.scatter_library.items:
		if not item:
			continue
		_disconnect_item_signals(item)
	_connected_meshes.clear()
	_connected_materials.clear()


func _connect_item_signals(item: TML3D_ScatterItemDefinition) -> void:
	var definition_callback: Callable = _on_definition_changed.bind(item.item_id)
	if not item.changed.is_connected(definition_callback):
		item.changed.connect(definition_callback)
	_sync_preview_resource_signals(item)


func _disconnect_item_signals(item: TML3D_ScatterItemDefinition) -> void:
	var definition_callback: Callable = _on_definition_changed.bind(item.item_id)
	if item.changed.is_connected(definition_callback):
		item.changed.disconnect(definition_callback)
	var definition_id: int = item.get_instance_id()
	var resource_callback: Callable = _on_preview_resource_changed.bind(item.item_id)
	var mesh: Mesh = _connected_meshes.get(definition_id)
	if mesh and mesh.changed.is_connected(resource_callback):
		mesh.changed.disconnect(resource_callback)
	var material: Material = _connected_materials.get(definition_id)
	if material and material.changed.is_connected(resource_callback):
		material.changed.disconnect(resource_callback)
	_connected_meshes.erase(definition_id)
	_connected_materials.erase(definition_id)


func _sync_preview_resource_signals(item: TML3D_ScatterItemDefinition) -> void:
	var definition_id: int = item.get_instance_id()
	var resource_callback: Callable = _on_preview_resource_changed.bind(item.item_id)
	var old_mesh: Mesh = _connected_meshes.get(definition_id)
	if old_mesh != item.mesh:
		if old_mesh and old_mesh.changed.is_connected(resource_callback):
			old_mesh.changed.disconnect(resource_callback)
		if item.mesh:
			if not item.mesh.changed.is_connected(resource_callback):
				item.mesh.changed.connect(resource_callback)
			_connected_meshes[definition_id] = item.mesh
		else:
			_connected_meshes.erase(definition_id)
	var old_material: Material = _connected_materials.get(definition_id)
	if old_material != item.material_override:
		if old_material and old_material.changed.is_connected(resource_callback):
			old_material.changed.disconnect(resource_callback)
		if item.material_override:
			if not item.material_override.changed.is_connected(resource_callback):
				item.material_override.changed.connect(resource_callback)
			_connected_materials[definition_id] = item.material_override
		else:
			_connected_materials.erase(definition_id)


func _ensure_library() -> TML3D_ScatterItemLibrary:
	if not active_tile_map_layer3d:
		return null
	var data: TML3D_TileMapLayerData = active_tile_map_layer3d.tile_map_data
	if not data:
		data = active_tile_map_layer3d.create_tile_map_data()
	if not data.scatter_library:
		data.scatter_library = TML3D_ScatterItemLibrary.new()
	return data.scatter_library


func reload_items() -> void:
	if not is_node_ready():
		return
	for child: Node in items_flow.get_children():
		child.queue_free()
	var library: TML3D_ScatterItemLibrary = _ensure_library()
	if not library:
		return
	var selected_id: int = active_tile_map_layer3d.settings.selected_scatter_item_id if active_tile_map_layer3d.settings else -1
	for item: TML3D_ScatterItemDefinition in library.items:
		if not item:
			continue
		_connect_item_signals(item)
		var card: ScatterItem = ScatterItemScene.instantiate()
		items_flow.add_child(card)
		card.setup(item, _thumbnail_for(item), item.item_id == selected_id)
		card.selected.connect(_on_card_selected)
		card.activation_changed.connect(_on_card_activation_changed)
		card.delete_requested.connect(_on_card_delete_requested)


func get_active_items() -> Array[TML3D_ScatterItemDefinition]:
	var result: Array[TML3D_ScatterItemDefinition] = []
	var library: TML3D_ScatterItemLibrary = _ensure_library()
	if not library:
		return result
	for item: TML3D_ScatterItemDefinition in library.items:
		if item and item.paint_enabled:
			result.append(item)
	return result

func _on_add_pressed() -> void:
	if active_tile_map_layer3d:
		var mesh: QuadMesh = QuadMesh.new()
		if mesh:
			var library: TML3D_ScatterItemLibrary = _ensure_library()
			if not library:
				return
			var item := TML3D_ScatterItemDefinition.new()
			item.item_name = "NewScatterItem: " + str(items_flow.get_child_count())
			item.mesh = mesh
			var item_id: int = library.add_item(item)
			if active_tile_map_layer3d.settings:
				active_tile_map_layer3d.settings.selected_scatter_item_id = item_id
			library_changed.emit()
			reload_items.call_deferred()
			EditorInterface.edit_resource(item)

func _on_clear_pressed() -> void:
	if not active_tile_map_layer3d:
		return
	active_tile_map_layer3d.clear_all_scatter()
	library_changed.emit()
	print("TML3D: Scatter instances cleared")

func _thumbnail_for(item: TML3D_ScatterItemDefinition) -> Texture2D:
	if not item.mesh:
		return null
	var cache_key: String = _thumbnail_key(item)
	_definition_thumbnail_keys[item.get_instance_id()] = cache_key
	if _thumbnail_cache.has(cache_key):
		return _thumbnail_cache[cache_key]
	if _queued_preview_keys.has(cache_key):
		return null
	var preview_mesh: Mesh = item.mesh
	if item.material_override:
		preview_mesh = item.mesh.duplicate() as Mesh
		if not preview_mesh:
			return null
		for surface_index: int in preview_mesh.get_surface_count():
			preview_mesh.surface_set_material(surface_index, item.material_override)
	_queued_preview_keys[cache_key] = true
	EditorInterface.get_resource_previewer().queue_edited_resource_preview(preview_mesh,self,"_on_mesh_preview_ready",cache_key)
	return null


func _thumbnail_key(item: TML3D_ScatterItemDefinition) -> String:
	var definition_id: int = item.get_instance_id()
	var material_id: int = item.material_override.get_instance_id() if item.material_override else 0
	var revision: int = _thumbnail_revisions.get(definition_id, 0)
	return "%d:%d:%d:%d" % [definition_id, item.mesh.get_instance_id(), material_id, revision]


func _invalidate_thumbnail(item: TML3D_ScatterItemDefinition) -> void:
	var definition_id: int = item.get_instance_id()
	var old_key: String = _definition_thumbnail_keys.get(definition_id, "")
	if not old_key.is_empty():
		_thumbnail_cache.erase(old_key)
	_thumbnail_revisions[definition_id] = int(_thumbnail_revisions.get(definition_id, 0)) + 1
	_definition_thumbnail_keys.erase(definition_id)


func _on_mesh_preview_ready(_path: String,preview: Texture2D,thumbnail_preview: Texture2D,userdata: Variant) -> void:
	_apply_mesh_preview.call_deferred(str(userdata), preview, thumbnail_preview)


func _apply_mesh_preview(cache_key: String,preview: Texture2D,thumbnail_preview: Texture2D) -> void:
	_queued_preview_keys.erase(cache_key)
	var thumbnail: Texture2D = thumbnail_preview if thumbnail_preview else preview
	if not thumbnail:
		return
	var is_current: bool = false
	for child: Node in items_flow.get_children():
		var card: ScatterItem = child as ScatterItem
		if card and card.definition and card.definition.mesh:
			if _thumbnail_key(card.definition) == cache_key:
				card.set_thumbnail(thumbnail)
				is_current = true
	if is_current:
		_thumbnail_cache[cache_key] = thumbnail


func _on_card_selected(item_id: int) -> void:
	if not active_tile_map_layer3d or not active_tile_map_layer3d.settings:
		return
	active_tile_map_layer3d.settings.selected_scatter_item_id = item_id
	var library: TML3D_ScatterItemLibrary = _ensure_library()
	var item: TML3D_ScatterItemDefinition = library.get_item_by_id(item_id) if library else null
	if item:
		EditorInterface.edit_resource(item)
	selection_changed.emit(item_id)
	reload_items.call_deferred()


func _on_card_activation_changed(_item_id: int, _enabled: bool) -> void:
	library_changed.emit()


func _on_definition_changed(item_id: int) -> void:
	_apply_definition_changed.call_deferred(item_id)


func _apply_definition_changed(item_id: int) -> void:
	var library: TML3D_ScatterItemLibrary = _ensure_library()
	var item: TML3D_ScatterItemDefinition = library.get_item_by_id(item_id) if library else null
	if item:
		_sync_preview_resource_signals(item)
		_invalidate_thumbnail(item)
		var thumbnail: Texture2D = _thumbnail_for(item)
		for child: Node in items_flow.get_children():
			var card: ScatterItem = child as ScatterItem
			if card and card.definition == item:
				card.refresh_from_definition(thumbnail)
	library_changed.emit()


func _on_preview_resource_changed(item_id: int) -> void:
	_apply_preview_resource_changed.call_deferred(item_id)


func _apply_preview_resource_changed(item_id: int) -> void:
	var library: TML3D_ScatterItemLibrary = _ensure_library()
	var item: TML3D_ScatterItemDefinition = library.get_item_by_id(item_id) if library else null
	if not item or not item.mesh:
		return
	_invalidate_thumbnail(item)
	var thumbnail: Texture2D = _thumbnail_for(item)
	for child: Node in items_flow.get_children():
		var card: ScatterItem = child as ScatterItem
		if card and card.definition == item:
			card.set_thumbnail(thumbnail)


func _on_card_delete_requested(item_id: int) -> void:
	var library: TML3D_ScatterItemLibrary = _ensure_library()
	if not library:
		return
	var item: TML3D_ScatterItemDefinition = library.get_item_by_id(item_id)
	if item:
		_disconnect_item_signals(item)
		var definition_id: int = item.get_instance_id()
		var cache_key: String = _definition_thumbnail_keys.get(definition_id, "")
		if not cache_key.is_empty():
			_thumbnail_cache.erase(cache_key)
		_thumbnail_revisions.erase(definition_id)
		_definition_thumbnail_keys.erase(definition_id)
	if active_tile_map_layer3d:
		active_tile_map_layer3d.remove_scatter_instances_by_item_id(item_id)
	if not library.remove_item_by_id(item_id):
		return
	if active_tile_map_layer3d.settings and active_tile_map_layer3d.settings.selected_scatter_item_id == item_id:
		active_tile_map_layer3d.settings.selected_scatter_item_id = -1
	library_changed.emit()
	reload_items.call_deferred()
