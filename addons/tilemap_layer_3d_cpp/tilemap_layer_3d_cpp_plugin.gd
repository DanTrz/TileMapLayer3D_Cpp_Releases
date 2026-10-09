## Main plugin entry point and central coordinator for the C++ TileMapLayer3D build.
@tool
class_name TML3D_TileMapLayer3DPlugin
extends EditorPlugin

const TilesetPanelScene: PackedScene = preload("res://addons/tilemap_layer_3d_cpp/src/editor_ui/tileset_panel.tscn")
const PatternThumbnailRendererScript: GDScript = preload("res://addons/tilemap_layer_3d_cpp/src/editor_ui/pattern_thumbnail_renderer.gd")
const PATTERN_THUMBNAIL_SIZE: int = 64
const EditorShortcuts = preload("res://addons/tilemap_layer_3d_cpp/src/editor/tml3d_editor_shortcuts.gd")

var _ANIM_SUPPORTED_MESH_MODES: Array[int] = [
	TML3D_GlobalConstants.FLAT_SQUARE,
	TML3D_GlobalConstants.BOX_MESH,
	TML3D_GlobalConstants.PRISM_MESH,
	TML3D_GlobalConstants.AUTOSHAPE_MESH,
]

# --- Member Variables ---
var tileset_panel: TML3D_TilesetPanel = null
var _bottom_panel_button: Button = null

var editor_ui: TML3D_TileEditorUI = null
var placement_manager: TML3D_PlacementManager = null
var current_tile_map3d: TileMapLayer3d_Cpp = null
var tile_cursor: TML3D_TileCursor3D = null
var tile_preview: TML3D_TilePreview3D = null
var is_active: bool = false
var _shortcuts: EditorShortcuts = null

var selection_manager: TML3D_SelectionManager = null

# Autotile
var _autotile_engine: TML3D_AutotileEngine = null
var _autotile_extension: TML3D_AutotilePlacementExtension = null

# Sculpt / Smart Fill / Vertex
var _sculpt_gizmo_plugin: TML3D_TileMapLayerGizmoPlugin = null
var _sculpt_manager: TML3D_SculptManager = null
var _smart_fill_manager: TML3D_SmartFillManager = null
var _smart_selection_manager: TML3D_SmartSelectionManager = null
var _smart_pattern_manager: TML3D_SmartPatternManager = null
var _vertex_edit_manager: TML3D_VertexEditManager = null

var plugin_settings: TML3D_TilePlacerPluginSettings = null

signal auto_flip_requested(flip_state: bool)
signal tile_position_updated(world_pos: Vector3, grid_pos: Vector3, current_plane: int)

var _last_preview_update_time: float = 0.0
var _last_preview_screen_pos: Vector2 = Vector2.INF
var _last_preview_grid_pos: Vector3 = Vector3.INF
var _last_highlight_grid_pos: Vector3 = Vector3.INF
var _last_highlight_orientation: int = -1
var _last_highlight_is_multi: bool = false
var _last_highlight_rotation: int = -1
var _last_highlight_mirror: bool = false
var _last_highlight_selection_count: int = -1
var _last_highlight_selection_signature: String = ""
var _cached_local_mouse_pos: Vector2 = Vector2.ZERO

var _tile_stroke_active: bool = false
var _tile_stroke_is_erase: bool = false
## Upper bound on cells filled between two stroke samples. A fast drag spans a few cells; a larger
## jump is a camera move or viewport re-entry, where bridging would place a stray line of tiles.
const MAX_CROSSED_STROKE_CELLS: int = 64

var _last_stroke_position: Vector3 = Vector3.INF
var _last_mouse_action_time: float = 0.0

# Scatter stroke/hover state. Persistent instance mutation remains native; the editor plugin owns
# input sampling, surface reprojection, and one undo snapshot per stroke.
var _scatter_stroke_active: bool = false
var _scatter_stroke_is_right_click: bool = false
var _scatter_stroke_before: Dictionary = {}
var _scatter_last_dab_position: Vector3 = Vector3.INF

var area_fill_selector: TML3D_AreaFillSelector3D = null
var _area_fill_operator: TML3D_AreaFillOperator = null

var _tile_count_warning_shown: bool = false
var _last_tile_count: int = 0

# Ephemeral pattern card thumbnails — generated on demand, kept in memory only (never serialized),
# keyed by a stable content signature (pattern instances are re-copied on every add/delete).
var _pattern_thumbnail_cache: Dictionary[String, Texture2D] = {}


# --- Lifecycle ---

func _enter_tree() -> void:
	_shortcuts = EditorShortcuts.new(self)
	#print("TileMapLayer3D_Cpp Entered Tree")
	_sculpt_manager = TML3D_SculptManager.new()
	_sculpt_manager.sculpt_tiles_created.connect(_on_sculpt_tiles_created)
	_sculpt_manager.sculpt_erase_tiles_requested.connect(_on_sculpt_erase_tiles_requested)
	_smart_fill_manager = TML3D_SmartFillManager.new()
	_smart_fill_manager.tiles_place_requested.connect(_on_smart_tiles_place_requested)
	_smart_selection_manager = TML3D_SmartSelectionManager.new()
	_smart_selection_manager.tiles_place_requested.connect(_on_smart_tiles_place_requested)
	_smart_selection_manager.tiles_erase_requested.connect(_on_smart_tiles_erase_requested)
	_smart_selection_manager.selection_changed.connect(_on_smart_selection_changed)
	_smart_pattern_manager = TML3D_SmartPatternManager.new()
	_smart_pattern_manager.tiles_place_requested.connect(_on_smart_tiles_place_requested)
	_smart_pattern_manager.selected_pattern_changed.connect(_on_pattern_selection_changed)
	_smart_pattern_manager.library_changed.connect(_on_pattern_library_changed)
	_vertex_edit_manager = TML3D_VertexEditManager.new()
	_sculpt_gizmo_plugin = TML3D_TileMapLayerGizmoPlugin.new()
	_sculpt_gizmo_plugin.vertex_edit_manager = _vertex_edit_manager
	add_node_3d_gizmo_plugin(_sculpt_gizmo_plugin)

	plugin_settings = TML3D_TilePlacerPluginSettings.new()
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	plugin_settings.load_from_editor_settings(editor_settings)

	TML3D_TileEditorUI.apply_label_font_scale()

	tileset_panel = TilesetPanelScene.instantiate()
	_bottom_panel_button = add_control_to_bottom_panel(tileset_panel, "TileMapLayer3D_CPP")

	tileset_panel.tile_selected.connect(_on_tile_selected)
	tileset_panel.multi_tile_selected.connect(_on_multi_tile_selected)
	tileset_panel.tileset_loaded.connect(_on_tileset_loaded)
	tileset_panel.orientation_changed.connect(_on_orientation_changed)
	tileset_panel.placement_mode_changed.connect(_on_placement_mode_changed)
	tileset_panel.show_plane_grids_changed.connect(_on_show_plane_grids_changed)
	auto_flip_requested.connect(_on_auto_flip_requested)
	tileset_panel.box_z_fighting_changed.connect(_on_box_z_fighting_changed)
	tileset_panel.grid_size_changed.connect(_on_grid_size_changed)
	tileset_panel.texture_filter_changed.connect(_on_texture_filter_changed)
	tileset_panel.pixel_inset_changed.connect(_on_pixel_inset_changed)
	tileset_panel.create_collision_requested.connect(_on_create_collision_requested)
	tileset_panel.clear_collisions_requested.connect(_on_clear_collisions_requested)
	tileset_panel._bake_mesh_requested.connect(_on_bake_mesh_requested)
	tileset_panel.clear_tiles_requested.connect(_clear_all_tiles)
	tileset_panel.show_debug_info_requested.connect(_on_show_debug_info_requested)
	tileset_panel.autotile_tileset_changed.connect(_on_autotile_tileset_changed)
	tileset_panel.autotile_terrain_selected.connect(_on_autotile_terrain_selected)
	tileset_panel.autotile_data_changed.connect(_on_autotile_data_changed)
	tileset_panel.clear_tileset_requested.connect(_on_clear_tileset_requested)
	tileset_panel.add_pattern_requested.connect(_on_add_pattern_requested)
	tileset_panel.delete_pattern_requested.connect(_on_delete_pattern_requested)
	tileset_panel.pattern_selected.connect(_on_pattern_selected)
	tileset_panel.pattern_unselected.connect(_on_pattern_unselected)
	tileset_panel.request_pattern_thumbnail.connect(_on_request_pattern_thumbnail)
	tileset_panel.scatter_items_panel.library_changed.connect(_on_scatter_library_changed)

	editor_ui = TML3D_TileEditorUI.new()
	editor_ui.initialize(self)
	editor_ui.set_tileset_panel(tileset_panel)
	editor_ui._main_toolbar_scene.grid_snap_size_changed.connect(_on_grid_snap_size_changed)
	editor_ui._main_toolbar_scene.cursor_step_size_changed.connect(_on_cursor_step_size_changed)

	editor_ui.tiling_enabled_changed.connect(_on_tool_toggled)
	editor_ui.tilemap_main_mode_changed.connect(_on_tilemap_main_mode_changed)
	editor_ui.rotate_requested.connect(_on_editor_ui_rotate_requested)
	editor_ui.tilt_requested.connect(_on_editor_ui_tilt_requested)
	editor_ui.reset_requested.connect(_on_editor_ui_reset_requested)
	editor_ui.mirror_requested.connect(_on_editor_ui_mirror_requested)
	editor_ui.texture_rotation_requested.connect(_on_editor_ui_texture_rotation_requested)
	editor_ui.smart_select_operation_requested.connect(_on_editor_ui_smart_select_operation_requested)
	editor_ui._context_toolbar.mesh_mode_selection_changed.connect(_on_mesh_mode_selection_changed)
	editor_ui._context_toolbar.mesh_mode_depth_changed.connect(_on_mesh_mode_depth_changed)
	editor_ui._context_toolbar.arch_radius_ratio_changed.connect(_on_arch_radius_ratio_changed)
	editor_ui._context_toolbar.freeze_uv_changed.connect(_on_freeze_uv_changed)
	editor_ui._context_toolbar.paint_uv_only_changed.connect(_on_paint_uv_only_changed)
	editor_ui._context_toolbar.place_opposite_changed.connect(_on_place_opposite_changed)
	editor_ui._context_toolbar.smart_operations_mode_changed.connect(_on_smart_operations_mode_changed)
	editor_ui._context_toolbar.smart_select_additive_toggled.connect(_on_smart_select_additive_toggled)
	editor_ui.smart_select_mode_changed.connect(_on_smart_select_mode_changed)
	editor_ui._context_toolbar.sculp_brush_changed.connect(_on_sculp_mode_brush_changed)
	editor_ui._context_toolbar.sculp_mode_options_changed.connect(_on_sculp_mode_options_changed)
	editor_ui._context_toolbar.smart_fill_changed.connect(_on_smart_fill_changed)
	editor_ui.vertex_convert_requested.connect(_on_vertex_convert_requested)
	editor_ui.vertex_delete_requested.connect(_on_vertex_delete_requested)
	editor_ui._context_toolbar.texture_repeat_mode_changed.connect(_on_texture_repeat_mode_changed)
	editor_ui._context_toolbar.depth_growth_mode_changed.connect(_on_depth_growth_mode_changed)
	editor_ui._context_toolbar.scatter_detection_changed.connect(_on_scatter_detection_changed)
	editor_ui._context_toolbar.scatter_brush_changed.connect(_on_scatter_brush_changed)

	tile_position_updated.connect(editor_ui._context_toolbar.update_tile_position)

	TML3D_GlobalTileMapEvents.connect_request_sprite_mesh_creation(_on_request_sprite_mesh_creation)

	placement_manager = TML3D_PlacementManager.new()
	_vertex_edit_manager.set_placement_manager(placement_manager)

	selection_manager = TML3D_SelectionManager.new()
	selection_manager.selection_changed.connect(_on_selection_manager_changed)
	selection_manager.selection_cleared.connect(_on_selection_manager_cleared)

	tileset_panel.set_selection_manager(selection_manager)

	hide_bottom_panel_and_ui()


func _ready() -> void:
	set_process(false)


func _exit_tree() -> void:
	set_process(false)
	_shortcuts = null
	#print("TileMapLayer3D_Cpp Exited Tree")

	TML3D_GlobalTileMapEvents.disconnect_request_sprite_mesh_creation(_on_request_sprite_mesh_creation)

	if plugin_settings:
		var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
		plugin_settings.save_to_editor_settings(editor_settings)

	if tileset_panel:
		remove_control_from_bottom_panel(tileset_panel)
		tileset_panel.queue_free()
		tileset_panel = null

	if editor_ui:
		editor_ui.cleanup()
		editor_ui = null

	placement_manager = null

	if _sculpt_gizmo_plugin:
		remove_node_3d_gizmo_plugin(_sculpt_gizmo_plugin)
		_sculpt_gizmo_plugin = null
	if _sculpt_manager:
		_sculpt_manager.reset()
		_sculpt_manager = null
	if _smart_fill_manager:
		_smart_fill_manager.reset()
		_smart_fill_manager = null
	if _smart_selection_manager:
		_smart_selection_manager.set_active_node(null, null)
		_smart_selection_manager = null
	if _smart_pattern_manager:
		_smart_pattern_manager.set_active_node(null, null)
		_smart_pattern_manager = null

	_autotile_engine = null
	_autotile_extension = null

	#print("TileMapLayer3D (C++): Plugin disabled")


# --- Editor Integration ---

func _handles(object: Object) -> bool:
	return object is TileMapLayer3d_Cpp


func _edit(object: Object) -> void:
	#print("TileMapLayer3D_Cpp Handled Node/Object: " + str(object) + " Class: " + object.get_class())
	if _shortcuts:
		_shortcuts.reset_input()

	_clear_selection()
	_clear_selected_pattern(true)

	# Commit an open drag on the old node before switching.
	if _tile_stroke_active:
		_finish_tile_stroke()
	if _area_fill_operator:
		_area_fill_operator.reset_state()
	_invalidate_preview()

	if current_tile_map3d:
		current_tile_map3d.clear_highlights()
		current_tile_map3d.set_active_placement_manager(null)

	if current_tile_map3d and current_tile_map3d.settings:
		if current_tile_map3d.settings.changed.is_connected(_on_current_node_settings_changed):
			current_tile_map3d.settings.changed.disconnect(_on_current_node_settings_changed)

	if object is TileMapLayer3d_Cpp:
		current_tile_map3d = object

		if not current_tile_map3d.settings:
			current_tile_map3d.settings = TML3D_TileMapLayerSettings.new()
			if plugin_settings:
				current_tile_map3d.settings.tile_size = plugin_settings.default_tile_size
				current_tile_map3d.settings.picker_tile_size = plugin_settings.default_tile_size
				current_tile_map3d.settings.grid_size = plugin_settings.default_grid_size
				current_tile_map3d.settings.texture_filter_mode = plugin_settings.default_texture_filter
				current_tile_map3d.settings.enable_collision = plugin_settings.default_enable_collision
				current_tile_map3d.settings.alpha_threshold = plugin_settings.default_alpha_threshold
			_mark_scene_dirty()

		_set_current_mesh_mode(current_tile_map3d.settings.mesh_mode)
		_apply_autoshape_freeze_uv_rule(current_tile_map3d.settings.mesh_mode)

		show_bottom_panel_and_ui()

		if current_tile_map3d.settings.changed.is_connected(_on_current_node_settings_changed) == false:
			current_tile_map3d.settings.changed.connect(_on_current_node_settings_changed)

		placement_manager.set_active_tile_map_layer3d(current_tile_map3d)
		current_tile_map3d.set_active_placement_manager(placement_manager)
		placement_manager.set_grid_size(current_tile_map3d.settings.grid_size)
		placement_manager.set_grid_snap_size(current_tile_map3d.settings.grid_snap_size)

		var resolved_texture: Texture2D = TML3D_TileAtlasResolver.get_active_texture(current_tile_map3d)
		if resolved_texture:
			placement_manager.set_tileset_texture(resolved_texture)
			placement_manager.set_texture_filter(current_tile_map3d.settings.texture_filter_mode)

		placement_manager.set_current_mesh_rotation(current_tile_map3d.settings.current_mesh_rotation)
		placement_manager.set_is_current_texture_mirrored(current_tile_map3d.settings.get_is_texture_mirrored())
		placement_manager.set_current_texture_rotation(current_tile_map3d.settings.current_texture_rotation)
		placement_manager.set_current_depth_scale(current_tile_map3d.settings.current_depth_scale)
		placement_manager.set_current_texture_repeat_mode(current_tile_map3d.settings.texture_repeat_mode)
		placement_manager.set_current_depth_growth_mode(current_tile_map3d.settings.depth_growth_mode)
		placement_manager.set_current_freeze_uv(current_tile_map3d.settings.freeze_uv_on_rotation)

		if tileset_panel:
			tileset_panel.set_active_node(current_tile_map3d)
		if editor_ui:
			editor_ui.set_active_node(current_tile_map3d)
			_update_side_toolbar_status()
		if _sculpt_manager:
			_sculpt_manager.set_active_node(current_tile_map3d, placement_manager)
		if _smart_fill_manager:
			_smart_fill_manager.set_active_node(current_tile_map3d, placement_manager)
		if _smart_selection_manager:
			_smart_selection_manager.set_active_node(current_tile_map3d, placement_manager)
		if _smart_pattern_manager:
			_smart_pattern_manager.set_active_node(current_tile_map3d, placement_manager)
		if _sculpt_gizmo_plugin:
			_sculpt_gizmo_plugin.set_active_node(current_tile_map3d, _smart_fill_manager, _sculpt_manager)
			_sculpt_gizmo_plugin._undo_redo = get_undo_redo()
		if _vertex_edit_manager:
			_vertex_edit_manager.set_tile_map(current_tile_map3d)
			_vertex_edit_manager.rebuild_all_vertex_meshes()

		placement_manager.sync_from_tile_model()
		call_deferred("_setup_cursor")
		call_deferred("_setup_autotile_extension")
	else:
		if current_tile_map3d:
			current_tile_map3d.set_active_placement_manager(null)
		current_tile_map3d = null
		if tileset_panel:
			tileset_panel.set_active_node(null)
		if editor_ui:
			editor_ui.set_active_node(null)
		if _sculpt_manager:
			_sculpt_manager.set_active_node(null, null)
			_sculpt_manager.reset()
		if _smart_fill_manager:
			_smart_fill_manager.set_active_node(null, null)
		if _smart_selection_manager:
			_smart_selection_manager.set_active_node(null, null)
		if _smart_pattern_manager:
			_smart_pattern_manager.set_active_node(null, null)
		if _sculpt_gizmo_plugin:
			_sculpt_gizmo_plugin.set_active_node(null, null, null)
		if _vertex_edit_manager:
			_vertex_edit_manager.set_tile_map(null)
		_cleanup_cursor()
		hide_bottom_panel_and_ui()

