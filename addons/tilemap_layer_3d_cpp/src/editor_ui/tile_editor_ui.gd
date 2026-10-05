@tool
class_name TML3D_TileEditorUI
extends RefCounted

# EditorPlugin.CustomControlContainer values (int for web export compatibility)
const VIEWPORT_TOP: int = 1
const VIEWPORT_LEFT: int = 2
const VIEWPORT_RIGHT: int = 3
const VIEWPORT_BOTTOM: int = 4

# Preload UI component scenes (new addon copies)
const TileContextToolbarScene = preload("res://addons/tilemap_layer_3d_cpp/src/editor_ui/context_toolbar.tscn")
const TileMainToolbarScene = preload("res://addons/tilemap_layer_3d_cpp//src/editor_ui/main_toolbar.tscn")
static var GlobalLabelSettings: LabelSettings = load("res://addons/tilemap_layer_3d_cpp/src/editor_ui/global_ui_label_settings.tres")

## Unscaled base font size for every editor-UI Label. The shared LabelSettings resource is
## always recomputed from this constant, never read back, so a value baked into the .tres by
## an editor save self-corrects on the next load instead of compounding across UI scales.
const BASE_LABEL_FONT_SIZE: int = 10


# --- Signals ---

signal tiling_enabled_changed(enabled: bool)
signal tilemap_main_mode_changed(mode: int)
signal rotate_requested(direction: int)  # +1 = CW, -1 = CCW
signal tilt_requested(reverse: bool)
signal reset_requested()
signal mirror_requested(enabled: bool)
signal texture_rotation_requested(direction: int)

signal smart_select_operation_requested(smart_mode: int)

signal smart_select_mode_changed(is_smart_select_on: bool, smart_mode: int)

signal vertex_convert_requested()
signal vertex_delete_requested()


# --- Member Variables ---

# Object not EditorPlugin — EditorPlugin unavailable at runtime (web export)
var _plugin: Object = null
var active_tile_map_layer3d: TileMapLayer3d_Cpp = null
var _is_visible: bool = false

# --- UI Components ---

var _main_toolbar_scene: TML3D_TileMainToolbar = null
var _context_toolbar: TML3D_TileContextToolbar = null
var _main_toolbar_location: int = VIEWPORT_LEFT
var _contextual_toolbar_location: int = VIEWPORT_BOTTOM
var _tileset_panel: TML3D_TilesetPanel = null

# --- Initialization ---

func initialize(plugin: Object) -> void:
	_plugin = plugin
	_create_main_toolbar()
	_create_context_toolbar()

	# Start with UI hidden - will be shown when TileMapLayer3d_Cpp is selected
	set_ui_visible(false)
	_sync_ui_from_node()


## Single write point for editor-UI label font size. Every Label in the addon's scenes shares
## GlobalLabelSettings, so scaling it once here covers all of them regardless of which scene
## loads first.
static func apply_label_font_scale() -> void:
	if GlobalLabelSettings == null:
		return
	var ui_scale: float = TML3D_GlobalUtil.get_editor_ui_scale()
	GlobalLabelSettings.font_size = int(BASE_LABEL_FONT_SIZE * ui_scale)


func cleanup() -> void:
	_disconnect_tileset_panel()
	_destroy_context_toolbar()
	_destroy_main_toolbar()
	_plugin = null
	active_tile_map_layer3d = null
	_tileset_panel = null

# --- Main Menu Toolbar ---

func _create_main_toolbar() -> void:
	if not _plugin:
		return

	_main_toolbar_scene = TileMainToolbarScene.instantiate()

	# Connect signals
	_main_toolbar_scene.main_toolbar_tiling_enabled_clicked.connect(_on_tiling_enabled_changed)
	_main_toolbar_scene.main_toolbar_mode_changed.connect(_on_mode_changed)

	# Add to editor's 3D toolbar
	_plugin.add_control_to_container(_main_toolbar_location, _main_toolbar_scene)


