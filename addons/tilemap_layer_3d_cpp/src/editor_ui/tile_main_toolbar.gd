@tool
class_name TML3D_TileMainToolbar
extends VBoxContainer

# --- Signals ---

## Emitted when enable toggle changes
signal main_toolbar_tiling_enabled_clicked(enabled: bool)

## Emitted when any mode button is clicked (Manual/Smart Select/Auto)
## Carries both mode and smart select state as one atomic event
signal main_toolbar_mode_changed(mode: int, is_smart_select: bool)

signal grid_snap_size_changed(snap_size: float)

signal cursor_step_size_changed(step_size: float)



# --- Member Variables ---

## Enable toggle button
@onready var enable_tiling_check_btn: CheckButton = %EnableTilingCheckBtn
## Manual mode button
@onready var manual_tile_button: Button = %ManualTileButton
## Smart operations mode button
@onready var smart_operations_button: Button = %SmartOperationsButton
## Auto mode button
@onready var auto_tile_button: Button = %AutoTileButton
## Animated tiles button
@onready var animated_tiles_button: Button = %AnimatedTilesButton

## Sculpted tiles button
@onready var sculp_tiles_button: Button = %SculpTilesButton
## Vertex edit mode button
@onready var vertex_edit_button: Button = %VertexEditButton
@onready var scatter_button: Button = %ScatterButton

## Settings button
@onready var settings_button: Button = %SettingsButton

##Grid Settings and CUrsor seetings
@onready var grid_snap_dropdown: OptionButton = %GridSnapDropdown
@onready var cursor_step_dropdown: OptionButton = %CursorStepSizeDropdown
@onready var grid_snap_label: Label = %GridSnapLbl
@onready var cursor_step_label: Label = %CursorStepLbl

var active_tile_map_layer3d: TileMapLayer3d_Cpp = null


## Flag to prevent signal loops during programmatic updates
var _updating_ui: bool = false

func _init() -> void:
	name = "TileMapLayer3DTopBar"

## Connect all UI components on READY via signals
func _ready() -> void:
	prepare_ui_components()


## Editor-only button theming (legacy GlobalUtil.apply_button_theme reimplemented locally).
func _apply_button_theme(button: Button, icon_name: String, size: float) -> void:
	if not Engine.is_editor_hint():
		return
	var ui_scale: float = TML3D_GlobalUtil.get_editor_ui_scale()
	var editor_theme: Theme = null
	var ei: Object = Engine.get_singleton("EditorInterface")
	if ei:
		editor_theme = ei.get_editor_theme()
	var icon_size: float = size * ui_scale
	button.custom_minimum_size = Vector2(icon_size, icon_size)
	button.add_theme_font_size_override("font_size", int(10 * ui_scale))
	if editor_theme and editor_theme.has_icon(icon_name, "EditorIcons"):
		button.icon = editor_theme.get_icon(icon_name, "EditorIcons")
	else:
		button.text = icon_name


func prepare_ui_components() -> void:
	var ui_scale: float = TML3D_GlobalUtil.get_editor_ui_scale()

	# Connect signals from UI components
	enable_tiling_check_btn.toggled.connect(_on_enable_button_toggled)
	manual_tile_button.toggled.connect(_on_manual_button_toggled)
	smart_operations_button.toggled.connect(_on_smartoperations_button_toggled)
	auto_tile_button.toggled.connect(_on_auto_button_toggled)
	settings_button.toggled.connect(_on_settings_button_toggled)
	animated_tiles_button.toggled.connect(_on_animated_tiles_button_toggled)
	sculp_tiles_button.toggled.connect(_on_sculp_tiles_button_toggled)
	vertex_edit_button.toggled.connect(_on_vertex_edit_button_toggled)
	scatter_button.toggled.connect(_on_scatter_button_toggled)
	grid_snap_dropdown.item_selected.connect(_on_grid_snap_selected)
	cursor_step_dropdown.item_selected.connect(_on_cursor_step_selected)


	_apply_button_theme(manual_tile_button, "BitMap", TML3D_GlobalConstants.BUTTOM_MAIN_UI_SIZE)
	_apply_button_theme(auto_tile_button, "TileSet", TML3D_GlobalConstants.BUTTOM_MAIN_UI_SIZE)
	_apply_button_theme(smart_operations_button, "PluginScript", TML3D_GlobalConstants.BUTTOM_MAIN_UI_SIZE)
	_apply_button_theme(settings_button, "Tools", TML3D_GlobalConstants.BUTTOM_MAIN_UI_SIZE)
	_apply_button_theme(animated_tiles_button, "Animation", TML3D_GlobalConstants.BUTTOM_MAIN_UI_SIZE)
	_apply_button_theme(sculp_tiles_button, "TexturePreviewChannels", TML3D_GlobalConstants.BUTTOM_MAIN_UI_SIZE)
	_apply_button_theme(vertex_edit_button, "MeshItem", TML3D_GlobalConstants.BUTTOM_MAIN_UI_SIZE)
	_apply_button_theme(scatter_button, "ImageTexture3D", TML3D_GlobalConstants.BUTTOM_MAIN_UI_SIZE)

	grid_snap_dropdown.add_theme_font_size_override("font_size", int(8 * ui_scale))
	cursor_step_dropdown.add_theme_font_size_override("font_size", int(8 * ui_scale))