func hide_bottom_panel_and_ui() -> void:
	if _bottom_panel_button:
		_bottom_panel_button.visible = false
	if editor_ui:
		editor_ui.set_ui_visible(false)

func show_bottom_panel_and_ui() -> void:
	if _bottom_panel_button:
		_bottom_panel_button.visible = true
	if tileset_panel:
		make_bottom_panel_item_visible(tileset_panel)
	if editor_ui:
		editor_ui.set_ui_visible(true)

func _setup_cursor() -> void:
	_cleanup_cursor()
	_remove_saved_cursors()

	tile_cursor = TML3D_TileCursor3D.new()
	tile_cursor.grid_size = _get_current_grid_size()
	if current_tile_map3d and current_tile_map3d.settings:
		tile_cursor.cursor_step_size = current_tile_map3d.settings.cursor_step_size
	tile_cursor.name = "TileCursor3D"
	if plugin_settings:
		tile_cursor.show_plane_grids = plugin_settings.show_plane_grids
	current_tile_map3d.add_child(tile_cursor)

	tile_preview = TML3D_TilePreview3D.new()
	tile_preview.grid_size = _get_current_grid_size()
	tile_preview.texture_filter_mode = placement_manager.get_texture_filter_mode()
	tile_preview.tile_model = current_tile_map3d
	_sync_tile_preview_from_settings()
	tile_preview.name = "TilePreview3D"
	current_tile_map3d.add_child(tile_preview)
	tile_preview.hide_preview()

	area_fill_selector = TML3D_AreaFillSelector3D.new()
	area_fill_selector.grid_size = _get_current_grid_size()
	area_fill_selector.name = "AreaFillSelector3D"
	current_tile_map3d.add_child(area_fill_selector)

	_area_fill_operator = TML3D_AreaFillOperator.new()
	_area_fill_operator.setup(area_fill_selector, placement_manager)
	_area_fill_operator.highlight_requested.connect(_on_highlight_tiles_in_area)
	_area_fill_operator.clear_highlights_requested.connect(_on_area_fill_clear_highlights)
	_area_fill_operator.out_of_bounds_warning.connect(_on_area_fill_out_of_bounds)

func _remove_saved_cursors() -> void:
	if not current_tile_map3d:
		return
	for child: Node in current_tile_map3d.get_children():
		if child is TML3D_TileCursor3D:
			child.queue_free()

func _setup_autotile_extension() -> void:
	if not current_tile_map3d or not placement_manager:
		return
	var resolved_tileset: TileSet = current_tile_map3d.get_tileset()
	if resolved_tileset == null and current_tile_map3d.settings:
		resolved_tileset = current_tile_map3d.settings.autotile_tileset
	# Set up even before the first terrain exists. Later TileSet edits rebuild this engine.
	_on_autotile_tileset_changed(resolved_tileset)

func _cleanup_cursor() -> void:
	if _shortcuts:
		_shortcuts.reset_input()
	if tile_cursor:
		if is_instance_valid(tile_cursor):
			tile_cursor.queue_free()
		tile_cursor = null

	if tile_preview:
		if is_instance_valid(tile_preview):
			tile_preview.queue_free()
		tile_preview = null

	if area_fill_selector:
		if is_instance_valid(area_fill_selector):
			area_fill_selector.queue_free()
		area_fill_selector = null

	_area_fill_operator = null

# --- Input Handling ---
func _process(delta: float) -> void:
	if _shortcuts:
		_shortcuts.process_cursor_movement(delta)

func _input(event: InputEvent) -> void:
	if _shortcuts and (_shortcuts.capture_mouse_release(event) or _shortcuts.can_handle_key_event(event)):
		get_viewport().set_input_as_handled()

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	#print("TileMapLayer3D (C++): _forward_3d_gui_input called")
	if _shortcuts and _shortcuts.handle_fast_move_mouse(camera, event):
		return AFTER_GUI_INPUT_STOP
	if not is_active or not current_tile_map3d:
		return AFTER_GUI_INPUT_PASS

	if event is InputEventMouse:
		_cached_local_mouse_pos = event.position

	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if _is_editor_viewport_navigation(motion_event.button_mask, motion_event.alt_pressed):
			return AFTER_GUI_INPUT_PASS
		_handle_mouse_motion(motion_event, camera)

	if event is InputEventMouseButton:
		return _handle_mouse_button_press(event as InputEventMouseButton, camera)

	return AFTER_GUI_INPUT_PASS

func _handle_mouse_button_press(event: InputEventMouseButton, camera: Camera3D) -> int:
	if _scatter_stroke_active and not event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		_finish_scatter_stroke()
		return AFTER_GUI_INPUT_STOP
	if event.alt_pressed:
		return AFTER_GUI_INPUT_PASS
	if _is_scatter_mode():
		var scatter_button: bool = event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT
		if not scatter_button:
			return AFTER_GUI_INPUT_PASS
		if event.pressed:
			_scatter_stroke_active = true
			_scatter_stroke_is_right_click = event.button_index == MOUSE_BUTTON_RIGHT
			_scatter_stroke_before = current_tile_map3d.capture_scatter_state()
			_scatter_last_dab_position = Vector3.INF
			_last_mouse_action_time = 0.0
			_apply_scatter_dab(camera, event.position, _scatter_stroke_is_right_click, event.shift_pressed, event.ctrl_pressed)
			return AFTER_GUI_INPUT_STOP
		if _scatter_stroke_active:
			_finish_scatter_stroke()
			return AFTER_GUI_INPUT_STOP
		return AFTER_GUI_INPUT_PASS

	var is_area_selecting: bool = _area_fill_operator and _area_fill_operator.is_selecting
	var is_left: bool = event.button_index == MOUSE_BUTTON_LEFT
	var is_right: bool = event.button_index == MOUSE_BUTTON_RIGHT
	var is_wheel_up: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
	var is_wheel_down: bool = event.button_index == MOUSE_BUTTON_WHEEL_DOWN

	if not (is_left or is_right or is_wheel_up or is_wheel_down):
		return AFTER_GUI_INPUT_PASS

	# SMART OPERATIONS
	if event.pressed and is_smart_operations_mode():
		if _is_pattern_placement_mode():
			if is_right:
				_clear_selected_pattern(true)
				return AFTER_GUI_INPUT_STOP
			if is_left:
				var target: Dictionary[Variant, Variant] = _get_mouse_grid_placement(camera, event.position)
				if not target.is_empty():
					_smart_pattern_manager.build_place_tile_list(target.grid_pos, target.orientation)
				return AFTER_GUI_INPUT_STOP
			return AFTER_GUI_INPUT_PASS
		if is_smart_fill_mode() and _smart_fill_manager:
			if is_left or is_right:
				_smart_fill_manager.handle_mouse_press(camera, event.position, event.button_index)
				current_tile_map3d.update_gizmos()
				return AFTER_GUI_INPUT_STOP
		if is_smart_select_mode() and _smart_selection_manager:
			if _smart_selection_manager.handle_mouse_press(camera, event.position, event.button_index):
				return AFTER_GUI_INPUT_STOP
			return AFTER_GUI_INPUT_PASS

	if not (is_left or is_right):
		return AFTER_GUI_INPUT_PASS

	# VERTEX EDIT
	if _is_vertex_edit_mode() and _vertex_edit_manager:
		if is_right:
			current_tile_map3d.clear_highlights()
			current_tile_map3d.smart_selected_tiles = PackedInt64Array()
			_vertex_edit_manager.deselect()
			current_tile_map3d.update_gizmos()
			return AFTER_GUI_INPUT_STOP

		if is_left:
			if event.pressed:
				if _vertex_edit_manager.get_selected_tile_key() != -1 and _vertex_edit_manager.begin_drag(camera, event.position):
					return AFTER_GUI_INPUT_STOP
				_handle_vertex_edit_click(camera, event.position)
				return AFTER_GUI_INPUT_STOP
			else:
				_finish_vertex_drag()
				return AFTER_GUI_INPUT_STOP

	# SCULPT
	if _is_sculpting_mode() and _sculpt_manager:
		if is_right and event.pressed:
			_sculpt_manager.reset()
			current_tile_map3d.update_gizmos()
			return AFTER_GUI_INPUT_STOP
		if is_left:
			if event.pressed:
				_sculpt_manager.on_mouse_press(camera, event.position)
			else:
				_sculpt_manager.on_mouse_release()
				current_tile_map3d.update_gizmos()
			return AFTER_GUI_INPUT_STOP

	# NORMAL PAINT
	var is_erase: bool = is_right
	## NORMAL PAINT - BUTTON PRESS HANDLER
	if event.pressed and not _is_sculpting_mode():
		if event.shift_pressed and _area_fill_operator and not _is_animated_tile_mode():
			if is_instance_valid(tile_cursor):
				_area_fill_operator.start(camera, event.position, is_erase, tile_cursor)
			return AFTER_GUI_INPUT_STOP

		_tile_stroke_active = true
		_tile_stroke_is_erase = is_erase
		_last_stroke_position = Vector3.INF
		_last_mouse_action_time = 0.0
		var action_name: String = "Paint Tiles"
		if is_erase:
			action_name = "Erase Tiles"
		elif _has_multi_tile_selection():
			action_name = "Paint Multi-Tiles"
		elif _is_paint_uv_only():
			action_name = "Paint UV Only"
		# The whole drag (press to release) becomes ONE undo entry.
		placement_manager.begin_drag_action()
		_handle_continues_tile_stroke(camera, event.position)
		return AFTER_GUI_INPUT_STOP
	## NORMAL PAINT - BUTTON RELEASED HANDLER
	else:
		#This is the Button Released Path, where the plugin closes the stroke or area fill operation.
		if is_area_selecting:
			_complete_area_fill()
			return AFTER_GUI_INPUT_STOP
		if _tile_stroke_active:
			_finish_tile_stroke()
			return AFTER_GUI_INPUT_STOP

	return AFTER_GUI_INPUT_PASS

func _handle_mouse_motion(event: InputEventMouseMotion, camera: Camera3D) -> void:
	if _is_scatter_mode():
		_update_scatter_hover(camera, event.position)
		if _scatter_stroke_active:
			var current_time: float = Time.get_ticks_msec() / 1000.0
			if current_time - _last_mouse_action_time >= TML3D_GlobalConstants.get_PAINT_UPDATE_INTERVAL():
				_apply_scatter_dab(camera, event.position, _scatter_stroke_is_right_click, event.shift_pressed, event.ctrl_pressed)
				_last_mouse_action_time = current_time
		return

	if _is_vertex_edit_mode():
		if _vertex_edit_manager and _vertex_edit_manager.is_dragging():
			_vertex_edit_manager.drag_to(camera, event.position)
			current_tile_map3d.update_gizmos()
		return

	var current_time: float = Time.get_ticks_msec() / 1000.0
	var is_area_selecting: bool = _area_fill_operator and _area_fill_operator.is_selecting

	if is_area_selecting and is_instance_valid(tile_cursor):
		_area_fill_operator.update(camera, event.position, tile_cursor)

	if not is_area_selecting:
		if current_time - _last_preview_update_time >= TML3D_GlobalConstants.get_PREVIEW_UPDATE_INTERVAL():
			var quick_result: Dictionary[Variant, Variant] = placement_manager.calculate_cursor_plane_placement(camera, event.position, tile_cursor.grid_position) if is_instance_valid(tile_cursor) else {}
			if not quick_result.is_empty():
				var grid_pos: Vector3 = quick_result.grid_pos
				if _should_update_preview(event.position, grid_pos):
					_update_preview(camera, event.position, false)
					_last_preview_update_time = current_time
					_last_preview_screen_pos = event.position
					_last_preview_grid_pos = grid_pos

	if is_smart_fill_mode() and _smart_fill_manager:
		if current_time - _last_mouse_action_time >= TML3D_GlobalConstants.get_PAINT_UPDATE_INTERVAL():
			_smart_fill_manager.handle_mouse_move(camera, event.position)
			current_tile_map3d.update_gizmos()
			_last_mouse_action_time = current_time
		return

	# Smart Select, Single Pick: a left-drag adds every tile the cursor passes over.
	if is_smart_select_mode() and not _is_pattern_placement_mode() and _smart_selection_manager and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if current_time - _last_mouse_action_time >= TML3D_GlobalConstants.get_PAINT_UPDATE_INTERVAL():
			_smart_selection_manager.handle_mouse_drag(camera, event.position)
			_last_mouse_action_time = current_time
		return

	if _is_sculpting_mode() and _sculpt_manager and _sculpt_gizmo_plugin and current_time - _last_mouse_action_time >= TML3D_GlobalConstants.get_PAINT_UPDATE_INTERVAL():
		var quick_result: Dictionary[Variant, Variant] = placement_manager.calculate_cursor_plane_placement(camera, event.position, tile_cursor.grid_position) if is_instance_valid(tile_cursor) else {}
		if not quick_result.is_empty():
			_sculpt_manager.update_brush_position(quick_result.grid_pos, current_tile_map3d.settings.grid_size, quick_result.orientation, current_tile_map3d.settings.grid_snap_size)
			_sculpt_manager.on_mouse_move(camera, event.position)
			if tile_cursor:
				tile_cursor.set_active_plane(quick_result.active_plane)
			current_tile_map3d.update_gizmos()
		_last_mouse_action_time = current_time
		return

	# No button held any more: the release was missed (e.g. outside the viewport), so close the drag.
	if _tile_stroke_active and event.button_mask == 0:
		_finish_tile_stroke()
		return

	if _tile_stroke_active and current_time - _last_mouse_action_time >= TML3D_GlobalConstants.get_PAINT_UPDATE_INTERVAL():
		_handle_continues_tile_stroke(camera, event.position)
		_last_mouse_action_time = current_time

func _handle_continues_tile_stroke(camera: Camera3D, screen_pos: Vector2) -> void:
	if not placement_manager or not _tile_stroke_active:
		return

	var target: Dictionary[Variant, Variant] = _get_mouse_grid_placement(camera, screen_pos)
	if target.is_empty():
		return
	var grid_pos: Vector3 = target.grid_pos
	var orientation: int = target.orientation

	if not TML3D_TileKeySystem.is_position_valid(grid_pos):
		if current_tile_map3d:
			current_tile_map3d.show_blocked_highlight(grid_pos, orientation)
		push_warning("TileMapLayer3D: Cannot place tile at position %s - outside valid range" % grid_pos)
		return

	if current_tile_map3d:
		current_tile_map3d.clear_blocked_highlight()

	if _last_stroke_position.distance_to(grid_pos) < TML3D_GlobalConstants.get_MIN_PAINT_GRID_DISTANCE():
		return
	# The cursor is only sampled every PAINT_UPDATE_INTERVAL, so a fast drag can jump several
	# cells between samples. Apply the selected action to the crossed cells so the stroke has no holes.
	for step_pos: Vector3 in _get_crossed_stroke_cells(_last_stroke_position, grid_pos):
		_apply_tile_action_at_cell(step_pos, orientation, _tile_stroke_is_erase)

	_apply_tile_action_at_cell(grid_pos, orientation, _tile_stroke_is_erase)

	_last_stroke_position = grid_pos
	_check_tile_count_warning()

func _finish_vertex_drag() -> void:
	if not _vertex_edit_manager or not _vertex_edit_manager.is_dragging():
		return
	var drag_result: Dictionary[Variant, Variant] = _vertex_edit_manager.end_drag()
	if not drag_result.is_empty() and drag_result["old_pos"] != drag_result["new_pos"]:
		var undo_redo: EditorUndoRedoManager = get_undo_redo()
		undo_redo.create_action("Move Vertex Corner", 0, current_tile_map3d)
		undo_redo.add_do_method(_vertex_edit_manager, "update_corner", drag_result["tile_key"], drag_result["handle"], drag_result["new_pos"])
		undo_redo.add_undo_method(_vertex_edit_manager, "update_corner", drag_result["tile_key"], drag_result["handle"], drag_result["old_pos"])
		undo_redo.add_do_method(current_tile_map3d, "update_gizmos")
		undo_redo.add_undo_method(current_tile_map3d, "update_gizmos")
		undo_redo.commit_action(false)