func _destroy_main_toolbar() -> void:
	if _main_toolbar_scene and _plugin:
		_plugin.remove_control_from_container(_main_toolbar_location, _main_toolbar_scene)
		_main_toolbar_scene.queue_free()
		_main_toolbar_scene = null

# --- Context Toolbar ---

func _create_context_toolbar() -> void:
	if not _plugin:
		return

	# Create side toolbar from scene
	_context_toolbar = TileContextToolbarScene.instantiate()

	# Connect signals from side toolbar to coordinator (routes to plugin)
	_context_toolbar.rotate_btn_pressed.connect(_on_rotate_btn_pressed)
	_context_toolbar.tilt_btn_pressed.connect(_on_tilt_btn_pressed)
	_context_toolbar.reset_btn_pressed.connect(_on_reset_btn_pressed)
	_context_toolbar.mirror_btn_pressed.connect(_on_mirror_btn_pressed)
	_context_toolbar.texture_rotation_btn_pressed.connect(_on_texture_rotation_btn_pressed)
	_context_toolbar.smart_select_dropdown_changed.connect(_on_smart_select_dropdown_changed)
	_context_toolbar.smart_select_operation_btn_pressed.connect(_on_smart_select_operation_btn_pressed)
	_context_toolbar.vertex_convert_pressed.connect(_on_vertex_convert_pressed)
	_context_toolbar.vertex_delete_pressed.connect(_on_vertex_delete_pressed)

	# Add to editor's left side panel
	_plugin.add_control_to_container(_contextual_toolbar_location, _context_toolbar)


func _destroy_context_toolbar() -> void:
	if _context_toolbar and _plugin:
		_plugin.remove_control_from_container(_contextual_toolbar_location, _context_toolbar)
		_context_toolbar.queue_free()
		_context_toolbar = null

# --- Tileset Panel Sync ---

## Connect to TilesetPanel signals for bidirectional sync
func _connect_tileset_panel() -> void:
	if not _tileset_panel:
		return

	# Connect to tiling_mode_changed to sync top bar when tab changes in dock
	if not _tileset_panel.tiling_mode_changed.is_connected(_on_tileset_panel_mode_changed):
		_tileset_panel.tiling_mode_changed.connect(_on_tileset_panel_mode_changed)


## Disconnect from TilesetPanel signals
func _disconnect_tileset_panel() -> void:
	if not _tileset_panel:
		return

	if _tileset_panel.tiling_mode_changed.is_connected(_on_tileset_panel_mode_changed):
		_tileset_panel.tiling_mode_changed.disconnect(_on_tileset_panel_mode_changed)

# --- Public Methods ---

## Called by plugin when _edit() is invoked
func set_active_node(node: TileMapLayer3d_Cpp) -> void:
	active_tile_map_layer3d = node

	if node:
		_sync_ui_from_node()
	else:
		_reset_ui_state()


func set_tileset_panel(panel: TML3D_TilesetPanel) -> void:
	# Disconnect from old panel if any
	_disconnect_tileset_panel()

	_tileset_panel = panel

	# Connect to new panel
	_connect_tileset_panel()


func set_enabled(enabled: bool) -> void:
	if _main_toolbar_scene:
		_main_toolbar_scene.set_enabled(enabled)
	_is_visible = enabled


## Get whether the plugin is currently enabled
func is_enabled() -> bool:
	if _main_toolbar_scene:
		return _main_toolbar_scene.is_enabled()
	return false


func update_status(rotation_steps: int, tilt_index: int, is_mirrored: bool, texture_rotation: int = 0) -> void:
	if _context_toolbar:
		_context_toolbar.update_status(rotation_steps, tilt_index, is_mirrored, texture_rotation)


## Called by plugin's _make_visible() when node selection changes
func set_ui_visible(visible: bool) -> void:
	if _main_toolbar_scene:
		_main_toolbar_scene.visible = visible

	if _context_toolbar:
		_context_toolbar.visible = visible
	_is_visible = visible