## Sync UI state from node settings
func sync_from_settings(tilemaplayer3d: TileMapLayer3d_Cpp) -> void:
	if not tilemaplayer3d:
		_reset_to_defaults()
		return

	_updating_ui = true
	active_tile_map_layer3d = tilemaplayer3d

	# Sync tiling mode to UI
	#Buttons are all in the same Toggle Group (via inspector), so only one can be active at a time.
	match active_tile_map_layer3d.settings.main_app_mode:
		TML3D_GlobalConstants.APP_MANUAL:
			manual_tile_button.button_pressed = true
		TML3D_GlobalConstants.APP_AUTOTILE:
			auto_tile_button.button_pressed = true
		TML3D_GlobalConstants.APP_SMART_OPERATIONS:
			smart_operations_button.button_pressed = true
		TML3D_GlobalConstants.APP_ANIMATED_TILES:
			animated_tiles_button.button_pressed = true
		TML3D_GlobalConstants.APP_SCULPT:
			sculp_tiles_button.button_pressed = true
		TML3D_GlobalConstants.APP_VERTEX_EDIT:
			vertex_edit_button.button_pressed = true
		TML3D_GlobalConstants.APP_SCATTER:
			scatter_button.button_pressed = true
		TML3D_GlobalConstants.APP_SETTINGS:
			settings_button.button_pressed = true
		_:
			manual_tile_button.button_pressed = true

	var resolved_cursor_step: float = active_tile_map_layer3d.settings.cursor_step_size
	var resolved_grid_snap: float = active_tile_map_layer3d.settings.grid_snap_size

	if grid_snap_dropdown:
		var snap_index: int = TML3D_EditorConst.GRID_SNAP_OPTIONS.find(resolved_grid_snap)
		if snap_index >= 0:
			grid_snap_dropdown.selected = snap_index
		else:
			var default_index: int = TML3D_EditorConst.GRID_SNAP_OPTIONS.find(1.0)
			grid_snap_dropdown.selected = default_index if default_index >= 0 else 0

	if cursor_step_dropdown:
		var step_index: int = TML3D_EditorConst.CURSOR_STEP_OPTIONS.find(resolved_cursor_step)
		if step_index >= 0:
			cursor_step_dropdown.selected = step_index
		else:
			var default_index: int = TML3D_EditorConst.CURSOR_STEP_OPTIONS.find(TML3D_GlobalConstants.get_DEFAULT_CURSOR_STEP_SIZE())
			cursor_step_dropdown.selected = default_index if default_index >= 0 else 0

	_updating_ui = false




## Reset UI to default state
func _reset_to_defaults() -> void:
	_updating_ui = true
	manual_tile_button.button_pressed = true
	_updating_ui = false


## Set enabled state without triggering signal
func set_enabled(enabled: bool) -> void:
	if enable_tiling_check_btn:
		enable_tiling_check_btn.set_pressed_no_signal(enabled)


func is_enabled() -> bool:
	if enable_tiling_check_btn:
		return enable_tiling_check_btn.button_pressed
	return false


## Set tiling mode without triggering signal
func set_mode(mode: int) -> void:
	_updating_ui = true
	if mode == TML3D_GlobalConstants.APP_AUTOTILE:
		auto_tile_button.button_pressed = true
	else:
		manual_tile_button.button_pressed = true
	_updating_ui = false


# SECTION: SIGNAL HANDLERS
func _on_enable_button_toggled(pressed: bool) -> void:
	main_toolbar_tiling_enabled_clicked.emit(pressed)

func _on_manual_button_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	if pressed:
		main_toolbar_mode_changed.emit(TML3D_GlobalConstants.APP_MANUAL, false)

func _on_smartoperations_button_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	if pressed:
		main_toolbar_mode_changed.emit(TML3D_GlobalConstants.APP_SMART_OPERATIONS, true)

func _on_auto_button_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	if pressed:
		main_toolbar_mode_changed.emit(TML3D_GlobalConstants.APP_AUTOTILE, false)

func _on_animated_tiles_button_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	if pressed:
		main_toolbar_mode_changed.emit(TML3D_GlobalConstants.APP_ANIMATED_TILES, false)

func _on_sculp_tiles_button_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	if pressed:
		main_toolbar_mode_changed.emit(TML3D_GlobalConstants.APP_SCULPT, false)


func _on_vertex_edit_button_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	if pressed:
		main_toolbar_mode_changed.emit(TML3D_GlobalConstants.APP_VERTEX_EDIT, false)


func _on_scatter_button_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	if pressed:
		main_toolbar_mode_changed.emit(TML3D_GlobalConstants.APP_SCATTER, false)


func _on_settings_button_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	if pressed:
		main_toolbar_mode_changed.emit(TML3D_GlobalConstants.APP_SETTINGS, false)

func _on_grid_snap_selected(index: int) -> void:
	if _updating_ui:
		return
	var snap_size: float = TML3D_EditorConst.GRID_SNAP_OPTIONS[index]
	grid_snap_size_changed.emit(snap_size)

func _on_cursor_step_selected(index: int) -> void:
	if _updating_ui:
		return
	var step_size: float = TML3D_EditorConst.CURSOR_STEP_OPTIONS[index]
	cursor_step_size_changed.emit(step_size)