func _finish_tile_stroke() -> void:
	placement_manager.end_drag_action()
	_tile_stroke_active = false
	_tile_stroke_is_erase = false
	_mark_scene_dirty()

# --- Core Manual Placement Handlers ---
## Central method to paint the tile and apply actions at a certain grid cell (for a tile
## This method checks what type of Manual or Autotile placement is being used and calls their pipeline
func _apply_tile_action_at_cell(grid_pos: Vector3, orientation: int, is_erase: bool) -> void:
	if not TML3D_TileKeySystem.is_position_valid(grid_pos):
		return

	if is_erase:
		if _is_autotile_mode() and _is_paint_uv_only() and _autotile_extension:
			_remove_autotile_mark_from_tile(grid_pos, orientation)
			return
		_set_erase_tile_v2(grid_pos, orientation)
	else:

		## Step 1: Check what UI and Settings are active and store local state into variables and construct a TileInfo from settings/options. 
		var use_autotile: bool = _is_autotile_mode()
		if use_autotile:
			# An unconfigured terrain must not fall through to manual placement.
			if not _autotile_extension or not _autotile_extension.is_ready():
				return
			if _is_paint_uv_only():
				_mark_existing_tile_for_autotile(grid_pos, orientation)
				return
		var use_animated: bool = not use_autotile and _is_animated_tile_mode()
		var use_multi_tile: bool = not use_autotile and not use_animated and _has_multi_tile_selection()
		if not use_autotile and not use_animated and not use_multi_tile and _is_paint_uv_only():
			_replace_existing_tile_uv_from_selection(grid_pos, orientation)
			return

		# Every geometry placement mode starts with the same complete snapshot. 
		var tile: TML3D_PlacedTileInfo = placement_manager.create_tile_from_current_settings(grid_pos, orientation)

		## Step 2: Determine what mode is active and what pipeline to use. Autotile takes precedence over animated and multi-tile, which are mutually exclusive.
		if use_autotile:
			_set_autotile_v2(tile)
		elif use_animated:
			_set_animated_tile_v2(tile)
		elif use_multi_tile:
			_set_multi_tile_v2(tile)
		else:
			_set_manual_tile_v2(tile)

func _set_animated_tile_v2(tile: TML3D_PlacedTileInfo) -> void:
	if not current_tile_map3d.settings.has_animated_tile_selected:
		push_warning("Animated Tile Mode active: No animated tile selected.")
		return
	var anim_id: int = current_tile_map3d.settings.active_animated_tile
	if anim_id >= 0 and current_tile_map3d.settings.animate_tiles_list.has(anim_id):
		var anim: TML3D_AnimatedTileData = current_tile_map3d.settings.animate_tiles_list[anim_id]
		if not anim.selection_uv_rects.is_empty():
			var atlas_size: Vector2 = placement_manager.get_tileset_texture().get_size()
			var info: Dictionary[Variant, Variant] = TML3D_GlobalUtil.compute_anim_frame_info(anim, atlas_size)
			if info.is_empty():
				return
			# The current tile plus this animation's frame data.
			tile.anim_step_x = info["anim_step_x"]
			tile.anim_step_y = info["anim_step_y"]
			tile.anim_total_frames = anim.frames
			tile.anim_columns = anim.columns
			tile.anim_speed_fps = anim.speed
			# Animation supports FLAT_SQUARE / BOX / PRISM / AUTOSHAPE (front-face animation).
			# The dropdown is restricted to these in anim mode; guard defensively in case the
			# selected mode drifted, falling back to FLAT_SQUARE only when truly unsupported.
			if not _ANIM_SUPPORTED_MESH_MODES.has(tile.mesh_mode):
				tile.mesh_mode = TML3D_GlobalConstants.FLAT_SQUARE

			var tiles: Array[TML3D_PlacedTileInfo]= []
			if placement_manager.get_multi_tile_uv_selection().size() > 1:
				tiles = placement_manager.get_multi_tile_selection(tile)
			else:
				tiles.append(tile)

			placement_manager.place_tiles(tiles, "New AnimatedTile Multi-tile Placement", _resync_autotile_around_tiles, _is_place_opposite(), true, placement_manager.get_current_freeze_uv())
			

func _set_manual_tile_v2(tile: TML3D_PlacedTileInfo) -> void:
	var tiles: Array[TML3D_PlacedTileInfo]= []
	tiles.append(tile)

	# Handles Manual tile placement. The callback re-resolves autotile neighbours on do/undo/redo,
	placement_manager.place_tiles(tiles, "New Manual Placement", _resync_autotile_around_tiles, _is_place_opposite(), true, placement_manager.get_current_freeze_uv())

	_mark_scene_dirty()

# Single-click and drag erase, one cell at a time (ordinary or vertex tile).
func _set_erase_tile_v2(grid_pos: Vector3, orientation: int) -> void:
	var tile_key: int = TML3D_GlobalUtil.make_tile_key(grid_pos, orientation)
	var tile: TML3D_PlacedTileInfo = placement_manager.get_existing_tile_state(tile_key)

	if tile == null:
		return

	var tiles: Array[TML3D_PlacedTileInfo]= []
	tiles.append(tile)

	placement_manager.erase_tiles(tiles, "New Erase Tile", _resync_autotile_around_tiles, _is_place_opposite())
	_mark_scene_dirty()

func _set_autotile_v2(tile: TML3D_PlacedTileInfo) -> void:
	var grid_pos: Vector3 = tile.grid_position
	var orientation: int = tile.orientation
	var autotile_uv: Rect2 = _autotile_extension.get_autotile_uv(grid_pos, orientation)
	if not autotile_uv.has_area():
		return
	# Apply the terrain's UV, atlas cell, terrain id, mesh mode, and depth.
	var autotile_binding: Array[Variant] = _resolve_autotile_binding(autotile_uv)
	var tiles: Array[TML3D_PlacedTileInfo]= []
	tile.uv_rect = autotile_uv
	tile.atlas_source_id = autotile_binding[0]
	tile.atlas_coords = autotile_binding[1]
	tile.terrain_id = _get_autotile_terrain_id()
	if current_tile_map3d.settings:
		tile.mesh_mode = current_tile_map3d.settings.mesh_mode
		tile.depth_scale = current_tile_map3d.settings.current_depth_scale

	tiles.append(tile)
	var placed: bool = placement_manager.place_tiles(tiles, "New AutoTile Placement", _resync_autotile_around_tiles, _is_place_opposite(), false, placement_manager.get_current_freeze_uv())

	_mark_scene_dirty()

func _set_multi_tile_v2(tile: TML3D_PlacedTileInfo) -> void:
	var multi_selection: Array[TML3D_PlacedTileInfo] = placement_manager.get_multi_tile_selection(tile)
	placement_manager.place_tiles(multi_selection, "New Multi-tile Placement", _resync_autotile_around_tiles, _is_place_opposite(), true, placement_manager.get_current_freeze_uv())
	_mark_scene_dirty()

func _set_area_erase_v2(min_pos: Vector3, max_pos: Vector3, orientation: int) -> int:
	if not placement_manager:
		return -1

	var tiles: Array[TML3D_PlacedTileInfo] = placement_manager.get_tiles_in_area(min_pos, max_pos, orientation)
	if tiles.is_empty():
		return 0
	placement_manager.erase_tiles(tiles, "New Erase Area (%d tiles)" % tiles.size(), _resync_autotile_around_tiles, _is_place_opposite())
	return tiles.size()

func _refresh_autotile_neighbours(tiles: Array[TML3D_PlacedTileInfo]) -> void:
	for tile: TML3D_PlacedTileInfo in tiles:
		# if tile.terrain_id < 0:
		# 	continue
		_autotile_extension.on_tile_erased(tile.grid_position, tile.orientation, tile.terrain_id)
		_autotile_extension.on_tile_placed(tile.grid_position, tile.orientation)


# --- Preview and Highlighting ---
func _should_update_preview(screen_pos: Vector2, grid_pos: Vector3 = Vector3.INF) -> bool:
	if _last_preview_screen_pos != Vector2.INF:
		var screen_delta: float = screen_pos.distance_to(_last_preview_screen_pos)
		if screen_delta < TML3D_GlobalConstants.get_PREVIEW_MIN_MOVEMENT():
			return false

	if grid_pos != Vector3.INF and _last_preview_grid_pos != Vector3.INF:
		var grid_delta: float = grid_pos.distance_to(_last_preview_grid_pos)
		var snap_size: float = placement_manager.get_grid_snap_size() if placement_manager else 1.0
		var grid_threshold: float = snap_size * TML3D_GlobalConstants.get_PREVIEW_GRID_MOVEMENT_MULTIPLIER()
		if grid_delta < grid_threshold:
			return false

	return true

func _update_preview(camera: Camera3D, screen_pos: Vector2, force_update: bool = false) -> void:
	if not tile_preview or not is_instance_valid(tile_cursor) or not placement_manager.get_tileset_texture():
		return

	if current_tile_map3d and is_smart_select_mode() and not _is_pattern_placement_mode():
		tile_preview.hide_preview()
		return

	if not force_update:
		if not _should_update_preview(screen_pos):
			return

	_last_preview_screen_pos = screen_pos

	if TML3D_GlobalPlaneDetector.update_from_camera(camera):
		auto_flip_requested.emit(TML3D_GlobalPlaneDetector.determine_auto_flip_for_plane(TML3D_GlobalPlaneDetector.get_current_plane_6d()))

	var has_multi_selection: bool = not _is_autotile_mode() and _has_multi_tile_selection()
	var has_pattern_selection: bool = _is_pattern_placement_mode()
	var has_autotile_ready: bool = _is_autotile_mode() and _autotile_extension and _autotile_extension.is_ready()

	if _is_autotile_mode() and not has_autotile_ready:
		tile_preview.hide_preview()
		if current_tile_map3d:
			current_tile_map3d.clear_highlights()
		return

	if not has_pattern_selection and not has_multi_selection and not placement_manager.get_current_tile_uv().has_area() and not has_autotile_ready:
		tile_preview.hide_preview()
		if current_tile_map3d:
			current_tile_map3d.clear_highlights()
		return

	var preview_grid_pos: Vector3
	var preview_orientation: int = TML3D_GlobalPlaneDetector.get_current_tile_orientation_18d()

	var pmode: int = placement_manager.get_placement_mode()
	if has_pattern_selection:
		var target: Dictionary[Variant, Variant] = _get_mouse_grid_placement(camera, screen_pos)
		if target.is_empty():
			tile_preview.hide_preview()
			current_tile_map3d.clear_highlights()
			return
		preview_grid_pos = target.grid_pos
		preview_orientation = target.orientation
		tile_cursor.set_active_plane(TML3D_GlobalPlaneDetector.detect_active_plane_3d(camera))
	elif pmode == TML3D_PlacementManager.CURSOR_PLANE:
		var result: Dictionary[Variant, Variant] = placement_manager.calculate_cursor_plane_placement(camera, screen_pos, tile_cursor.grid_position)
		if result.is_empty():
			tile_preview.hide_preview()
			if current_tile_map3d:
				current_tile_map3d.clear_highlights()
			return
		preview_grid_pos = result.grid_pos
		preview_orientation = result.orientation
		if tile_cursor:
			tile_cursor.set_active_plane(result.active_plane)
	elif pmode == TML3D_PlacementManager.CURSOR:
		preview_grid_pos = _get_cursor_storage_position(camera)
	else: # RAYCAST
		var ray_result: Dictionary[Variant, Variant] = placement_manager._raycast_to_geometry(camera, screen_pos, tile_cursor.grid_position)
		if ray_result.is_empty():
			tile_preview.hide_preview()
			if current_tile_map3d:
				current_tile_map3d.clear_highlights()
			return
		var grid_coords: Vector3 = TML3D_GlobalUtil.world_to_grid(ray_result.position, placement_manager.get_grid_size())
		preview_grid_pos = placement_manager.snap_to_grid(grid_coords)

	var world_pos: Vector3 = _grid_to_absolute_world(preview_grid_pos)
	tile_position_updated.emit(world_pos, preview_grid_pos, TML3D_GlobalPlaneDetector.get_current_plane_6d())

	if not TML3D_TileKeySystem.is_position_valid(preview_grid_pos):
		if current_tile_map3d:
			current_tile_map3d.show_blocked_highlight(preview_grid_pos, preview_orientation)
		tile_preview.hide_preview()
		return

	if current_tile_map3d:
		current_tile_map3d.clear_blocked_highlight()

	if has_pattern_selection:
		var preview: Dictionary = _smart_pattern_manager.get_preview_data(preview_grid_pos, preview_orientation)
		if preview.is_empty():
			tile_preview.hide_preview()
			current_tile_map3d.clear_highlights()
			return
		if preview.get("mesh") != null:
			tile_preview.update_pattern_mesh_preview(preview.mesh, preview.material, preview.transform, true)
		else:
			tile_preview.update_pattern_preview(preview.tiles, placement_manager.get_tileset_texture(), true, preview.pool_limit)
		current_tile_map3d.highlight_tiles(preview.highlight_keys)
	elif has_multi_selection:
		var layout_rotation: int = TML3D_GlobalUtil.mesh_rotation_with_texture_turn(
			placement_manager.get_current_mesh_rotation(), placement_manager.get_current_texture_rotation_turn(),
			placement_manager.get_is_current_texture_mirrored())
		tile_preview.update_multi_preview(
			preview_grid_pos, _get_selected_tiles(), preview_orientation,
			placement_manager.get_current_preview_mesh_rotation(), placement_manager.get_tileset_texture(),
			placement_manager.get_is_current_texture_mirrored(), true,
			placement_manager.get_current_effective_uv_rotation(), layout_rotation)
	elif has_autotile_ready:
		var terrain_color: Color = _autotile_engine.get_terrain_color(_get_autotile_terrain_id())
		terrain_color.a = 0.7
		tile_preview.update_color_preview(
			preview_grid_pos, preview_orientation, terrain_color,
			placement_manager.get_current_mesh_rotation(),
			placement_manager.get_is_current_texture_mirrored(), true)
	else:
		tile_preview.update_preview(
			preview_grid_pos, preview_orientation, placement_manager.get_current_tile_uv(),
			placement_manager.get_tileset_texture(), placement_manager.get_current_preview_mesh_rotation(),
			placement_manager.get_is_current_texture_mirrored(), true, current_tile_map3d.enable_decal_mode,
			placement_manager.get_current_effective_uv_rotation())

	if not has_pattern_selection:
		_highlight_tiles_at_preview_position(preview_grid_pos, preview_orientation, has_multi_selection)