# --- Private Methods ---

## Sync UI state from the active node's settings
func _sync_ui_from_node() -> void:
	if not active_tile_map_layer3d:
		return

	# Sync top bar from settings
	if _main_toolbar_scene:
		_main_toolbar_scene.sync_from_settings(active_tile_map_layer3d)

	# Sync context toolbar smart select from settings
	if _context_toolbar:
		_context_toolbar.sync_from_settings(active_tile_map_layer3d)


## Reset UI to default state (no node selected)
func _reset_ui_state() -> void:
	if _main_toolbar_scene:
		_main_toolbar_scene.sync_from_settings(null)

	if _context_toolbar:
		_context_toolbar.sync_from_settings(null)

# --- Signal Handlers ---

## Called when enable toggle changes in top bar
func _on_tiling_enabled_changed(pressed: bool) -> void:
	tiling_enabled_changed.emit(pressed)


## Called when any mode button is clicked in main toolbar
## Receives both mode and smart select state as one atomic event
func _on_mode_changed(mode: int, is_smart_select: bool) -> void:
	# Update settings (single source of truth)
	if active_tile_map_layer3d:
		var settings: TML3D_TileMapLayerSettings = active_tile_map_layer3d.settings
		if settings:
			settings.main_app_mode = mode

	# Emit for plugin (clears selection on autotile, toggles extension, updates preview)
	tilemap_main_mode_changed.emit(mode)

	# Sync dock panel tabs
	if _tileset_panel:
		_tileset_panel.set_tiling_mode_from_external(mode)

	# Update smart select state based on new mode (smart select only applies to manual mode)
	if mode == TML3D_GlobalConstants.APP_AUTOTILE:
		smart_select_mode_changed.emit(false, _context_toolbar.smart_select_mode_option_btn.get_selected_id())
	else:
		smart_select_mode_changed.emit(is_smart_select, _context_toolbar.smart_select_mode_option_btn.get_selected_id())

	# Context toolbar sync handles visibility of menus based on mode and smart select state
	if _context_toolbar and active_tile_map_layer3d:
		_context_toolbar.sync_from_settings(active_tile_map_layer3d)


## Captures the MODE change for Smart Selection : SINGLE_PICK, CONNECTED_UV, CONNECTED_NEIGHBOR
func _on_smart_select_dropdown_changed(smart_mode: int) -> void:
	if active_tile_map_layer3d:
		smart_select_mode_changed.emit(active_tile_map_layer3d.settings.is_smart_select_active, smart_mode)

func _on_smart_select_operation_btn_pressed(smart_mode_operation: int) -> void:
	smart_select_operation_requested.emit(smart_mode_operation)

## Called when TilesetPanel tab changes (user clicked tab in dock)
## This syncs dock → top bar
func _on_tileset_panel_mode_changed(mode: int) -> void:
	# Update top bar to reflect the new mode (without emitting signal to avoid loop)
	if _main_toolbar_scene:
		_main_toolbar_scene.set_mode(mode)


## Called when rotation is requested from side toolbar
func _on_rotate_btn_pressed(direction: int) -> void:
	rotate_requested.emit(direction)


## Called when tilt is requested from side toolbar
func _on_tilt_btn_pressed(reverse: bool) -> void:
	tilt_requested.emit(reverse)


## Called when reset is requested from side toolbar
func _on_reset_btn_pressed() -> void:
	reset_requested.emit()


## Called when flip is requested from side toolbar
func _on_mirror_btn_pressed(enabled: bool) -> void:
	mirror_requested.emit(enabled)


func _on_texture_rotation_btn_pressed(direction: int) -> void:
	texture_rotation_requested.emit(direction)


## Called when vertex edit Convert button is pressed
func _on_vertex_convert_pressed() -> void:
	vertex_convert_requested.emit()


## Called when vertex edit Revert button is pressed
func _on_vertex_delete_pressed() -> void:
	vertex_delete_requested.emit()