## Cells strictly between two sampled stroke positions, so a fast stroke stays continuous.
## Empty on the first sample of a stroke, when the gap is a single step, when the two samples are
## not on the same plane, or when the jump is too large to be a real drag (camera move, viewport
## re-entry). Both endpoints are already snapped by the caller, so intermediate positions are
## produced by stepping along the axes that actually changed - never by re-snapping, which would
## quantize the off-plane axis and push tiles onto a different plane.
func _get_crossed_stroke_cells(from_pos: Vector3, to_pos: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if from_pos == Vector3.INF or not placement_manager:
		return result
	if not current_tile_map3d or not current_tile_map3d.settings:
		return result

	var step: float = placement_manager.get_grid_size() * current_tile_map3d.settings.grid_snap_size
	if step <= 0.0:
		return result

	var delta: Vector3 = to_pos - from_pos
	# Steps per axis, as whole snap cells. A stroke stays on one plane, so the axis perpendicular
	# to it contributes 0 and is carried through unchanged.
	var sx: int = int(round(delta.x / step))
	var sy: int = int(round(delta.y / step))
	var sz: int = int(round(delta.z / step))
	var steps: int = max(max(abs(sx), abs(sy)), abs(sz))
	if steps <= 1 or steps > MAX_CROSSED_STROKE_CELLS:
		return result

	# Any leftover is sub-cell jitter within the same cell; ignore it so the walk stays exactly on
	# the lattice the endpoints already sit on.
	for i: int in range(1, steps):
		var t: float = float(i) / float(steps)
		result.append(Vector3(
			from_pos.x + float(int(round(float(sx) * t))) * step,
			from_pos.y + float(int(round(float(sy) * t))) * step,
			from_pos.z + float(int(round(float(sz) * t))) * step))
	return result


## Autotile "UV Only": repaint an EXISTING tile with the resolved autotile UV and mark it as
## belonging to the active terrain, without touching mesh mode, rotation, orientation, depth or
## any transform. Never creates geometry. Empty cells and unsupported (tilted) orientations no-op.
func _mark_existing_tile_for_autotile(grid_pos: Vector3, orientation: int) -> void:
	if not current_tile_map3d or not placement_manager:
		return
	var tile_key: int = TML3D_GlobalUtil.make_tile_key(grid_pos, orientation)
	# Paint-over only: never place a new tile, and never retarget a tile on a different plane.
	if not current_tile_map3d.has_tile(tile_key):
		return
	if _vertex_edit_manager and _vertex_edit_manager.is_vertex_tile(tile_key):
		return

	# Also covers the tilted-orientation skip: unsupported orientations resolve to an empty Rect2.
	var autotile_uv: Rect2 = _autotile_extension.get_autotile_uv(grid_pos, orientation)
	if not autotile_uv.has_area():
		return

	var new_terrain_id: int = _get_autotile_terrain_id()
	if new_terrain_id < 0:
		return

	var tile: TML3D_PlacedTileInfo = placement_manager.get_existing_tile_info(tile_key)
	if tile == null:
		return
	# Drag strokes re-fire over the same cell; skip no-op writes so undo stays clean.
	if tile.uv_rect == autotile_uv and tile.terrain_id == new_terrain_id:
		return

	# The existing tile with the terrain's UV and terrain id.
	# Mesh, orientation, rotation, depth, and transform stay as they are. A UV change makes it static.
	var binding: Array[Variant] = _resolve_autotile_binding(autotile_uv)
	tile.uv_rect = autotile_uv
	tile.atlas_source_id = binding[0]
	tile.atlas_coords = binding[1]
	tile.terrain_id = new_terrain_id
	_clear_tile_animation(tile)
	# The callback resolves this tile and its neighbours now that it counts as terrain.
	placement_manager.place_tiles([tile], "New Autotile UV Only Paint", _resync_autotile_around_tiles, false)
	_mark_scene_dirty()

## Erase counterpart for "UV Only": clears the terrain mark so the tile stops participating in
## autotile, but keeps the tile itself (mesh, orientation, rotation and current UV all intact).
func _remove_autotile_mark_from_tile(grid_pos: Vector3, orientation: int) -> void:
	if not current_tile_map3d or not placement_manager:
		return
	var tile_key: int = TML3D_GlobalUtil.make_tile_key(grid_pos, orientation)
	if not current_tile_map3d.has_tile(tile_key):
		return
	var tile: TML3D_PlacedTileInfo = placement_manager.get_existing_tile_info(tile_key)
	if tile == null or tile.terrain_id < 0:
		return

	# The same tile without its terrain mark.
	tile.terrain_id = TML3D_GlobalConstants.AUTOTILE_NO_TERRAIN
	# The callback re-resolves the neighbours now that this tile left the terrain.
	placement_manager.place_tiles([tile], "New Remove Autotile Mark", _resync_autotile_around_tiles, false)
	_mark_scene_dirty()

## place_tiles callback: re-resolves autotile tiles bordering the placed cells against the current map.
## Uses the engine directly because the extension is disabled outside autotile mode.
func _resync_autotile_around_tiles(tiles: Array[TML3D_PlacedTileInfo]) -> void:
	if not current_tile_map3d or not _autotile_extension:
		return
	var engine: TML3D_AutotileEngine = _autotile_extension.get_engine()
	if not engine or not engine.is_ready():
		return

	# Collect first, then write, so a neighbour shared by several cells is repainted once.
	var updates: Dictionary[int, Rect2] = {}
	for tile: TML3D_PlacedTileInfo in tiles:
		if tile == null or not TML3D_PlaneCoordinateMapper.is_supported_orientation(tile.orientation):
			continue
		var key: int = TML3D_GlobalUtil.make_tile_key(tile.grid_position, tile.orientation)
		# The cell itself resolves too, so an autotile area settles against the finished region.
		if current_tile_map3d.has_tile(key):
			var terrain: int = current_tile_map3d.get_tile_terrain_id(key)
			if terrain >= 0:
				var bitmask: int = engine.calculate_bitmask(tile.grid_position, tile.orientation, terrain, current_tile_map3d)
				var uv: Rect2 = engine.get_uv_for_bitmask(terrain, bitmask, engine.position_seed(tile.grid_position))
				if uv.has_area() and uv != current_tile_map3d.get_tile_uv_rect(key):
					updates[key] = uv
		var cell_updates: Dictionary = engine.update_neighbors(tile.grid_position, tile.orientation, current_tile_map3d)
		for nkey: int in cell_updates:
			updates[nkey] = cell_updates[nkey]
	if updates.is_empty():
		return

	for key: int in updates:
		_autotile_extension.update_tile_uv(key, updates[key])


## Manual-mode "Paint UV Only": repaint an EXISTING tile with the UV currently selected in the
## tileset panel, leaving mesh mode, rotation, orientation, depth and transform untouched.
## Never creates geometry. Multi-tile selections bypass this entirely (see _apply_tile_action_at_cell).
##
## Painting over an AUTOTILE tile converts it back to a plain manual tile: its terrain mark is
## cleared so the autotile engine stops owning it (otherwise the next neighbor refresh would
## overwrite the UV just painted), and its former neighbors are re-resolved into edge pieces.
func _replace_existing_tile_uv_from_selection(grid_pos: Vector3, orientation: int) -> void:
	if not current_tile_map3d or not placement_manager or not selection_manager:
		return
	var tile_key: int = TML3D_GlobalUtil.make_tile_key(grid_pos, orientation)
	# Paint-over only: never place a new tile, and never retarget a tile on a different plane.
	if not current_tile_map3d.has_tile(tile_key):
		return
	if _vertex_edit_manager and _vertex_edit_manager.is_vertex_tile(tile_key):
		return

	# Use the selection manager, NOT placement_manager.get_current_tile_uv(): the latter is only
	# refreshed for single-tile selections and goes stale once a multi-selection has been made.
	var new_uv: Rect2 = selection_manager.get_first_tile()
	if not new_uv.has_area():
		return

	var tile: TML3D_PlacedTileInfo = placement_manager.get_existing_tile_info(tile_key)
	if tile == null:
		return
	var old_terrain_id: int = tile.terrain_id
	var was_autotile: bool = old_terrain_id >= 0

	# Drag strokes re-fire over the same cell; compare against the tile's CURRENT state. A tile
	# whose UV already matches still needs converting if it is a leftover autotile tile.
	if tile.uv_rect == new_uv and not was_autotile:
		return

	# The existing tile with the selected UV. Painting over an
	# autotile tile also clears its terrain mark so the engine stops owning it. A UV change makes
	# the tile static.
	var binding: Array[Variant] = placement_manager.binding_for_uv_rect(new_uv)
	tile.uv_rect = new_uv
	tile.atlas_source_id = binding[0]
	tile.atlas_coords = binding[1]
	_clear_tile_animation(tile)
	tile.terrain_id = TML3D_GlobalConstants.AUTOTILE_NO_TERRAIN

	# The callback re-resolves former autotile neighbours; it skips itself when the engine is not ready.
	placement_manager.place_tiles([tile], "New UV Only Paint", _resync_autotile_around_tiles, false)
	_mark_scene_dirty()

func _check_tile_count_warning() -> void:
	if not current_tile_map3d or not placement_manager:
		return
	var total_tiles: int = current_tile_map3d.get_tile_count()
	var threshold: int = int(TML3D_GlobalConstants.MAX_RECOMMENDED_TILES * TML3D_GlobalConstants.get_TILE_COUNT_WARNING_THRESHOLD())
	var limit: int = TML3D_GlobalConstants.MAX_RECOMMENDED_TILES

	var was_over_limit: bool = _last_tile_count > limit
	var is_over_limit: bool = total_tiles > limit
	var was_over_threshold: bool = _last_tile_count >= threshold
	var is_over_threshold: bool = total_tiles >= threshold

	if was_over_limit != is_over_limit or was_over_threshold != is_over_threshold:
		current_tile_map3d.update_configuration_warnings()

	_last_tile_count = total_tiles

	if total_tiles < threshold:
		_tile_count_warning_shown = false
		return

	if not _tile_count_warning_shown:
		push_warning("TileMapLayer3D: Tile count (%d) at %.0f%% of recommended max (%d)." % [total_tiles, TML3D_GlobalConstants.get_TILE_COUNT_WARNING_THRESHOLD() * 100, TML3D_GlobalConstants.MAX_RECOMMENDED_TILES])
		_tile_count_warning_shown = true

# --- Signal Handlers - UI Events ---
func _on_tool_toggled(pressed: bool) -> void:
	is_active = pressed
	if not pressed and _shortcuts:
		_shortcuts.reset_input()

func _on_tile_selected(uv_rect: Rect2) -> void:
	if selection_manager:
		selection_manager.select([uv_rect], 0)
	if placement_manager:
		placement_manager.set_current_mesh_rotation(0)
		if current_tile_map3d and current_tile_map3d.settings:
			current_tile_map3d.settings.current_mesh_rotation = 0
	if tile_preview:
		tile_preview._hide_all_preview_instances()

func _on_multi_tile_selected(uv_rects: Array[Rect2], anchor_index: int) -> void:
	if _is_autotile_mode():
		return
	if selection_manager:
		selection_manager.select(uv_rects, anchor_index)
	if placement_manager:
		placement_manager.set_current_mesh_rotation(0)
		if current_tile_map3d and current_tile_map3d.settings:
			current_tile_map3d.settings.current_mesh_rotation = 0

func _on_tileset_loaded(texture: Texture2D) -> void:
	placement_manager.set_tileset_texture(texture)
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.tileset_texture = texture
		current_tile_map3d.apply_settings()
		current_tile_map3d.update_configuration_warnings()

func _on_orientation_changed(orientation: int) -> void:
	TML3D_GlobalPlaneDetector.set_current_tile_orientation_18d(orientation)

func _on_placement_mode_changed(mode: int) -> void:
	if _shortcuts:
		_shortcuts.reset_input()
	placement_manager.set_placement_mode(mode)
	if tile_cursor:
		tile_cursor.visible = (mode == 0 or mode == 1)

func _on_auto_flip_requested(_flip_state: bool) -> void:
	if not plugin_settings or not plugin_settings.enable_auto_flip:
		return
	if placement_manager:
		placement_manager.set_current_mesh_rotation(0)
		if current_tile_map3d and current_tile_map3d.settings:
			current_tile_map3d.settings.current_mesh_rotation = 0


# --- Pattern Fill presentation ---

func _on_add_pattern_requested() -> void:
	if _smart_pattern_manager:
		_smart_pattern_manager.add_pattern_from_selection()

func _on_delete_pattern_requested(pattern_index: int) -> void:
	if _smart_pattern_manager:
		_smart_pattern_manager.delete_pattern(pattern_index)

func _on_pattern_selected(pattern_index: int) -> void:
	if _smart_pattern_manager:
		_smart_pattern_manager.select_pattern(pattern_index)

func _on_pattern_unselected() -> void:
	_clear_selected_pattern(false)

func _clear_selected_pattern(sync_panel: bool) -> void:
	if _smart_pattern_manager:
		_smart_pattern_manager.clear_selection()
	if sync_panel and tileset_panel:
		tileset_panel.clear_patterns_selection(false)

func _on_pattern_selection_changed() -> void:
	if tileset_panel and _smart_pattern_manager and not _smart_pattern_manager.has_selected_pattern():
		tileset_panel.clear_patterns_selection(false)
	if tile_preview:
		tile_preview.hide_preview()
	if current_tile_map3d:
		current_tile_map3d.clear_highlights()
	_invalidate_preview()

func _on_pattern_library_changed() -> void:
	_pattern_thumbnail_cache.clear()
	if tileset_panel:
		tileset_panel.reload_patterns_panel()
	_mark_scene_dirty()

func get_pattern_thumbnail(pattern: TML3D_TilePattern) -> Texture2D:
	if pattern == null or not _smart_pattern_manager:
		return null
	var signature: String = _smart_pattern_manager.get_pattern_signature(pattern)
	if _pattern_thumbnail_cache.has(signature):
		return _pattern_thumbnail_cache[signature]
	var data: Dictionary = _smart_pattern_manager.get_pattern_mesh_data(pattern)
	if not data.get("success", false) or data.get("mesh") == null:
		return null
	var texture: Texture2D = await PatternThumbnailRendererScript.render(data.mesh, data.get("material"), PATTERN_THUMBNAIL_SIZE)
	if texture != null:
		_pattern_thumbnail_cache[signature] = texture
	return texture

func _on_request_pattern_thumbnail(pattern: TML3D_TilePattern, card: PatternCard) -> void:
	await get_tree().process_frame
	var texture: Texture2D = await get_pattern_thumbnail(pattern)
	if texture != null and is_instance_valid(card):
		card.set_preview_texture(texture)

# --- Selection Manager Handlers ---

func _on_selection_manager_changed(tiles: Array[Rect2], anchor: int) -> void:
	var bindings: Array[Variant] = _resolve_selection_bindings(tiles, current_tile_map3d)
	var source_ids: Array[int] = bindings[0]
	var coords_list: Array[Vector2i] = bindings[1]

	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.selected_tiles = tiles.duplicate()
		current_tile_map3d.settings.selected_atlas_coords = coords_list.duplicate()
		current_tile_map3d.settings.selected_anchor_index = anchor

	if placement_manager:
		if tiles.size() == 1:
			placement_manager.set_current_tile_uv(tiles[0])
			placement_manager.set_current_atlas_source_id(source_ids[0])
			placement_manager.set_current_atlas_coords(coords_list[0])
			placement_manager.set_multi_tile_selection([])
			placement_manager.set_multi_tile_atlas_source_ids(PackedInt32Array())
			placement_manager.set_multi_tile_atlas_coords([])
		else:
			placement_manager.set_multi_tile_selection(tiles.duplicate())
			placement_manager.set_multi_tile_atlas_source_ids(PackedInt32Array(source_ids))
			placement_manager.set_multi_tile_atlas_coords(coords_list.duplicate())


func _resolve_autotile_binding(autotile_uv: Rect2) -> Array[Variant]:
	var settings: TML3D_TileMapLayerSettings = current_tile_map3d.settings if current_tile_map3d else null
	if settings == null or not TML3D_TileAtlasResolver.is_valid_tileset(current_tile_map3d):
		return [-1, Vector2i(-1, -1)]
	var ts_size: Vector2i = TML3D_TileAtlasResolver.get_tile_size(current_tile_map3d)
	if ts_size.x <= 0 or ts_size.y <= 0:
		return [-1, Vector2i(-1, -1)]
	var src_id: int = settings.active_source_id
	var candidate: Vector2i = Vector2i(
		int(round(autotile_uv.position.x / float(ts_size.x))),
		int(round(autotile_uv.position.y / float(ts_size.y)))
	)
	if TML3D_TileAtlasResolver.coords_match_registered_cell(current_tile_map3d, src_id, candidate, autotile_uv):
		return [src_id, candidate]
	return [-1, Vector2i(-1, -1)]


func _resolve_selection_bindings(tiles: Array[Rect2], tile_map: TileMapLayer3d_Cpp) -> Array[Variant]:
	var source_ids: Array[int] = []
	var coords_list: Array[Vector2i] = []
	var settings: TML3D_TileMapLayerSettings = tile_map.settings if tile_map else null
	var src_id: int = settings.active_source_id if settings != null else -1
	var ts_size: Vector2i = TML3D_TileAtlasResolver.get_tile_size(tile_map)
	var has_valid_atlas: bool = TML3D_TileAtlasResolver.is_valid_tileset(tile_map) and ts_size.x > 0 and ts_size.y > 0
	for rect: Rect2 in tiles:
		var bound_src: int = -1
		var bound_coords: Vector2i = Vector2i(-1, -1)
		if has_valid_atlas:
			var col: int = int(round(rect.position.x / float(ts_size.x)))
			var row: int = int(round(rect.position.y / float(ts_size.y)))
			var candidate: Vector2i = Vector2i(col, row)
			if TML3D_TileAtlasResolver.coords_match_registered_cell(tile_map, src_id, candidate, rect):
				bound_src = src_id
				bound_coords = candidate
		source_ids.append(bound_src)
		coords_list.append(bound_coords)
	return [source_ids, coords_list]


func _on_selection_manager_cleared() -> void:
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.selected_tiles = []
		current_tile_map3d.settings.selected_atlas_coords = []
		current_tile_map3d.settings.selected_anchor_index = 0

	if placement_manager:
		placement_manager.set_current_tile_uv(Rect2())
		placement_manager.set_current_atlas_source_id(-1)
		placement_manager.set_current_atlas_coords(Vector2i(-1, -1))
		placement_manager.set_multi_tile_selection([])
		placement_manager.set_multi_tile_atlas_source_ids(PackedInt32Array())
		placement_manager.set_multi_tile_atlas_coords([])

	if tileset_panel:
		tileset_panel.tileset_display.clear_selection()
	if tile_preview:
		tile_preview.hide_preview()
		tile_preview._hide_all_preview_instances()

#---Sprite mesh handlers ----#
func _on_request_sprite_mesh_creation(current_texture: Texture2D, selected_tiles: Array[Rect2], tile_size: Vector2i, grid_size: float, filter_mode: int) -> void:
	if not current_tile_map3d or not tile_cursor:
		push_warning("No TileMapLayer3d_Cpp selected")
		return
	var sprite_mesh_instance: TML3D_SpriteMeshInstance = _generate_sprite_mesh_node(current_texture, selected_tiles, tile_size, grid_size)
	if not sprite_mesh_instance:
		push_warning("SpriteMeshGenerator: Failed to generate SpriteMeshInstance.")
		return

	var scene_root: Node = current_tile_map3d.get_tree().edited_scene_root
	_generate_sprite_mesh(sprite_mesh_instance, current_texture, filter_mode, current_tile_map3d)

	var first_rect: Rect2 = selected_tiles[0]
	var last_rect: Rect2 = selected_tiles[selected_tiles.size() - 1]
	var tiles_tall: int = int((last_rect.position.y - first_rect.position.y) / tile_size.y) + 1
	var total_height: float = tiles_tall * grid_size
	var local_position: Vector3 = tile_cursor.global_position - current_tile_map3d.global_position
	sprite_mesh_instance.position = Vector3(local_position.x, local_position.y + (total_height / 2.0), local_position.z)

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Create SpriteMesh")
	undo_redo.add_do_method(current_tile_map3d, "add_child", sprite_mesh_instance)
	undo_redo.add_do_method(sprite_mesh_instance, "set_owner", scene_root)
	undo_redo.add_undo_method(current_tile_map3d, "remove_child", sprite_mesh_instance)
	undo_redo.commit_action()


func _generate_sprite_mesh_node(current_texture: Texture2D, selected_tiles: Array[Rect2], tile_size: Vector2i, grid_size: float) -> TML3D_SpriteMeshInstance:
	if not current_texture or selected_tiles.is_empty() or tile_size.x <= 0 or tile_size.y <= 0:
		return null

	var first_rect: Rect2 = selected_tiles[0]
	var last_rect: Rect2 = selected_tiles[selected_tiles.size() - 1]
	var bounding_rect: Rect2 = Rect2(first_rect.position, last_rect.position + last_rect.size - first_rect.position)
	var tiles_wide: int = int((last_rect.position.x - first_rect.position.x) / tile_size.x) + 1
	var tiles_tall: int = int((last_rect.position.y - first_rect.position.y) / tile_size.y) + 1
	var selection_tile_size: Vector2 = Vector2(tiles_wide * grid_size, tiles_tall * grid_size)
	var total_tex_size: Vector2 = Vector2(bounding_rect.size)
	if total_tex_size.x <= 0 or total_tex_size.y <= 0:
		return null

	var region_texture: AtlasTexture = AtlasTexture.new()
	region_texture.atlas = current_texture
	region_texture.region = bounding_rect
	var sprite_mesh_instance: TML3D_SpriteMeshInstance = TML3D_SpriteMeshInstance.new()
	sprite_mesh_instance.atlas_texture = region_texture
	sprite_mesh_instance.pixel_size = selection_tile_size.x / total_tex_size.x
	sprite_mesh_instance.double_sided = true
	sprite_mesh_instance.depth = 5.0
	return sprite_mesh_instance


func _find_matching_sprite_mesh(parent_node: Node, texture: Texture2D, region_rect: Rect2i) -> TML3D_SpriteMesh:
	if not parent_node or not texture:
		return null

	var texture_path: String = texture.resource_path
	for child: Node in parent_node.get_children():
		if child is TML3D_SpriteMeshInstance:
			var existing: TML3D_SpriteMeshInstance = child
			if existing.spritemesh_texture and existing.spritemesh_texture.resource_path == texture_path:
				if existing.region_enabled and existing.region_rect == region_rect:
					if existing.generated_sprite_mesh and existing.generated_sprite_mesh.meshes.size() > 0:
						return existing.generated_sprite_mesh
	return null


func _generate_sprite_mesh(sprite_mesh_instance: TML3D_SpriteMeshInstance, atlas_texture: Texture2D, filter_mode: int, parent_node: Node) -> void:
	var existing_sprite_mesh: TML3D_SpriteMesh = _find_matching_sprite_mesh(parent_node, atlas_texture, sprite_mesh_instance.region_rect)
	if existing_sprite_mesh:
		sprite_mesh_instance.generated_sprite_mesh = existing_sprite_mesh
		return

	var sprite_mesh: TML3D_SpriteMesh = TML3D_SpriteMesh.new()
	sprite_mesh.meshes = TML3D_SpriteMeshGenerator.generate_frame_meshes(
		sprite_mesh_instance.spritemesh_texture,
		sprite_mesh_instance.depth,
		sprite_mesh_instance.pixel_size,
		sprite_mesh_instance.double_sided,
		sprite_mesh_instance.centered,
		sprite_mesh_instance.offset,
		sprite_mesh_instance.axis,
		sprite_mesh_instance.hframes,
		sprite_mesh_instance.vframes,
		sprite_mesh_instance.flip_h,
		sprite_mesh_instance.flip_v,
		sprite_mesh_instance.region_enabled,
		sprite_mesh_instance.region_rect,
		sprite_mesh_instance.alpha_threshold,
		sprite_mesh_instance.uv_correction,
		sprite_mesh_instance.texture_repeat
	)
	sprite_mesh.material = TML3D_SpriteMeshGenerator.get_or_create_material(atlas_texture, filter_mode)
	sprite_mesh_instance.generated_sprite_mesh = sprite_mesh


# --- Bake / Collision ---

func _on_create_collision_requested(bake_mode: int, backface_collision: bool, save_external_collision: bool) -> void:
	if not current_tile_map3d:
		push_warning("No TileMapLayer3d_Cpp selected")
		return
	if not current_tile_map3d.get_parent():
		push_error("TileMapLayer3d_Cpp has no parent node")
		return

	var regions: Array[Variant] = TML3D_TileMeshMerger.get_collision_regions(current_tile_map3d, true)
	if regions.is_empty():
		push_warning("[CollisionGen] No regions found.")
		return

	current_tile_map3d.clear_collision_shapes(Vector3i(2147483647, 2147483647, 2147483647))

	var options: TML3D_RegionBakeOptions = TML3D_RegionBakeOptions.new()
	options.alpha_aware = bake_mode == TML3D_GlobalConstants.BAKE_ALPHA_AWARE
	options.backface_collision = backface_collision
	options.attach_owner = current_tile_map3d.get_tree().edited_scene_root

	var baker: TML3D_RegionBaker = TML3D_RegionBaker.new()
	# Collect results keyed by request_id. Await BOTH bake_completed and bake_failed so a region
	# that produces no geometry (empty/edge/alpha) does NOT hang the loop. Completed-with-null and
	# failed are both "no shape" — skipped, not fatal.
	var results: Dictionary[int, Variant] = {}  # request_id -> shape (or null)
	var on_done: Callable = func(region_key: Vector3i, request_id: int, result: Variant) -> void:
		results[request_id] = result
	var on_failed: Callable = func(region_key: Vector3i, request_id: int, reason: String) -> void:
		results[request_id] = null
	baker.bake_completed.connect(on_done)
	baker.bake_failed.connect(on_failed)

	var request_ids: Array[int] = []
	for region_chunk: Variant in regions:
		request_ids.append(baker.bake_collision(current_tile_map3d, region_chunk, options))

	var pending: Array[Array] = []  # [shape, region_key] for the external .res save phase
	for i: int in range(request_ids.size()):
		var rid: int = request_ids[i]
		while not results.has(rid):
			await get_tree().process_frame
		var shape: Shape3D = results[rid]
		if shape != null:
			# take_over_path, not resource_path= : a stale .res from a previous generate is still
			# cached at this path, and the plain setter FAILS there (printing "Another resource is
			# loaded from path"), leaving the shape path-less so the scene embeds it as a sub_resource.
			if save_external_collision:
				var p: String = _collision_res_path_for(regions[i].region_key)
				if p != "":
					shape.take_over_path(p)
			pending.append([shape, regions[i].region_key])

	baker.bake_completed.disconnect(on_done)
	baker.bake_failed.disconnect(on_failed)

	if save_external_collision and not pending.is_empty():
		_save_collision_shapes(pending)

	# Collision shapes were added to the scene (owned by the scene root) — flag it for save.
	_mark_scene_dirty()


func _collision_res_path_for(region_key: Vector3i) -> String:
	var scene_path: String = current_tile_map3d.get_tree().edited_scene_root.scene_file_path
	if scene_path.is_empty():
		return ""
	var scene_name: String = scene_path.get_file().get_basename()
	var folder: String = scene_path.get_base_dir().path_join(scene_name + TML3D_GlobalConstants.get_SAVE_FOLDER_NAME())
	var suffix: String = "" if region_key == Vector3i(2147483647, 2147483647, 2147483647) \
		else "_%d_%d_%d" % [region_key.x, region_key.y, region_key.z]
	return folder.path_join("%s_%s_collision%s.res" % [scene_name, current_tile_map3d.name, suffix])


func _save_collision_shapes(pending: Array[Array]) -> void:
	var scene_path: String = current_tile_map3d.get_tree().edited_scene_root.scene_file_path
	if scene_path.is_empty():
		return
	var scene_name: String = scene_path.get_file().get_basename()
	var folder: String = scene_path.get_base_dir().path_join(scene_name + TML3D_GlobalConstants.get_SAVE_FOLDER_NAME())
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)

	# Serial on the main thread: ResourceSaver.save mutates the global resource cache, registers
	# UIDs and notifies EditorFileSystem. Running it from N WorkerThreadPool threads races all
	# three. No delete-before-save either — that left the cache entry bound to a deleted file.
	var saved_paths: PackedStringArray = []
	for entry: Array[Variant] in pending:
		var shape: Shape3D = entry[0]
		var region_key: Vector3i = entry[1]
		var path: String = _collision_res_path_for(region_key)
		if path == "":
			continue
		if shape.resource_path != path:
			shape.take_over_path(path)
		var err: int = ResourceSaver.save(shape, path, ResourceSaver.FLAG_CHANGE_PATH)
		if err != OK:
			push_warning("TML3D: collision save failed | path=%s | err=%d" % [path, err])
			continue
		saved_paths.append(path)

	if Engine.is_editor_hint() and saved_paths.size() > 0:
		var efs: EditorFileSystem = EditorInterface.get_resource_filesystem()
		for path: String in saved_paths:
			efs.update_file(path)
	print("TML3D: collision external save | saved=", saved_paths.size(), "/", pending.size())


func _on_clear_collisions_requested() -> void:
	if not current_tile_map3d:
		push_warning("No TileMapLayer3d_Cpp selected")
		return
	current_tile_map3d.clear_collision_shapes()  # also resets the node's cached body ref (full-map clear)
	_free_collision_bodies()
	# queue_free is deferred — let the frees land before evicting the cache entries, or the
	# shape nodes still hold references and the files get written straight back on next save.
	await get_tree().process_frame
	if not is_instance_valid(current_tile_map3d):
		return
	_delete_all_collision_res_files()
	_mark_scene_dirty()  # clearing collision must flag the scene as needing save
	#print("All collision shapes cleared from: ", current_tile_map3d.name)


func _free_collision_bodies() -> void:
	# Snapshot children first — queue_free defers, but avoid iterating a live child list.
	var bodies: Array[TML3D_StaticCollisionBody3D] = []
	for child: Node in current_tile_map3d.get_children():
		if child is TML3D_StaticCollisionBody3D:
			bodies.append(child)
	for body: TML3D_StaticCollisionBody3D in bodies:
		body.queue_free()


func _delete_all_collision_res_files() -> void:
	var scene_path: String = current_tile_map3d.get_tree().edited_scene_root.scene_file_path
	if scene_path.is_empty():
		return
	var scene_name: String = scene_path.get_file().get_basename()
	var folder: String = scene_path.get_base_dir().path_join(scene_name + TML3D_GlobalConstants.get_SAVE_FOLDER_NAME())
	var dir: DirAccess = DirAccess.open(folder)
	if not dir:
		return
	# Collect first, then delete — never mutate the directory mid-iteration.
	var prefix: String = scene_name + "_" + current_tile_map3d.name + "_collision"
	var targets: PackedStringArray = []
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if filename.begins_with(prefix) and filename.ends_with(".res"):
			targets.append(filename)
		filename = dir.get_next()
	dir.list_dir_end()

	var removed: int = 0
	for target_name: String in targets:
		var path: String = folder.path_join(target_name)
		# Unbind the cached resource BEFORE deleting, or the editor still holds it at this path
		# and the next scene save writes the file straight back.
		if ResourceLoader.has_cached(path):
			var cached: Resource = ResourceLoader.load(path)
			if cached:
				cached.take_over_path("")
		var err: int = dir.remove(target_name)
		if err != OK:
			push_warning("TML3D: collision .res delete failed | path=%s | err=%d" % [path, err])
			continue
		removed += 1
		if FileAccess.file_exists(path + ".uid"):
			dir.remove(target_name + ".uid")

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	print("TML3D: collision .res delete | removed=", removed, "/", targets.size(), " | folder=", folder)


func _on_bake_mesh_requested(bake_mode: int, include_sprite_meshes: bool) -> void:
	if not Engine.is_editor_hint(): return
	if not current_tile_map3d:
		push_error("No TileMapLayer3d_Cpp selected for merge bake")
		return
	var parent: Node = current_tile_map3d.get_parent()
	if not parent:
		push_error("TileMapLayer3d_Cpp has no parent node")
		return

	var options: TML3D_RegionBakeOptions = TML3D_RegionBakeOptions.new()
	options.alpha_aware = bake_mode == TML3D_GlobalConstants.BAKE_ALPHA_AWARE
	# Visual mesh bake must include EVERY tile. respect_collision_custom_data (default true)
	# is a COLLISION-generation filter that drops tiles whose "collision" custom-data is false
	# (e.g. decoration like grass); applying it to the visual bake wrongly hides those tiles.
	# Collision generation keeps the default; only this visual bake opts out.
	options.respect_collision_custom_data = false
	options.include_sprite_meshes = include_sprite_meshes

	var baker: TML3D_RegionBaker = TML3D_RegionBaker.new()
	baker.bake_mesh(current_tile_map3d, null, options)
	var res: Array[Variant] = await baker.bake_completed
	var mesh_instance: MeshInstance3D = res[2]
	if mesh_instance == null:
		push_error("Bake TileMapLayer3d_Cpp failed")
		return

	mesh_instance.name = current_tile_map3d.name + "_Baked"
	mesh_instance.transform = current_tile_map3d.transform

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Bake TileMapLayer3D to Static Mesh")
	undo_redo.add_do_method(parent, "add_child", mesh_instance)
	undo_redo.add_do_method(mesh_instance, "set_owner", parent.get_tree().edited_scene_root)
	undo_redo.add_do_property(mesh_instance, "name", mesh_instance.name)
	undo_redo.add_undo_method(parent, "remove_child", mesh_instance)
	undo_redo.commit_action()


# --- Clear and Debug Operations ---

func _clear_all_tiles() -> void:
	if not current_tile_map3d:
		push_warning("No TileMapLayer3d_Cpp selected")
		return
	var confirm_dialog: ConfirmationDialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Clear all tiles from '%s'?\n\nThis action cannot be undone." % current_tile_map3d.name
	confirm_dialog.title = "Clear All Tiles"
	confirm_dialog.confirmed.connect(_do_clear_all_tiles)
	EditorInterface.get_base_control().add_child(confirm_dialog)
	confirm_dialog.popup_centered()
	confirm_dialog.visibility_changed.connect(func():
		if not confirm_dialog.visible:
			confirm_dialog.queue_free())


func _do_clear_all_tiles() -> void:
	if not current_tile_map3d:
		return
	if _vertex_edit_manager:
		_vertex_edit_manager.clear_all_vertex_tiles()
	if current_tile_map3d:
		current_tile_map3d.smart_selected_tiles = PackedInt64Array()
		current_tile_map3d.clear_highlights()
	current_tile_map3d.clear_all_tiles()
	current_tile_map3d.clear_runtime_chunks()
	current_tile_map3d.clear_collision_shapes()
	current_tile_map3d.notify_property_list_changed()


func _on_show_debug_info_requested() -> void:
	TML3D_DebugInfoGenerator.print_report(current_tile_map3d, placement_manager)


# --- Settings Handlers ---

func _on_show_plane_grids_changed(enabled: bool) -> void:
	if tile_cursor:
		tile_cursor.show_plane_grids = enabled
	if plugin_settings:
		plugin_settings.show_plane_grids = enabled

func _on_cursor_step_size_changed(step_size: float) -> void:
	if tile_cursor:
		tile_cursor.cursor_step_size = step_size
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.cursor_step_size = step_size

func _on_grid_snap_size_changed(snap_size: float) -> void:
	if placement_manager:
		placement_manager.set_grid_snap_size(snap_size)
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.grid_snap_size = snap_size

func _apply_autoshape_freeze_uv_rule(mesh_mode: int) -> void:
	if mesh_mode != TML3D_GlobalConstants.AUTOSHAPE_MESH:
		return
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.freeze_uv_on_rotation = false
	if placement_manager:
		placement_manager.set_current_freeze_uv(false)
	if editor_ui and editor_ui._context_toolbar:
		editor_ui._context_toolbar.set_freeze_uv(false)

func _on_mesh_mode_selection_changed(mesh_mode: int) -> void:
	if current_tile_map3d:
		_set_current_mesh_mode(mesh_mode)
		current_tile_map3d.settings.mesh_mode = mesh_mode
	_apply_autoshape_freeze_uv_rule(mesh_mode)
	if tile_preview and not _is_autotile_mode():
		tile_preview.current_mesh_mode = mesh_mode
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			_update_preview(camera, get_viewport().get_mouse_position())

func _on_mesh_mode_depth_changed(depth: float) -> void:
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.current_depth_scale = depth
	if not _is_autotile_mode() and placement_manager:
		placement_manager.set_current_depth_scale(depth)
	if not _is_autotile_mode() and tile_preview:
		tile_preview.current_depth_scale = depth
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			_update_preview(camera, get_viewport().get_mouse_position())

func _on_arch_radius_ratio_changed(ratio: float) -> void:
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.arch_radius_ratio = ratio
		current_tile_map3d.rebuild_arch_chunk_meshes()
	if tile_preview:
		tile_preview.current_arch_radius_ratio = ratio
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			_update_preview(camera, get_viewport().get_mouse_position())

func _on_texture_repeat_mode_changed(mode: int) -> void:
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.texture_repeat_mode = mode
	if placement_manager:
		placement_manager.set_current_texture_repeat_mode(mode)

func _on_depth_growth_mode_changed(mode: int) -> void:
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.depth_growth_mode = mode
	if placement_manager:
		placement_manager.set_current_depth_growth_mode(mode)
	if tile_preview:
		tile_preview.current_depth_growth_mode = mode
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			_update_preview(camera, get_viewport().get_mouse_position())

func _on_box_z_fighting_changed(enabled: bool) -> void:
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.auto_resolve_box_z_fighting = enabled
	if current_tile_map3d:
		current_tile_map3d.rebuild_chunks_from_saved_data()

func _on_freeze_uv_changed(enabled: bool) -> void:
	if enabled and _get_current_mesh_mode() == TML3D_GlobalConstants.AUTOSHAPE_MESH:
		_apply_autoshape_freeze_uv_rule(TML3D_GlobalConstants.AUTOSHAPE_MESH)
		return
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.freeze_uv_on_rotation = enabled
	if placement_manager:
		placement_manager.set_current_freeze_uv(enabled)
		# Turning Freeze UV on puts the texture back to its atlas orientation; it stays 0 when turned off.
		if enabled:
			placement_manager.set_current_texture_rotation(0)
			_update_after_transform_change()

func _on_smart_select_additive_toggled(enabled: bool) -> void:
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.smart_select_additive = enabled
	if editor_ui and editor_ui._context_toolbar:
		editor_ui._context_toolbar.set_smart_select_additive(enabled)

func _on_sculp_mode_brush_changed(brush_type: int, brush_size: float) -> void:
	if current_tile_map3d and _sculpt_manager:
		current_tile_map3d.settings.sculpt_brush_type = brush_type
		current_tile_map3d.settings.sculpt_brush_size = brush_size
		_sculpt_manager.rebuild_brush_shape_template()

func _on_sculp_mode_options_changed(draw_top: bool, draw_bottom: bool, flip_sides: bool, flip_top: bool, flip_bottom: bool, build_with_depth: bool) -> void:
	if current_tile_map3d:
		current_tile_map3d.settings.sculpt_draw_top = draw_top
		current_tile_map3d.settings.sculpt_draw_bottom = draw_bottom
		current_tile_map3d.settings.sculpt_flip_top = flip_top
		current_tile_map3d.settings.sculpt_flip_sides = flip_sides
		current_tile_map3d.settings.sculpt_flip_bottom = flip_bottom
		current_tile_map3d.settings.sculpt_build_with_depth = build_with_depth

func _on_smart_operations_mode_changed(mode: int) -> void:
	if current_tile_map3d:
		current_tile_map3d.settings.smart_operations_main_mode = mode
		current_tile_map3d.update_gizmos()
	match mode:
		TML3D_GlobalConstants.SMART_FILL:
			if _smart_selection_manager:
				_smart_selection_manager.clear_selection()
		TML3D_GlobalConstants.SMART_SELECT:
			if _smart_fill_manager:
				_smart_fill_manager.reset()
			if current_tile_map3d:
				current_tile_map3d.clear_highlights()
		TML3D_GlobalConstants.PATTERNS_FILL:
			if _smart_fill_manager:
				_smart_fill_manager.reset()
			if current_tile_map3d:
				current_tile_map3d.clear_highlights()

func _on_smart_select_mode_changed(is_smart_select_on: bool, smart_mode: int) -> void:
	if not is_smart_select_on and current_tile_map3d:
		_smart_selection_manager.clear_selection()
	if _smart_fill_manager:
		_smart_fill_manager.reset()
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.is_smart_select_active = is_smart_select_on
		if smart_mode != current_tile_map3d.settings.smart_select_mode:
			current_tile_map3d.settings.smart_select_mode = smart_mode
	if current_tile_map3d:
		current_tile_map3d.update_gizmos()

func _on_smart_fill_changed(fill_mode: int, width: float, fill_direction: int, flip_faces: bool, ramp_sides: bool, total_steps: int, freeze_uv: bool) -> void:
	if current_tile_map3d:
		current_tile_map3d.settings.smart_fill_mode = fill_mode
		current_tile_map3d.settings.smart_fill_width = width
		current_tile_map3d.settings.smart_fill_quad_growth_dir = fill_direction
		current_tile_map3d.settings.smart_fill_flip_face = flip_faces
		current_tile_map3d.settings.smart_fill_ramp_sides = ramp_sides
		current_tile_map3d.settings.smart_fill_total_steps = total_steps
		current_tile_map3d.settings.smart_fill_freeze_uv = freeze_uv
		current_tile_map3d.update_gizmos()

func _on_grid_size_changed(new_size: float) -> void:
	var old_size: float = _get_current_grid_size()
	if placement_manager:
		placement_manager.set_grid_size(new_size)
	if tile_cursor:
		tile_cursor.grid_size = new_size
	if tile_preview:
		tile_preview.grid_size = new_size
	if area_fill_selector:
		area_fill_selector.grid_size = new_size
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.grid_size = new_size
		current_tile_map3d.apply_settings()
		if not is_equal_approx(old_size, new_size):
			current_tile_map3d.clear_collision_shapes()

func _on_texture_filter_changed(filter_mode: int) -> void:
	if placement_manager:
		placement_manager.set_texture_filter(filter_mode)
	if tile_preview:
		tile_preview.texture_filter_mode = filter_mode
		tile_preview._update_preview_material()
	_mark_scene_dirty()

func _on_pixel_inset_changed(value: float) -> void:
	if current_tile_map3d:
		current_tile_map3d.set_pixel_inset(value)
	_mark_scene_dirty()


# --- Area Fill Operations ---

func _complete_area_fill() -> void:
	if not _area_fill_operator:
		return
	var selection: Dictionary = _area_fill_operator.complete()
	if selection.is_empty():
		return
	var result: int
	if selection.is_erase:
		result = _set_area_erase_v2(selection.min_pos, selection.max_pos, selection.orientation)
	else:
		result = _set_area_fill_v2(selection.min_pos, selection.max_pos, selection.orientation)
	if result > 0:
		_check_tile_count_warning()
		_mark_scene_dirty()

func _set_area_fill_v2(min_pos: Vector3, max_pos: Vector3, orientation: int) -> int:
	if not placement_manager or not current_tile_map3d or _is_animated_tile_mode():
		return -1
	var autotile: bool = _is_autotile_mode()
	if autotile and (not _autotile_extension or not _autotile_extension.is_ready()):
		return 0
	var uv_only: bool = _is_paint_uv_only()

	# UV-only repaints the tiles already there; a normal fill creates one per cell.
	var tiles: Array[TML3D_PlacedTileInfo] = []
	if uv_only:
		tiles = _get_existing_area_tiles(min_pos, max_pos, orientation)
	else:
		for grid_pos: Vector3 in _get_area_fill_positions(min_pos, max_pos, orientation):
			tiles.append(placement_manager.create_tile_from_current_settings(grid_pos, orientation))
	if tiles.is_empty():
		return 0

	# The UV every tile takes. Autotile uses a placeholder; the callback resolves the real piece.
	var uv: Rect2 = placement_manager.get_current_tile_uv()
	if autotile:
		uv = _autotile_extension.get_autotile_uv(tiles[0].grid_position, orientation)
	elif uv_only:
		uv = selection_manager.get_first_tile() if selection_manager else Rect2()
	if not uv.has_area():
		return 0
	var binding: Array[Variant] = _resolve_autotile_binding(uv) if autotile else placement_manager.binding_for_uv_rect(uv)
	var terrain_id: int = _get_autotile_terrain_id() if autotile else TML3D_GlobalConstants.AUTOTILE_NO_TERRAIN

	var changed: Array[TML3D_PlacedTileInfo] = []
	for tile: TML3D_PlacedTileInfo in tiles:
		# A manual UV-only repaint skips tiles already showing this UV, unless they are autotile.
		if uv_only and not autotile and tile.uv_rect == uv and tile.terrain_id < 0:
			continue
		tile.terrain_id = terrain_id
		if not (autotile and uv_only):
			tile.uv_rect = uv
			tile.atlas_source_id = binding[0]
			tile.atlas_coords = binding[1]
		if autotile and not uv_only and current_tile_map3d.settings:
			tile.mesh_mode = current_tile_map3d.settings.mesh_mode
		if uv_only:
			_clear_tile_animation(tile)
		changed.append(tile)
	if changed.is_empty():
		return 0

	# UV-only repaints existing tiles, so it must not create back faces in empty cells.
	placement_manager.place_tiles(changed, "New Area Fill (%d tiles)" % changed.size(), _resync_autotile_around_tiles,
		_is_place_opposite() and not uv_only, not autotile, placement_manager.get_current_freeze_uv())
	return changed.size()

## Grid cells inside the area-fill rectangle, or empty when the area is too large.
func _get_area_fill_positions(min_pos: Vector3, max_pos: Vector3, orientation: int) -> Array[Vector3]:
	var positions: Array[Vector3] = TML3D_GlobalUtil.get_grid_positions_in_area_with_snap(min_pos, max_pos, orientation, placement_manager.get_grid_size())
	if positions.size() > TML3D_GlobalConstants.MAX_AREA_FILL_TILES:
		push_error("Area fill: Area too large (%d tiles, max %d)" % [positions.size(), TML3D_GlobalConstants.MAX_AREA_FILL_TILES])
		return []
	return positions

## A UV change makes a tile static, matching TileMapLayer3d_Cpp::update_tile_uv.
func _clear_tile_animation(tile: TML3D_PlacedTileInfo) -> void:
	tile.anim_step_x = 0.0
	tile.anim_step_y = 0.0
	tile.anim_total_frames = 1
	tile.anim_columns = 1
	tile.anim_speed_fps = 0.0

## Existing, non-vertex tiles inside the area-fill rectangle, as copies safe to modify.
func _get_existing_area_tiles(min_pos: Vector3, max_pos: Vector3, orientation: int) -> Array[TML3D_PlacedTileInfo]:
	var tiles: Array[TML3D_PlacedTileInfo] = []
	for grid_pos: Vector3 in _get_area_fill_positions(min_pos, max_pos, orientation):
		var tile_key: int = TML3D_GlobalUtil.make_tile_key(grid_pos, orientation)
		if not current_tile_map3d.has_tile(tile_key):
			continue
		if _vertex_edit_manager and _vertex_edit_manager.is_vertex_tile(tile_key):
			continue
		var info: TML3D_PlacedTileInfo = placement_manager.get_existing_tile_info(tile_key)
		if info != null:
			tiles.append(info.copy())
	return tiles

func _on_area_fill_clear_highlights() -> void:
	if current_tile_map3d:
		current_tile_map3d.clear_highlights()

func _on_area_fill_out_of_bounds(position: Vector3, orientation: int) -> void:
	if current_tile_map3d:
		current_tile_map3d.show_blocked_highlight(position, orientation)

func _on_highlight_tiles_in_area(start_pos: Vector3, end_pos: Vector3, orientation: int, is_erase: bool) -> void:
	if current_tile_map3d:
		current_tile_map3d.highlight_tiles_in_area(start_pos, end_pos, orientation, is_erase)

func _highlight_tiles_at_preview_position(grid_pos: Vector3, orientation: int, is_multi: bool) -> void:
	if not current_tile_map3d:
		return
	var selected: Array[Rect2] = []
	if is_multi:
		selected = _get_selected_tiles()
	var mirror_texture: bool = placement_manager.get_is_current_texture_mirrored() if placement_manager else false
	# Multi-tile layout turns with the texture rotation (only the multi-tile footprint uses this rotation).
	var rotation: int = TML3D_GlobalUtil.mesh_rotation_with_texture_turn(
		placement_manager.get_current_mesh_rotation(), placement_manager.get_current_texture_rotation_turn(), mirror_texture) if placement_manager else 0
	var selection_signature: String = _get_selection_signature(selected)
	if (
		grid_pos == _last_highlight_grid_pos
		and orientation == _last_highlight_orientation
		and is_multi == _last_highlight_is_multi
		and rotation == _last_highlight_rotation
		and mirror_texture == _last_highlight_mirror
		and selected.size() == _last_highlight_selection_count
		and selection_signature == _last_highlight_selection_signature
	):
		return
	_last_highlight_grid_pos = grid_pos
	_last_highlight_orientation = orientation
	_last_highlight_is_multi = is_multi
	_last_highlight_rotation = rotation
	_last_highlight_mirror = mirror_texture
	_last_highlight_selection_count = selected.size()
	_last_highlight_selection_signature = selection_signature
	current_tile_map3d.highlight_at_preview(grid_pos, orientation, selected, rotation, mirror_texture)


# --- Transform/mode change handlers (toolbar) ---

func _reset_autotile_transforms() -> void:
	if not placement_manager:
		return
	TML3D_GlobalPlaneDetector.reset_to_flat()
	placement_manager.set_current_mesh_rotation(0)
	placement_manager.set_is_current_texture_mirrored(false)
	placement_manager.set_current_texture_rotation(0)
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.current_mesh_rotation = 0
		current_tile_map3d.settings.set_is_texture_mirrored(false)
		current_tile_map3d.settings.current_texture_rotation = 0
	if tile_preview and current_tile_map3d and current_tile_map3d.settings:
		tile_preview.current_mesh_mode = current_tile_map3d.settings.mesh_mode

func _on_tilemap_main_mode_changed(mode: int) -> void:
	if _sculpt_manager and current_tile_map3d:
		_sculpt_manager.reset()
		current_tile_map3d.update_gizmos()
	if _smart_fill_manager and current_tile_map3d:
		_smart_fill_manager.reset()
		current_tile_map3d.update_gizmos()
	if _vertex_edit_manager:
		_vertex_edit_manager.deselect()
		if current_tile_map3d:
			current_tile_map3d.update_gizmos()
			current_tile_map3d.smart_selected_tiles = PackedInt64Array()
			current_tile_map3d.clear_highlights()
	if current_tile_map3d:
		current_tile_map3d.settings.is_smart_select_active = false
		current_tile_map3d.smart_selected_tiles = PackedInt64Array()
		current_tile_map3d.clear_highlights()

	_set_tiling_mode_to_settings(mode)
	_clear_selection()
	if mode == TML3D_GlobalConstants.APP_AUTOTILE:
		_reset_autotile_transforms()

	if _autotile_extension:
		_autotile_extension.set_enabled(mode == TML3D_GlobalConstants.APP_AUTOTILE)

	# Animated tiles now carry a mesh mode (FLAT_SQUARE/BOX/PRISM/AUTOSHAPE), so restore the
	# persisted mesh mode like the manual modes do; only autotile drives its own mesh mode.
	if current_tile_map3d and current_tile_map3d.settings and mode != TML3D_GlobalConstants.APP_AUTOTILE:
		_set_current_mesh_mode(current_tile_map3d.settings.mesh_mode)
	_sync_tile_preview_from_settings()

	call_deferred("_sync_depth_for_mode", mode)
	_invalidate_preview()
	show_bottom_panel_and_ui()

func _on_editor_ui_rotate_requested(direction: int, camera: Camera3D = null) -> void:
	if not placement_manager:
		return
	var r: int = (placement_manager.get_current_mesh_rotation() + direction) % TML3D_GlobalConstants.MAX_SPIN_ROTATION_STEPS
	if r < 0:
		r += TML3D_GlobalConstants.MAX_SPIN_ROTATION_STEPS
	placement_manager.set_current_mesh_rotation(r)
	_update_after_transform_change(camera)

func _on_editor_ui_tilt_requested(reverse: bool, camera: Camera3D = null) -> void:
	if reverse:
		TML3D_GlobalPlaneDetector.cycle_tilt_backward()
	else:
		TML3D_GlobalPlaneDetector.cycle_tilt_forward()
	_update_after_transform_change(camera)

func _on_editor_ui_reset_requested(camera: Camera3D = null) -> void:
	TML3D_GlobalPlaneDetector.reset_to_flat()
	if placement_manager:
		placement_manager.set_current_mesh_rotation(0)
		placement_manager.set_is_current_texture_mirrored(false)
		placement_manager.set_current_texture_rotation(0)
	_update_after_transform_change(camera)

func _on_editor_ui_mirror_requested(enabled: bool, camera: Camera3D = null) -> void:
	if not placement_manager:
		return
	placement_manager.set_is_current_texture_mirrored(enabled)
	_update_after_transform_change(camera)

func _on_editor_ui_texture_rotation_requested(direction: int, camera: Camera3D = null) -> void:
	# UI-only lock (button and G / Shift+G): tile code still sets texture rotation while Freeze UV is on.
	if not placement_manager or placement_manager.get_current_freeze_uv():
		return
	placement_manager.set_current_texture_rotation(placement_manager.get_current_texture_rotation() + direction)
	_update_after_transform_change(camera)

func _on_editor_ui_smart_select_operation_requested(operation: int) -> void:
	if not _smart_selection_manager:
		return
	match operation:
		TML3D_GlobalConstants.DELETE:
			_smart_selection_manager.request_delete_selected()
		TML3D_GlobalConstants.REPLACE_UV:
			_smart_selection_manager.request_replace_uv(selection_manager.get_first_tile())
		TML3D_GlobalConstants.REPLACE_MESH_TYPE:
			_smart_selection_manager.request_replace_mesh(
				editor_ui._context_toolbar.get_smart_select_target_mesh_mode(),
				editor_ui._context_toolbar.get_smart_depth_scale(),
				editor_ui._context_toolbar.get_smart_texture_repeat_mode(),
				editor_ui._context_toolbar.get_smart_select_depth_growth_mode())
		TML3D_GlobalConstants.CLEAR:
			_smart_selection_manager.clear_selection()

func _on_smart_selection_changed(keys: PackedInt64Array) -> void:
	if current_tile_map3d:
		current_tile_map3d.smart_selected_tiles = keys
		current_tile_map3d.highlight_tiles(keys)
		current_tile_map3d.update_gizmos()

func _on_smart_tiles_place_requested(tile_list: Array[TML3D_PlacedTileInfo], action_name: String) -> void:
	if placement_manager and placement_manager.place_tiles(tile_list, action_name, _resync_autotile_around_tiles, false):
		_mark_scene_dirty()

func _on_smart_tiles_erase_requested(tile_list: Array[TML3D_PlacedTileInfo], action_name: String) -> void:
	if placement_manager and placement_manager.erase_tiles(tile_list, action_name, _resync_autotile_around_tiles, false):
		if _vertex_edit_manager:
			_vertex_edit_manager.deselect()
		_mark_scene_dirty()

func _update_after_transform_change(camera: Camera3D = null) -> void:
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.current_mesh_rotation = placement_manager.get_current_mesh_rotation()
		current_tile_map3d.settings.set_is_texture_mirrored(placement_manager.get_is_current_texture_mirrored())
		current_tile_map3d.settings.current_texture_rotation = placement_manager.get_current_texture_rotation()
	if tile_preview:
		if not camera:
			camera = EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
		if camera:
			_update_preview(camera, _cached_local_mouse_pos, true)
	_update_side_toolbar_status()
	update_overlays()

func _update_side_toolbar_status() -> void:
	if not editor_ui:
		return
	var rotation_steps: int = 0
	if placement_manager:
		rotation_steps = placement_manager.get_current_mesh_rotation()
	var tilt_index: int = 0
	var current_orientation: int = TML3D_GlobalPlaneDetector.get_current_tile_orientation_18d()
	var tilt_sequence: Array[int] = TML3D_GlobalUtil.get_tilt_sequence(current_orientation)
	if tilt_sequence.size() > 0:
		var pos: int = tilt_sequence.find(current_orientation)
		if pos > 0:
			tilt_index = pos
	var is_mirrored: bool = false
	var texture_rotation: int = 0
	if placement_manager:
		is_mirrored = placement_manager.get_is_current_texture_mirrored()
		texture_rotation = placement_manager.get_current_texture_rotation()
	editor_ui.update_status(rotation_steps, tilt_index, is_mirrored, texture_rotation)

func _sync_depth_for_mode(mode: int) -> void:
	if not current_tile_map3d or not placement_manager:
		return
	var correct_depth: float = current_tile_map3d.settings.current_depth_scale
	placement_manager.set_current_depth_scale(correct_depth)
	placement_manager.set_current_depth_growth_mode(current_tile_map3d.settings.depth_growth_mode)
	if tile_preview:
		tile_preview.current_depth_scale = correct_depth
		tile_preview.current_depth_growth_mode = current_tile_map3d.settings.depth_growth_mode

func _sync_tile_preview_from_settings() -> void:
	if not tile_preview or not current_tile_map3d or not current_tile_map3d.settings:
		return
	# Animated tiles now preview in their chosen mesh mode (FLAT_SQUARE/BOX/PRISM/AUTOSHAPE).
	var preview_mesh_mode: int = _get_current_mesh_mode()
	tile_preview.sync_from_settings(current_tile_map3d.settings, preview_mesh_mode)


# --- Autotile Mode Handlers ---

func _sync_autotile_texture() -> void:
	if not _autotile_engine or not current_tile_map3d:
		return
	var resolved_texture: Texture2D = TML3D_TileAtlasResolver.get_active_texture(current_tile_map3d)
	if resolved_texture == null:
		push_warning("Autotile: TileSet has no atlas texture!")
		return
	placement_manager.set_tileset_texture(resolved_texture)
	current_tile_map3d.apply_settings()
	current_tile_map3d.update_configuration_warnings()
	if tileset_panel:
		tileset_panel.set_tileset_texture(resolved_texture)

func _on_autotile_tileset_changed(tileset: TileSet) -> void:
	if not current_tile_map3d or not placement_manager:
		return
	if not _autotile_extension:
		_autotile_extension = TML3D_AutotilePlacementExtension.new()
	if not tileset:
		_autotile_engine = null
		_autotile_extension.setup(null, current_tile_map3d)
		_invalidate_preview()
		return
	var settings: TML3D_TileMapLayerSettings = current_tile_map3d.settings
	var source_id: int = settings.active_source_id if settings else 0
	var terrain_set: int = settings.active_terrain_set if settings else 0
	var stats: Dictionary = _autotile_engine.get_stats() if _autotile_engine else {}
	if not _autotile_engine or _autotile_engine.get_tileset() != tileset or stats.get("source_id") != source_id or stats.get("terrain_set") != terrain_set:
		_autotile_engine = TML3D_AutotileEngine.new()
		_autotile_engine.setup(tileset, source_id, terrain_set)
	else:
		_autotile_engine.rebuild_lookup()
	_autotile_extension.setup(_autotile_engine, current_tile_map3d)
	var terrain_id: int = settings.active_terrain if settings else -1
	if terrain_id < 0 and settings:
		terrain_id = settings.autotile_active_terrain
	if terrain_id >= _autotile_engine.get_terrain_count():
		terrain_id = -1
	_autotile_extension.set_terrain(terrain_id)
	_autotile_extension.set_enabled(_is_autotile_mode())
	if tileset_panel and tileset_panel.auto_tile_tab and terrain_id >= 0:
		tileset_panel.auto_tile_tab.select_terrain(terrain_id)
	_sync_autotile_texture()
	_invalidate_preview()

func _on_autotile_terrain_selected(terrain_id: int) -> void:
	if not _autotile_engine:
		_setup_autotile_extension()
	if _autotile_extension:
		_autotile_extension.set_terrain(terrain_id)
	_reset_autotile_transforms()
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.active_terrain = terrain_id
		current_tile_map3d.settings.autotile_active_terrain = terrain_id
	_invalidate_preview()

func _on_paint_uv_only_changed(enabled: bool) -> void:
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.paint_uv_only = enabled

func _on_place_opposite_changed(enabled: bool) -> void:
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.place_opposite_tile = enabled

func _on_autotile_data_changed() -> void:
	# This also initializes a missing engine after the first terrain is authored, and
	# reconnects it if the active TileSet/source changed while editing resources.
	_setup_autotile_extension()

func _on_clear_tileset_requested() -> void:
	if _autotile_engine:
		_autotile_engine = null
	if _autotile_extension:
		_autotile_extension.set_engine(null)
	if current_tile_map3d and current_tile_map3d.settings:
		var settings: TML3D_TileMapLayerSettings = current_tile_map3d.settings
		current_tile_map3d.set_tileset(null)
		settings.tileset_texture = null
		settings.active_source_id = TML3D_GlobalConstants.AUTOTILE_DEFAULT_SOURCE_ID
		settings.active_terrain_set = TML3D_GlobalConstants.AUTOTILE_DEFAULT_TERRAIN_SET
		settings.active_terrain = TML3D_GlobalConstants.AUTOTILE_NO_TERRAIN
		settings.autotile_tileset = null
		settings.autotile_source_id = TML3D_GlobalConstants.AUTOTILE_DEFAULT_SOURCE_ID
		settings.autotile_terrain_set = TML3D_GlobalConstants.AUTOTILE_DEFAULT_TERRAIN_SET
		settings.autotile_active_terrain = TML3D_GlobalConstants.AUTOTILE_NO_TERRAIN
		current_tile_map3d.apply_settings()
		current_tile_map3d.update_configuration_warnings()
	if tileset_panel and tileset_panel.auto_tile_tab:
		tileset_panel.auto_tile_tab.refresh_terrains()


# --- Pattern placement ---

func _get_cursor_storage_position(camera: Camera3D) -> Vector3:
	if not tile_cursor:
		return Vector3.ZERO
	var plane_normal: Vector3 = TML3D_GlobalPlaneDetector.detect_active_plane_3d(camera)
	tile_cursor.set_active_plane(plane_normal)
	# grid_position IS the storage position; the cursor rests on the lattice corner.
	return placement_manager.snap_to_grid(tile_cursor.grid_position, plane_normal)


func _get_mouse_grid_placement(camera: Camera3D, screen_pos: Vector2) -> Dictionary[Variant, Variant]:
	if not is_instance_valid(tile_cursor):
		return {}
	var pmode: int = placement_manager.get_placement_mode()
	if _is_pattern_placement_mode():
		if pmode != TML3D_PlacementManager.CURSOR:
			return placement_manager.calculate_cursor_plane_placement(camera, screen_pos, tile_cursor.grid_position)
		var orientation: int = TML3D_GlobalPlaneDetector.detect_active_plane_6d(camera)
		return {
			"grid_pos": TML3D_GlobalUtil.snapped_grid_to_storage(_get_cursor_storage_position(camera), orientation),
			"orientation": orientation
		}
	if pmode == TML3D_PlacementManager.CURSOR_PLANE:
		return placement_manager.calculate_cursor_plane_placement(camera, screen_pos, tile_cursor.grid_position)
	elif pmode == TML3D_PlacementManager.CURSOR:
		return {
			"grid_pos": _get_cursor_storage_position(camera),
			"orientation": TML3D_GlobalPlaneDetector.get_current_tile_orientation_18d()
		}
	else:
		var ray_result: Dictionary[Variant, Variant] = placement_manager._raycast_to_geometry(camera, screen_pos, tile_cursor.grid_position)
		if ray_result.is_empty():
			return {}
		var grid_coords: Vector3 = TML3D_GlobalUtil.world_to_grid(ray_result.position, placement_manager.get_grid_size())
		return {
			"grid_pos": placement_manager.snap_to_grid(grid_coords),
			"orientation": TML3D_GlobalPlaneDetector.get_current_tile_orientation_18d()
		}

# --- Sculpt mode ---

func _on_sculpt_tiles_created(tile_list: Array[TML3D_PlacedTileInfo]) -> void:
	if not current_tile_map3d or not placement_manager:
		return
	if tile_list.is_empty():
		return
	# Sculpt always places with Freeze UV on.
	placement_manager.place_tiles(tile_list, "New Sculpt Place Tiles", _resync_autotile_around_tiles, _is_place_opposite(), true, true)
	_mark_scene_dirty()
	if current_tile_map3d:
		current_tile_map3d.update_gizmos()

func _on_sculpt_erase_tiles_requested(tile_list: Array[TML3D_PlacedTileInfo]) -> void:
	if not current_tile_map3d or not placement_manager:
		return
	if tile_list.is_empty():
		return
	placement_manager.erase_tiles(tile_list, "New Sculpt Erase Tiles", _resync_autotile_around_tiles, false)
	_mark_scene_dirty()
	if current_tile_map3d:
		current_tile_map3d.update_gizmos()


# --- Helper Getters ---

func _mark_scene_dirty() -> void:
	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()

func _is_autotile_mode() -> bool:
	if current_tile_map3d and current_tile_map3d.settings:
		return current_tile_map3d.settings.main_app_mode == TML3D_GlobalConstants.APP_AUTOTILE
	return false

func _is_paint_uv_only() -> bool:
	if current_tile_map3d and current_tile_map3d.settings:
		return current_tile_map3d.settings.paint_uv_only
	return false

func _is_place_opposite() -> bool:
	if current_tile_map3d and current_tile_map3d.settings:
		return current_tile_map3d.settings.place_opposite_tile
	return false

func _is_animated_tile_mode() -> bool:
	if current_tile_map3d and current_tile_map3d.settings:
		return current_tile_map3d.settings.main_app_mode == TML3D_GlobalConstants.APP_ANIMATED_TILES
	return false

func _is_patterns_fill_mode() -> bool:
	if current_tile_map3d and current_tile_map3d.settings:
		return current_tile_map3d.settings.main_app_mode == TML3D_GlobalConstants.APP_SMART_OPERATIONS and current_tile_map3d.settings.smart_operations_main_mode == TML3D_GlobalConstants.PATTERNS_FILL
	return false

func _is_pattern_placement_mode() -> bool:
	return _is_patterns_fill_mode() and _smart_pattern_manager != null and _smart_pattern_manager.has_selected_pattern()
func is_smart_operations_mode() -> bool:
	if current_tile_map3d and current_tile_map3d.settings:
		return current_tile_map3d.settings.main_app_mode == TML3D_GlobalConstants.APP_SMART_OPERATIONS
	return false

func is_smart_select_mode() -> bool:
	if current_tile_map3d and current_tile_map3d.settings:
		return (
			current_tile_map3d.settings.main_app_mode == TML3D_GlobalConstants.APP_SMART_OPERATIONS
			and (
				current_tile_map3d.settings.smart_operations_main_mode == TML3D_GlobalConstants.SMART_SELECT
				or current_tile_map3d.settings.smart_operations_main_mode == TML3D_GlobalConstants.PATTERNS_FILL
			)
		)
	return false

func is_smart_fill_mode() -> bool:
	if current_tile_map3d and current_tile_map3d.settings:
		return current_tile_map3d.settings.main_app_mode == TML3D_GlobalConstants.APP_SMART_OPERATIONS and current_tile_map3d.settings.smart_operations_main_mode == TML3D_GlobalConstants.SMART_FILL
	return false

func _is_sculpting_mode() -> bool:
	if current_tile_map3d and current_tile_map3d.settings:
		return current_tile_map3d.settings.main_app_mode == TML3D_GlobalConstants.APP_SCULPT
	return false

func _is_vertex_edit_mode() -> bool:
	if current_tile_map3d and current_tile_map3d.settings:
		return current_tile_map3d.settings.main_app_mode == TML3D_GlobalConstants.APP_VERTEX_EDIT
	return false


func _is_scatter_mode() -> bool:
	return current_tile_map3d != null and current_tile_map3d.settings != null and current_tile_map3d.settings.main_app_mode == TML3D_GlobalConstants.APP_SCATTER


func _get_scatter_surface_hit(camera: Camera3D, screen_position: Vector2) -> TML3D_ScatterSurfaceHit:
	if not current_tile_map3d or not current_tile_map3d.settings:
		return null
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	if current_tile_map3d.settings.scatter_detection_mode == TML3D_ScatterSurfacePicker.DETECT_COLLISION:
		return TML3D_ScatterSurfacePicker.pick_collision(
			ray_origin, ray_direction, current_tile_map3d,
			current_tile_map3d.settings.scatter_collision_mask
		)
	if not placement_manager or not is_instance_valid(tile_cursor):
		return null
	var placement_hit: Dictionary[Variant, Variant] = placement_manager._raycast_to_geometry(camera, screen_position, tile_cursor.grid_position)
	var placement_plane: Dictionary[Variant, Variant] = placement_manager.calculate_cursor_plane_placement(camera, screen_position, tile_cursor.grid_position)
	if placement_hit.is_empty() or placement_plane.is_empty():
		return null
	var active_plane: Vector3 = placement_plane.active_plane
	if tile_cursor:
		tile_cursor.set_active_plane(active_plane)
	var world_normal: Vector3 = (current_tile_map3d.global_transform.basis.inverse().transposed() * active_plane).normalized()
	return TML3D_ScatterSurfacePicker.create_grid_plane_hit(
		placement_hit.position, world_normal, current_tile_map3d,
		current_tile_map3d.settings.grid_size
	)


func _get_checked_scatter_items() -> Array[TML3D_ScatterItemDefinition]:
	if not tileset_panel or not tileset_panel.scatter_items_panel:
		return []
	return tileset_panel.scatter_items_panel.get_active_items()


func _get_checked_scatter_ids() -> PackedInt32Array:
	var result := PackedInt32Array()
	for item: TML3D_ScatterItemDefinition in _get_checked_scatter_items():
		if item:
			result.append(item.item_id)
	return result


func _choose_weighted_scatter_item(items: Array[TML3D_ScatterItemDefinition]) -> TML3D_ScatterItemDefinition:
	var total: float = 0.0
	for item: TML3D_ScatterItemDefinition in items:
		if item and item.mesh and item.probability_weight > 0.0:
			total += item.probability_weight
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for item: TML3D_ScatterItemDefinition in items:
		if not item or not item.mesh or item.probability_weight <= 0.0:
			continue
		roll -= item.probability_weight
		if roll <= 0.0:
			return item
	return null


func _update_scatter_hover(camera: Camera3D, screen_position: Vector2) -> void:
	var hit: TML3D_ScatterSurfaceHit = _get_scatter_surface_hit(camera, screen_position)
	if _sculpt_gizmo_plugin:
		_sculpt_gizmo_plugin.scatter_preview_valid = hit != null and hit.is_valid()
		_sculpt_gizmo_plugin.scatter_preview_rejected = false
		if hit and hit.is_valid():
			_sculpt_gizmo_plugin.scatter_preview_local_position = hit.get_local_position()
			_sculpt_gizmo_plugin.scatter_preview_local_normal = hit.get_local_normal()
		_sculpt_gizmo_plugin.scatter_preview_radius = current_tile_map3d.settings.scatter_brush_radius
		_sculpt_gizmo_plugin.scatter_preview_tool = current_tile_map3d.settings.scatter_tool
	current_tile_map3d.update_gizmos()

#TODO: MOVE TO SCATTER MANAGER OR ANOTHER CLASSS
func _apply_scatter_dab(camera: Camera3D, screen_position: Vector2, right_click: bool, shrink: bool, reset_scale: bool) -> void:
	var hit: TML3D_ScatterSurfaceHit = _get_scatter_surface_hit(camera, screen_position)
	if hit == null or not hit.is_valid():
		if _sculpt_gizmo_plugin:
			_sculpt_gizmo_plugin.scatter_preview_valid = false
		current_tile_map3d.update_gizmos()
		return
	var radius: float = current_tile_map3d.settings.scatter_brush_radius
	var local_center: Vector3 = hit.get_local_position()
	if _scatter_last_dab_position != Vector3.INF and _scatter_last_dab_position.distance_to(local_center) < maxf(0.05, radius * 0.15):
		return
	var stroke_direction: Vector3 = Vector3.ZERO if _scatter_last_dab_position == Vector3.INF else local_center - _scatter_last_dab_position
	_scatter_last_dab_position = local_center
	var checked_ids: PackedInt32Array = _get_checked_scatter_ids()
	if checked_ids.is_empty():
		return

	if current_tile_map3d.settings.scatter_tool == 1:
		var strength: float = current_tile_map3d.settings.scatter_scale_strength
		if right_click or shrink:
			strength = -strength
		current_tile_map3d.scale_scatter_in_radius(local_center, radius, checked_ids, strength, reset_scale)
		current_tile_map3d.update_gizmos()
		return

	if right_click:
		current_tile_map3d.erase_scatter_in_radius(local_center, radius, checked_ids)
		current_tile_map3d.update_gizmos()
		return

	var items: Array[TML3D_ScatterItemDefinition] = _get_checked_scatter_items()
	var area: float = PI * radius * radius
	var current_density: float = current_tile_map3d.settings.scatter_density	
	var attempts: int = clampi(ceili(area * current_density), 1, 1024 * (current_density / 10.0))
	var normal: Vector3 = hit.get_world_normal().normalized()
	var tangent: Vector3 = normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.001:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent: Vector3 = normal.cross(tangent).normalized()
	var placed_any: bool = false
	current_tile_map3d.begin_scatter_batch()
	for attempt: int in range(attempts):
		var offset2: Vector2 = Vector2.ZERO
		if attempt > 0:
			var angle: float = randf() * TAU
			var distance: float = sqrt(randf()) * radius
			offset2 = Vector2(cos(angle), sin(angle)) * distance
		var candidate_world: Vector3 = hit.get_world_position() + tangent * offset2.x + bitangent * offset2.y
		var candidate_hit: TML3D_ScatterSurfaceHit
		if current_tile_map3d.settings.scatter_detection_mode == TML3D_ScatterSurfacePicker.DETECT_COLLISION:
			candidate_hit = TML3D_ScatterSurfacePicker.pick_collision(
				candidate_world + normal * maxf(radius, 1.0), -normal, current_tile_map3d,
				current_tile_map3d.settings.scatter_collision_mask, maxf(radius * 2.0, 2.0)
			)
		else:
			# Reuse the existing placement manager path for every candidate so active-plane
			# selection and the visible placement bounds behave exactly like tile placement.
			candidate_hit = _get_scatter_surface_hit(camera, camera.unproject_position(candidate_world))
		if candidate_hit == null or not candidate_hit.is_valid():
			continue
		var item: TML3D_ScatterItemDefinition = _choose_weighted_scatter_item(items)
		if item and current_tile_map3d.place_scatter_instance(
			item.item_id, candidate_hit.get_local_position(), candidate_hit.get_local_normal(), stroke_direction
		):
			placed_any = true
	current_tile_map3d.end_scatter_batch()
	if _sculpt_gizmo_plugin:
		_sculpt_gizmo_plugin.scatter_preview_rejected = not placed_any
	current_tile_map3d.update_gizmos()

#TODO: MOVE TO SCATTER MANAGER OR ANOTHER CLASSS
func _finish_scatter_stroke() -> void:
	var after: Dictionary = current_tile_map3d.capture_scatter_state()
	if after != _scatter_stroke_before:
		var undo_redo: EditorUndoRedoManager = get_undo_redo()
		var action_name: String = "Scale Scatter" if current_tile_map3d.settings.scatter_tool == 1 else ("Erase Scatter" if _scatter_stroke_is_right_click else "Paint Scatter")
		undo_redo.create_action(action_name, 0, current_tile_map3d)
		undo_redo.add_do_method(current_tile_map3d, "restore_scatter_state", after)
		undo_redo.add_undo_method(current_tile_map3d, "restore_scatter_state", _scatter_stroke_before)
		undo_redo.add_do_method(current_tile_map3d, "update_gizmos")
		undo_redo.add_undo_method(current_tile_map3d, "update_gizmos")
		undo_redo.commit_action(false)
		_mark_scene_dirty()
	_scatter_stroke_active = false
	_scatter_stroke_is_right_click = false
	_scatter_stroke_before = {}
	_scatter_last_dab_position = Vector3.INF

func _on_scatter_detection_changed(mode: int, collision_mask: int) -> void:
	if not current_tile_map3d or not current_tile_map3d.settings:
		return
	current_tile_map3d.settings.scatter_detection_mode = mode
	current_tile_map3d.settings.scatter_collision_mask = collision_mask
	_mark_scene_dirty()


func _on_scatter_brush_changed(tool: int, radius: float, density: float, scale_strength: float) -> void:
	if not current_tile_map3d or not current_tile_map3d.settings:
		return
	current_tile_map3d.settings.scatter_tool = tool
	current_tile_map3d.settings.scatter_brush_radius = radius
	current_tile_map3d.settings.scatter_density = density
	current_tile_map3d.settings.scatter_scale_strength = scale_strength
	if _sculpt_gizmo_plugin:
		_sculpt_gizmo_plugin.scatter_preview_radius = radius
		_sculpt_gizmo_plugin.scatter_preview_tool = tool
	current_tile_map3d.update_gizmos()
	_mark_scene_dirty()


func _on_scatter_library_changed() -> void:
	if current_tile_map3d and current_tile_map3d.tile_map_data:
		current_tile_map3d.tile_map_data.emit_changed()
		current_tile_map3d.rebuild_scatter_chunks()
	_mark_scene_dirty()

func _get_selected_tiles() -> Array[Rect2]:
	if selection_manager:
		return selection_manager.get_tiles_readonly()
	return []

func _has_multi_tile_selection() -> bool:
	if selection_manager:
		return selection_manager.has_multi_selection()
	return false

func _get_snapped_cardinal_vector(direction: Vector3) -> Vector3:
	var ax: float = absf(direction.x)
	var ay: float = absf(direction.y)
	var az: float = absf(direction.z)
	if ax >= ay and ax >= az:
		return Vector3(_axis_sign(direction.x), 0.0, 0.0)
	if ay >= ax and ay >= az:
		return Vector3(0.0, _axis_sign(direction.y), 0.0)
	return Vector3(0.0, 0.0, _axis_sign(direction.z))

func _axis_sign(value: float) -> float:
	if value > 0.0:
		return 1.0
	if value < 0.0:
		return -1.0
	return 0.0

func _set_tiling_mode_to_settings(mode: int) -> void:
	if current_tile_map3d and current_tile_map3d.settings:
		current_tile_map3d.settings.main_app_mode = mode

func _set_current_mesh_mode(mesh_mode: int) -> void:
	if current_tile_map3d:
		current_tile_map3d.set_current_mesh_mode(mesh_mode)

func _get_current_mesh_mode() -> int:
	if current_tile_map3d:
		return current_tile_map3d.get_current_mesh_mode()
	return TML3D_GlobalConstants.get_DEFAULT_MESH_MODE()

func _get_current_grid_size() -> float:
	if current_tile_map3d and current_tile_map3d.settings:
		return current_tile_map3d.settings.grid_size
	return TML3D_GlobalConstants.get_DEFAULT_GRID_SIZE()

func _get_autotile_terrain_id() -> int:
	if _autotile_extension:
		return _autotile_extension.get_terrain()
	return TML3D_GlobalConstants.AUTOTILE_NO_TERRAIN

func _get_selection_signature(selected: Array[Rect2]) -> String:
	if selected.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for rect: Rect2 in selected:
		parts.append("%s:%s" % [rect.position, rect.size])
	return "|".join(parts)

func _clear_selection() -> void:
	if selection_manager:
		selection_manager.clear()

func _invalidate_preview() -> void:
	if tile_preview:
		tile_preview.hide_preview()
		tile_preview._hide_all_preview_instances()
	_last_preview_grid_pos = Vector3.INF
	_last_preview_screen_pos = Vector2.INF
	_invalidate_highlight_cache()

func _invalidate_highlight_cache() -> void:
	_last_highlight_grid_pos = Vector3.INF
	_last_highlight_orientation = -1
	_last_highlight_is_multi = false
	_last_highlight_rotation = -1
	_last_highlight_mirror = false
	_last_highlight_selection_count = -1
	_last_highlight_selection_signature = ""

#TODO MODE TO GLOBAL UTIL?
func _grid_to_absolute_world(grid_pos: Vector3) -> Vector3:
	var local_world: Vector3 = TML3D_GlobalUtil.grid_to_world(grid_pos, placement_manager.get_grid_size())
	if current_tile_map3d:
		return current_tile_map3d.to_global(local_world)
	return local_world

func _on_current_node_settings_changed() -> void:
	if not current_tile_map3d or not current_tile_map3d.settings:
		return
	var settings: TML3D_TileMapLayerSettings = current_tile_map3d.settings
	_set_current_mesh_mode(settings.mesh_mode)
	_apply_autoshape_freeze_uv_rule(settings.mesh_mode)
	if editor_ui and editor_ui._context_toolbar:
		editor_ui._context_toolbar.set_mesh_mode(settings.mesh_mode)
		editor_ui._context_toolbar.set_freeze_uv(settings.freeze_uv_on_rotation)
		editor_ui._context_toolbar.set_paint_uv_only(settings.paint_uv_only)
		editor_ui._context_toolbar.set_mirrored(settings.get_is_texture_mirrored())
		editor_ui._context_toolbar.set_texture_rotation(settings.current_texture_rotation)
	_sync_tile_preview_from_settings()
	if _autotile_extension:
		_autotile_extension.set_enabled(settings.main_app_mode == TML3D_GlobalConstants.APP_AUTOTILE)
	if selection_manager:
		var current_selection: Array[Rect2] = selection_manager.get_tiles_readonly()
		if current_selection != settings.selected_tiles:
			selection_manager.restore_from_settings(settings.selected_tiles, settings.selected_anchor_index, true)


# --- Vertex Edit Mode ---

func _handle_vertex_edit_click(camera: Camera3D, screen_pos: Vector2) -> void:
	if not _vertex_edit_manager or not current_tile_map3d:
		return
	var pick_result: TML3D_PlacedTileInfo = TML3D_SmartSelectionManager.pick_tile_at(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos), current_tile_map3d)
	if pick_result == null:
		current_tile_map3d.clear_highlights()
		current_tile_map3d.smart_selected_tiles = PackedInt64Array()
		_vertex_edit_manager.deselect()
		current_tile_map3d.update_gizmos()
		return

	var tile_key: int = pick_result.tile_key
	var is_vtx: bool = _vertex_edit_manager.is_vertex_tile(tile_key)
	var sel: PackedInt64Array = current_tile_map3d.smart_selected_tiles

	var idx: int = sel.find(tile_key)
	if idx >= 0:
		sel.remove_at(idx)
		if _vertex_edit_manager.get_selected_tile_key() == tile_key:
			_vertex_edit_manager.deselect()
	else:
		sel.append(tile_key)
	current_tile_map3d.smart_selected_tiles = sel

	if is_vtx and current_tile_map3d.smart_selected_tiles.has(tile_key):
		_vertex_edit_manager.select_tile(tile_key)
	else:
		_vertex_edit_manager.deselect()

	current_tile_map3d.highlight_tiles(current_tile_map3d.smart_selected_tiles)
	current_tile_map3d.update_gizmos()

func _on_vertex_convert_requested() -> void:
	if not _vertex_edit_manager or not current_tile_map3d:
		return
	var selected_keys: PackedInt64Array = current_tile_map3d.smart_selected_tiles
	if selected_keys.is_empty():
		return
	var to_convert: Array[int] = []
	for tile_key: int in selected_keys:
		if not _vertex_edit_manager.is_vertex_tile(tile_key):
			to_convert.append(tile_key)
	if to_convert.is_empty():
		if selected_keys.size() == 1:
			_vertex_edit_manager.select_tile(selected_keys[0])
			current_tile_map3d.update_gizmos()
		return
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Convert to Vertex Tiles", 0, current_tile_map3d)
	for tile_key: int in to_convert:
		undo_redo.add_do_method(_vertex_edit_manager, "convert_tile", tile_key)
		undo_redo.add_undo_method(_vertex_edit_manager, "undo_convert_tile", tile_key)
	undo_redo.add_do_method(current_tile_map3d, "update_gizmos")
	undo_redo.add_undo_method(current_tile_map3d, "update_gizmos")
	undo_redo.commit_action()
	_vertex_edit_manager.select_tile(to_convert[0])
	current_tile_map3d.update_gizmos()

func _on_vertex_delete_requested() -> void:
	_delete_selected_tiles()

func _delete_selected_tiles() -> void:
	if _smart_selection_manager:
		_smart_selection_manager.request_delete_selected()


func _prepare_fast_move() -> void:
	if _tile_stroke_active:
		_finish_tile_stroke()
	if _scatter_stroke_active:
		_finish_scatter_stroke()
	if _area_fill_operator and _area_fill_operator.is_selecting:
		_area_fill_operator.cancel()
	if _sculpt_manager and _sculpt_manager.get_state() != TML3D_SculptManager.IDLE:
		_sculpt_manager.on_cancel()
		if current_tile_map3d:
			current_tile_map3d.update_gizmos()
	_finish_vertex_drag()

func _fast_move_cursor_to_tile(camera: Camera3D, screen_pos: Vector2) -> void:
	if not current_tile_map3d or not tile_cursor:
		return
	var hit = TML3D_SmartSelectionManager.pick_tile_at(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos), current_tile_map3d)
	if hit == null:
		if EditorShortcuts.DEBUG_INPUT:
			print("TML3D: fast move miss")
		return
	var plane: int = TML3D_GlobalPlaneDetector.detect_active_plane_6d(camera)
	var base_orientation: int = TML3D_GlobalUtil.get_base_tile_orientation(hit.orientation)
	# An opposite (back-face) tile shares its original's cell and plane, so it counts as on this plane.
	if base_orientation != plane and base_orientation != TML3D_GlobalUtil.get_opposite_orientation(plane):
		if EditorShortcuts.DEBUG_INPUT:
			print("TML3D: fast move rejected: tile %s, camera %s" % [TML3D_GlobalUtil.orientation_name(hit.orientation), TML3D_GlobalUtil.orientation_name(plane)])
		return
	# A tilted tile occupies its base face's cell; only the mesh differs. Re-snap from the
	# camera plane rather than using snapped_grid_position, which carries no face
	# offset for non-base orientations. Then step to the corner the cursor occupies.
	var face_centre: Vector3 = TML3D_GlobalUtil.storage_grid_to_snapped(hit.grid_position, plane)
	var cursor_position: Vector3 = face_centre + _fast_move_corner_step(plane)
	tile_cursor.set_active_plane(TML3D_GlobalPlaneDetector.detect_active_plane_3d(camera))
	tile_cursor.move_to(cursor_position)
	_invalidate_preview()
	if _is_scatter_mode():
		_update_scatter_hover(camera, screen_pos)
	else:
		_update_preview(camera, screen_pos, true)


## Face centre -> the lattice corner the cursor occupies, per base orientation.
## Measured from in-editor cursor positions; see the six-face check in the notes.
func _fast_move_corner_step(orientation: int) -> Vector3:
	match orientation:
		TML3D_GlobalUtil.FLOOR: return Vector3(0, 0, 1)
		TML3D_GlobalUtil.CEILING: return Vector3.ZERO
		TML3D_GlobalUtil.WALL_NORTH: return Vector3.ZERO
		TML3D_GlobalUtil.WALL_SOUTH: return Vector3(1, 0, 0)
		TML3D_GlobalUtil.WALL_EAST: return Vector3.ZERO
		TML3D_GlobalUtil.WALL_WEST: return Vector3(0, 0, 1)
	return Vector3.ZERO


func _is_editor_viewport_navigation(button_mask: int, alt_pressed: bool = false) -> bool:
	if _scatter_stroke_active:
		return false
	if _tile_stroke_active:
		return false
	if _area_fill_operator and _area_fill_operator.is_selecting:
		return false  # area select/erase drag (Shift+RMB) must reach _handle_mouse_motion
	if alt_pressed:
		return true
	var nav_mask: int = MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT
	return (button_mask & nav_mask) != 0
