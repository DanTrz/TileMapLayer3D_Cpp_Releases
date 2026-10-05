@tool
class_name TML3D_TileContextToolbar
extends HBoxContainer

# --- Signals ---
signal rotate_btn_pressed(direction: int)  # +1 = CW, -1 = CCW

signal tilt_btn_pressed(reverse: bool)

signal reset_btn_pressed()

signal mirror_btn_pressed(enabled: bool)
## Emitted when Texture Rotation is pressed (+1, or -1 with Shift)
signal texture_rotation_btn_pressed(direction: int)

signal smart_select_dropdown_changed(smart_mode: int)

signal smart_select_additive_toggled(enabled: bool)

signal smart_select_operation_btn_pressed(smart_mode_operation: int)
signal mesh_mode_selection_changed(mesh_mode: int)
signal mesh_mode_depth_changed(depth: float)
signal arch_radius_ratio_changed(ratio: float)

signal sculp_brush_changed(brush_type: int, brush_size: float)

signal sculp_mode_options_changed(draw_top: bool, draw_bottom: bool, flip_sides: bool, flip_top: bool, flip_bottom: bool, build_with_depth: bool)

signal smart_operations_mode_changed(smart_mode: int)

signal smart_fill_changed(fill_mode: int, width: float, fill_direction: int, flip_face: bool, ramp_sides: bool, total_steps: int, freeze_uv: bool)

signal vertex_convert_pressed()

signal vertex_delete_pressed()

signal freeze_uv_changed(enabled: bool)
signal paint_uv_only_changed(enabled: bool)
signal place_opposite_changed(enabled: bool)

signal texture_repeat_mode_changed(mode: int)

signal depth_growth_mode_changed(mode: int)
signal scatter_detection_changed(mode: int, collision_mask: int)
signal scatter_brush_changed(tool: int, radius: float, density: float, scale_strength: float)

# --- Member Variables ---
@onready var main_tiling_group: FlowContainer = %MainTilingGroup
@onready var manual_mode_group: HBoxContainer = %ManualModeGroup
@onready var box_prism_group: HBoxContainer = %BoxPrismGroup

@onready var sculp_mode_group: FlowContainer = %SculpModeGroup

#smart operations groups
@onready var smart_operations_group: FlowContainer = %SmartOperationtGroup
@onready var smart_select_group: HBoxContainer = %SmartSelectGroup
@onready var smart_fill_group: FlowContainer = %SmartFillGroup
@onready var smart_select_operations_group: HBoxContainer = %SmartSelectOperationsGroup

# Vertex Edit group
@onready var vertex_edit_group: HBoxContainer = %VertexEditGroup
@onready var vertex_convert_btn: Button = %VertexConvertBtn
@onready var vertex_delete_btn: Button = %VertexDeleteBtn
@onready var scatter_mode_group: FlowContainer = %ScatterModeGroup
@onready var scatter_detection_mode: OptionButton = %ScatterDetectionMode
@onready var scatter_collision_mask: SpinBox = %ScatterCollisionMask
@onready var scatter_tool: OptionButton = %ScatterTool
@onready var scatter_brush_radius: SpinBox = %ScatterBrushRadius
@onready var scatter_density: SpinBox = %ScatterDensity
@onready var scatter_scale_strength: SpinBox = %ScatterScaleStrength

@onready var _rotate_right_btn: Button = %RotateRightBtn
@onready var _rotate_left_btn: Button = %RotateLeftBtn
@onready var _cycle_tilt_btn: Button = %CycleTiltBtn
@onready var _reset_orientation_btn: Button = %ResetOrientationBtn
## Mirror Texture button (F)
@onready var _mirror_face_btn: Button = %MirrorFaceBtn
## Texture Rotation button (G)
@onready var _texture_rotate_btn: Button = %TextureRotateBtn
## Freeze UV toggle (created programmatically after flip button)
@onready var _freeze_uv_btn: Button = %FreezeUVBtn
## Status label
@onready var _status_label: Label = %StatusLabel


@onready var smart_operation_opt_btn: OptionButton = %SmartOperationOptBtn
#Smart Select Controls
@onready var smart_select_mode_option_btn: OptionButton = %SmartSelectionModeOptBtn
@onready var smart_select_additive_btn: CheckButton = %SmartSelectAdditiveBtn
@onready var smart_select_replaceUV_btn: Button = %SmartSelectReplaceUVBtn
@onready var smart_select_delete_btn: Button = %SmartSelectDeleteBtn
@onready var smart_select_clear_btn: Button = %SmartSelectClearBtn
@onready var smart_select_replace_mesh_btn: Button = %SmartSelectReplaceMeshTypeBtn
@onready var smart_select_target_mesh_opt:OptionButton = %SmartSelectTargetMeshTypeOpt
@onready var mesh_depth_spin_box: SpinBox = %MeshDepthSpinBox
@onready var texture_repeat_checkbox: CheckBox = %TextureRepeatCheckbox 

@onready var smart_select_target_mesh_depth_group: HBoxContainer = %SmartSelectMeshReplaceDepthGroup

#Smart Fill Controls
@onready var smart_fill_mode_opt_btn: OptionButton = %SmartFillModeOptBtn
@onready var smart_fill_width_spin_box: SpinBox = %SmartFillWidthSpinBox
@onready var smart_fill_steps_group: HBoxContainer = %SmartFillStepsGroup
@onready var smart_fill_steps_auto_check_box: CheckBox = %SmartFillStepsAutoCheckBox
@onready var smart_fill_total_steps_spin_box: SpinBox = %SmartFillTotalStepsSpinBox
@onready var smart_fill_direction_opt_btn: OptionButton = %SmartFillDirectionOptBtn
@onready var smart_fill_face_flip_check_box: CheckBox = %SmartFillFaceFlipCheckBox
@onready var smart_fill_ramp_sides_check_box: CheckBox = %SmartFillRampSidesCheckBox
@onready var smart_fill_freeze_uv_check_box: CheckBox = %SmartFillFreezeUVCheckBox

@onready var mesh_mode_dropdown: TML3D_SquareOptionButton = %MeshModeDropdown
@onready var mesh_mode_depth_spin_box: SpinBox = %MeshModeDepthSpinBox

@onready var arch_radius_lbl: Label = %ArchRadiusLbl
@onready var arch_radius_spin_box: SpinBox = %ArchRadiusSpinBox
@onready var arch_tile_sculpt_options_container: HBoxContainer = %ArchTileSculptOptionsContainer
@onready var sculpt_arch_radius_spin_box: SpinBox = %SculptArchRadiusSpinBox

@onready var mesh_mode_label: Label = %MeshModeLabel
@onready var mesh_mode_depth_lbl: Label = %MeshModeDepthLbl
@onready var tile_world_pos_label: Label = %TileWorldPosLabel
@onready var tile_grid_pos_label: Label = %TileGridPosLabel


#Sculp Mode Controls
@onready var sculp_brush_dropdown: OptionButton = %SculpBrushDropdown
@onready var sculpt_brush_size_hslider: HSlider = %SculptBrushSizeHSlider

@onready var sculp_draw_top_check_box: CheckBox = %SculpDrawTopCheckBox
@onready var sculp_draw_bottom_check_box: CheckBox = %SculpDrawBottomCheckBox
@onready var sculp_flip_sides_check_box: CheckBox = %SculpFlipSidesCheckBox
@onready var sculp_flip_top_check_box: CheckBox = %SculpFlipTopCheckBox
@onready var sculp_flip_bottom_check_box: CheckBox = %SculpFlipBottomCheckBox
@onready var sculpt_depth_options_container: HBoxContainer = %SculptDepthOptionsContainer
@onready var sculpt_build_with_depth_check_box: CheckBox = %SculptBuildWithDepthCheckBox
@onready var sculpt_depth_spin_box: SpinBox = %SculptDepthSpinBox

#Box/Prism Mesh Depth and Texture Controls
@onready var box_texture_repeat_checkbox: CheckBox = %BoxTextureRepeatCheckbox
@onready var box_depth_inward_checkbox: CheckBox = %BoxDepthInwardCheckbox
@onready var mesh_replace_depth_inward_checkbox: CheckBox = %MeshReplaceDepthInwardCheckbox
@onready var paint_uv_only_check: CheckBox = %PaintUVonlyCheck
@onready var place_opposite_check: CheckBox = %PlaceOppositeCheck
@onready var place_opposite_sculpt_check: CheckBox = %PlaceOppositeSculptCheck

@onready var create_sprite_mesh_btn: Button = %CreateSpriteMeshBtn

var active_tile_map_layer3d: TileMapLayer3d_Cpp = null

# Animated tiles only support FLAT_SQUARE / BOX / PRISM / AUTOSHAPE (front-face animation).
# In anim mode, disable the other dropdown items; re-enable everything otherwise. Uses
# set_item_disabled (not item removal) so it composes with show_hide_arch_tiles' rebuild.
const _ANIM_SUPPORTED_MESH_MODES := [
	TML3D_GlobalConstants.FLAT_SQUARE,
	TML3D_GlobalConstants.BOX_MESH,
	TML3D_GlobalConstants.PRISM_MESH,
	TML3D_GlobalConstants.AUTOSHAPE_MESH,
]

## UI Variables
var _updating_ui: bool = false

# --- Initialization ---

func _init() -> void:
	name = "TileContextToolbar"


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

	#Rotate Right (Q)
	_rotate_right_btn.pressed.connect(_on_rotate_right_pressed)
	_apply_button_theme(_rotate_right_btn, "RotateRight", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	#Rotate Left (E)
	_rotate_left_btn.pressed.connect(_on_rotate_left_pressed)
	_apply_button_theme(_rotate_left_btn, "RotateLeft", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	# Tilt (R)
	_cycle_tilt_btn.pressed.connect(_on_tilt_pressed)
	_apply_button_theme(_cycle_tilt_btn, "FadeCross", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	# Reset (T)
	_reset_orientation_btn.pressed.connect(_on_reset_pressed)
	_apply_button_theme(_reset_orientation_btn, "EditorPositionUnselected", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	# Mirror Texture (F)
	_mirror_face_btn.toggled.connect(_on_mirror_toggled)
	_apply_button_theme(_mirror_face_btn, "ExpandTree", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	# Texture Rotation (G)
	_texture_rotate_btn.pressed.connect(_on_texture_rotate_pressed)
	_texture_rotate_btn.custom_minimum_size = Vector2.ONE * TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE * ui_scale
	_texture_rotate_btn.add_theme_font_size_override("font_size", int(10 * ui_scale))

	# Freeze UV toggle — insert after mirror button
	_freeze_uv_btn.toggled.connect(_on_freeze_uv_toggled)
	_apply_button_theme(_freeze_uv_btn, "Pin", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	create_sprite_mesh_btn.pressed.connect(_on_create_sprite_mesh_btn_pressed)
	_apply_button_theme(create_sprite_mesh_btn, "SpriteFrames", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	smart_select_replaceUV_btn.pressed.connect(_on_smart_select_replaceUV_pressed)
	_apply_button_theme(smart_select_replaceUV_btn, "Loop", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	smart_select_delete_btn.pressed.connect(_on_smart_select_delete_pressed)
	_apply_button_theme(smart_select_delete_btn, "Remove", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	smart_select_clear_btn.pressed.connect(_on_smart_select_clear_pressed)
	_apply_button_theme(smart_select_clear_btn, "Clear", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	smart_select_replace_mesh_btn.pressed.connect(_on_smart_select_replace_mesh_pressed)
	_apply_button_theme(smart_select_replace_mesh_btn, "MeshItem", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)

	smart_operation_opt_btn.item_selected.connect(on_smart_operations_dropdown_changed)
	smart_operation_opt_btn.add_theme_font_size_override("font_size", int(10 * ui_scale))
	smart_operation_opt_btn.custom_minimum_size.x = TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE * ui_scale

	smart_select_mode_option_btn.item_selected.connect(_on_smart_select_mode_changed)
	smart_select_mode_option_btn.add_theme_font_size_override("font_size", int(10 * ui_scale))
	smart_select_mode_option_btn.custom_minimum_size.x = TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE * ui_scale
	smart_select_additive_btn.toggled.connect(_on_smart_select_additive_toggled)
	smart_select_additive_btn.add_theme_font_size_override("font_size", int(10 * ui_scale))


	#Smart Select MESH REPLACE Options
	smart_select_target_mesh_opt.add_theme_font_size_override("font_size", int(10 * ui_scale))
	smart_select_target_mesh_opt.item_selected.connect(on_smart_select_target_mesh_changed)
	mesh_depth_spin_box.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))
	texture_repeat_checkbox.add_theme_font_size_override("font_size", int(10 * ui_scale))
	

	# --- Status Label ---
	_status_label.text = "0°"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# --- All other Labels ---

	# --- Spinbox controls  ---
	mesh_mode_depth_spin_box.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))
	arch_radius_spin_box.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))
	sculpt_arch_radius_spin_box.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))
	sculpt_depth_spin_box.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))

	mesh_mode_dropdown.item_selected.connect(_on_mesh_mode_selected)
	mesh_mode_depth_spin_box.value_changed.connect(_on_mesh_mode_depth_changed)
	sculpt_depth_spin_box.value_changed.connect(_on_mesh_mode_depth_changed)
	arch_radius_spin_box.value_changed.connect(_on_arch_radius_ratio_changed)
	sculpt_arch_radius_spin_box.value_changed.connect(_on_arch_radius_ratio_changed)

	#Sculp Mode controls
	sculp_brush_dropdown.item_selected.connect(_on_sculp_brush_selected)
	sculpt_brush_size_hslider.value_changed.connect(_on_sculpt_brush_size_changed)

	# Vertex Edit Controls
	vertex_convert_btn.pressed.connect(_on_vertex_convert_pressed)
	_apply_button_theme(vertex_convert_btn, "MeshItem", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)
	vertex_delete_btn.pressed.connect(_on_vertex_delete_pressed)
	_apply_button_theme(vertex_delete_btn, "Remove", TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE)
	scatter_detection_mode.item_selected.connect(_on_scatter_controls_changed)
	scatter_collision_mask.value_changed.connect(_on_scatter_mask_changed)
	scatter_tool.item_selected.connect(_on_scatter_brush_controls_changed)
	scatter_brush_radius.value_changed.connect(_on_scatter_brush_value_changed)
	scatter_density.value_changed.connect(_on_scatter_brush_value_changed)
	scatter_scale_strength.value_changed.connect(_on_scatter_brush_value_changed)

	#Smart Fill Controls
	smart_fill_mode_opt_btn.item_selected.connect(
		func (index: int) -> void: _emit_smart_fill_changed())

	smart_fill_width_spin_box.value_changed.connect(
		func (value: float) -> void: _emit_smart_fill_changed())
	smart_fill_steps_auto_check_box.toggled.connect(
		func (_enabled: bool) -> void: _emit_smart_fill_changed())
	smart_fill_freeze_uv_check_box.toggled.connect(
		func (_enabled: bool) -> void: _emit_smart_fill_changed())
	smart_fill_total_steps_spin_box.value_changed.connect(
		func (_value: float) -> void: _emit_smart_fill_changed())

	smart_fill_direction_opt_btn.item_selected.connect(
		func (index: int) -> void: _emit_smart_fill_changed())

	smart_fill_face_flip_check_box.pressed.connect(
		func () -> void: _emit_smart_fill_changed())

	smart_fill_ramp_sides_check_box.pressed.connect(
		func () -> void: _emit_smart_fill_changed())

	sculp_draw_top_check_box.pressed.connect(_on_sculpt_mode_ui_changed)
	sculp_draw_bottom_check_box.pressed.connect(_on_sculpt_mode_ui_changed)
	sculp_flip_sides_check_box.pressed.connect(_on_sculpt_mode_ui_changed)
	sculp_flip_top_check_box.pressed.connect(_on_sculpt_mode_ui_changed)
	sculp_flip_bottom_check_box.pressed.connect(_on_sculpt_mode_ui_changed)
	sculpt_build_with_depth_check_box.pressed.connect(_on_sculpt_mode_ui_changed)


	#Setup Box/Prism Controls and UI elements
	box_texture_repeat_checkbox.toggled.connect(_on_texture_repeat_checkbox_toggled)
	box_texture_repeat_checkbox.add_theme_font_size_override("font_size", int(10 * ui_scale))
	box_texture_repeat_checkbox.button_pressed = true
	_on_texture_repeat_checkbox_toggled(true)

	box_depth_inward_checkbox.toggled.connect(_on_depth_inward_checkbox_toggled)
	box_depth_inward_checkbox.add_theme_font_size_override("font_size", int(10 * ui_scale))
	box_depth_inward_checkbox.button_pressed = true
	_on_depth_inward_checkbox_toggled(true)

	paint_uv_only_check.toggled.connect(_on_paint_uv_only_toggled)
	paint_uv_only_check.add_theme_font_size_override("font_size", int(10 * ui_scale))

	place_opposite_check.toggled.connect(_on_place_opposite_toggled)
	place_opposite_sculpt_check.toggled.connect(_on_place_opposite_toggled)
	place_opposite_check.add_theme_font_size_override("font_size", int(10 * ui_scale))
	place_opposite_sculpt_check.add_theme_font_size_override("font_size", int(10 * ui_scale))




func set_mirrored(mirrored: bool) -> void:
	_updating_ui = true
	_mirror_face_btn.button_pressed = mirrored
	_updating_ui = false


func set_texture_rotation(steps: int) -> void:
	if _texture_rotate_btn:
		_texture_rotate_btn.text = "UV " + str(steps * 90) + "°"


func is_mirrored() -> bool:
	return _mirror_face_btn.button_pressed if _mirror_face_btn else false


func set_freeze_uv(enabled: bool) -> void:
	_updating_ui = true
	if _freeze_uv_btn:
		_freeze_uv_btn.button_pressed = enabled
	_updating_ui = false

func set_smart_select_additive(enabled: bool) -> void:
	_updating_ui = true
	if smart_select_additive_btn:
		smart_select_additive_btn.button_pressed = enabled
	_updating_ui = false

func set_paint_uv_only(enabled: bool) -> void:
	_updating_ui = true
	if paint_uv_only_check:
		paint_uv_only_check.button_pressed = enabled
	_updating_ui = false

func _select_option_by_item_id(option_button: OptionButton, item_id: int, fallback_item_id: int = 0) -> int:
	if not option_button:
		return -1
	for i: int in range(option_button.item_count):
		if option_button.get_item_id(i) == item_id:
			option_button.select(i)
			return item_id
	for i: int in range(option_button.item_count):
		if option_button.get_item_id(i) == fallback_item_id:
			option_button.select(i)
			return fallback_item_id
	if option_button.item_count > 0:
		option_button.select(0)
		return option_button.get_item_id(0)
	return -1

func set_mesh_mode(mesh_mode: int) -> void:
	_updating_ui = true
	var synced_mesh_mode: int = _select_option_by_item_id(mesh_mode_dropdown, mesh_mode, TML3D_GlobalConstants.FLAT_SQUARE)
	_update_mesh_mode_controls_visibility(synced_mesh_mode)
	box_prism_group.visible = true if (synced_mesh_mode == TML3D_GlobalConstants.BOX_MESH or synced_mesh_mode == TML3D_GlobalConstants.PRISM_MESH or synced_mesh_mode == TML3D_GlobalConstants.AUTOSHAPE_MESH) else false
	_updating_ui = false


func update_status(rotation_steps: int, tilt_index: int, is_mirrored: bool, texture_rotation: int = 0) -> void:
	if not _status_label:
		return

	var rotation_deg: int = rotation_steps * 90
	var parts: PackedStringArray = []

	# Rotation
	parts.append(str(rotation_deg) + "°")

	# Tilt indicator
	if tilt_index > 0:
		parts.append("T" + str(tilt_index))

	# Mirror indicator
	if is_mirrored:
		parts.append("M")

	if texture_rotation != 0:
		parts.append("UV" + str(texture_rotation * 90))

	_status_label.text = " ".join(parts)

	# Update mirror button state
	_updating_ui = true
	_mirror_face_btn.button_pressed = is_mirrored
	_updating_ui = false
	set_texture_rotation(texture_rotation)



func sync_from_settings(tilemaplayer3d: TileMapLayer3d_Cpp) -> void:
	if not tilemaplayer3d:
		return
	_updating_ui = true
	active_tile_map_layer3d = tilemaplayer3d

	if active_tile_map_layer3d.settings:
		show_hide_arch_tiles(active_tile_map_layer3d.settings.enable_arched_tiles, active_tile_map_layer3d.settings.show_arched_tiles_on_manual_mode)
		scatter_detection_mode.select(active_tile_map_layer3d.settings.scatter_detection_mode)
		scatter_collision_mask.value = active_tile_map_layer3d.settings.scatter_collision_mask
		scatter_tool.select(active_tile_map_layer3d.settings.scatter_tool)
		scatter_brush_radius.value = active_tile_map_layer3d.settings.scatter_brush_radius
		scatter_density.value = active_tile_map_layer3d.settings.scatter_density
		scatter_scale_strength.value = active_tile_map_layer3d.settings.scatter_scale_strength

		# Sync BOX/PRISM texture repeat mode checkbox
	if box_texture_repeat_checkbox:
		box_texture_repeat_checkbox.button_pressed = (active_tile_map_layer3d.settings.texture_repeat_mode == TML3D_GlobalConstants.TEX_REPEAT_REPEAT)

	# Sync BOX/PRISM depth inward checkbox
	if box_depth_inward_checkbox:
		box_depth_inward_checkbox.button_pressed = (active_tile_map_layer3d.settings.depth_growth_mode == TML3D_GlobalConstants.INWARD)

	# Sync Paint UV Only checkbox
	if paint_uv_only_check:
		paint_uv_only_check.button_pressed = active_tile_map_layer3d.settings.paint_uv_only

	if place_opposite_check:
		place_opposite_check.button_pressed = active_tile_map_layer3d.settings.place_opposite_tile
		place_opposite_sculpt_check.button_pressed = active_tile_map_layer3d.settings.place_opposite_tile

	if place_opposite_sculpt_check:
		place_opposite_sculpt_check.button_pressed = active_tile_map_layer3d.settings.place_opposite_tile
	# UI Items to sync:
	smart_select_mode_option_btn.select(active_tile_map_layer3d.settings.smart_select_mode)
	if smart_select_additive_btn:
		smart_select_additive_btn.button_pressed = active_tile_map_layer3d.settings.smart_select_additive
	smart_operation_opt_btn.selected = active_tile_map_layer3d.settings.smart_operations_main_mode

	smart_fill_mode_opt_btn.select(smart_fill_mode_opt_btn.get_item_index(active_tile_map_layer3d.settings.smart_fill_mode))
	smart_fill_width_spin_box.value = active_tile_map_layer3d.settings.smart_fill_width
	smart_fill_direction_opt_btn.selected = active_tile_map_layer3d.settings.smart_fill_quad_growth_dir
	smart_fill_face_flip_check_box.button_pressed = active_tile_map_layer3d.settings.smart_fill_flip_face
	smart_fill_ramp_sides_check_box.button_pressed = active_tile_map_layer3d.settings.smart_fill_ramp_sides
	smart_fill_freeze_uv_check_box.set_pressed_no_signal(active_tile_map_layer3d.settings.smart_fill_freeze_uv)
	var total_steps: int = active_tile_map_layer3d.settings.smart_fill_total_steps
	smart_fill_steps_auto_check_box.set_pressed_no_signal(total_steps == 0)
	if total_steps > 0:
		smart_fill_total_steps_spin_box.set_value_no_signal(total_steps)
	_update_stair_steps_controls()

	var synced_mesh_mode: int = _select_option_by_item_id(mesh_mode_dropdown, active_tile_map_layer3d.settings.mesh_mode, TML3D_GlobalConstants.FLAT_SQUARE)
	mesh_mode_depth_spin_box.value = active_tile_map_layer3d.settings.current_depth_scale
	sculpt_depth_spin_box.value = active_tile_map_layer3d.settings.current_depth_scale
	arch_radius_spin_box.value = active_tile_map_layer3d.settings.arch_radius_ratio
	sculpt_arch_radius_spin_box.value = active_tile_map_layer3d.settings.arch_radius_ratio
	_update_mesh_mode_controls_visibility(synced_mesh_mode)



	sculp_brush_dropdown.selected = active_tile_map_layer3d.settings.sculpt_brush_type
	sculpt_brush_size_hslider.value = active_tile_map_layer3d.settings.sculpt_brush_size
	sculp_draw_bottom_check_box.button_pressed = active_tile_map_layer3d.settings.sculpt_draw_bottom
	sculp_draw_top_check_box.button_pressed = active_tile_map_layer3d.settings.sculpt_draw_top
	sculp_flip_sides_check_box.button_pressed = active_tile_map_layer3d.settings.sculpt_flip_sides
	sculp_flip_top_check_box.button_pressed = active_tile_map_layer3d.settings.sculpt_flip_top
	sculp_flip_bottom_check_box.button_pressed = active_tile_map_layer3d.settings.sculpt_flip_bottom
	sculpt_build_with_depth_check_box.button_pressed = active_tile_map_layer3d.settings.sculpt_build_with_depth
	_update_sculpt_depth_ui()


	if _freeze_uv_btn:
		_freeze_uv_btn.button_pressed = active_tile_map_layer3d.settings.freeze_uv_on_rotation
	if _mirror_face_btn:
		_mirror_face_btn.button_pressed = active_tile_map_layer3d.settings.get_is_texture_mirrored()
	set_texture_rotation(active_tile_map_layer3d.settings.current_texture_rotation)




	# Sync visibility from mode + smart select state
	match active_tile_map_layer3d.settings.main_app_mode:
		TML3D_GlobalConstants.APP_MANUAL:
			main_tiling_group.visible = true
			manual_mode_group.visible = true
			smart_operations_group.visible = false
			sculp_mode_group.visible = false
			vertex_edit_group.visible = false
			self.visible = true
		TML3D_GlobalConstants.APP_AUTOTILE:
			main_tiling_group.visible = true
			manual_mode_group.visible = false
			smart_operations_group.visible = false
			sculp_mode_group.visible = false
			vertex_edit_group.visible = false
			self.visible = true
		TML3D_GlobalConstants.APP_SMART_OPERATIONS:
			main_tiling_group.visible = false
			manual_mode_group.visible = false
			smart_operations_group.visible = true
			sculp_mode_group.visible = false
			vertex_edit_group.visible = false
			self.visible = true
		TML3D_GlobalConstants.APP_ANIMATED_TILES:
			# Animated tiles can use FLAT_SQUARE / BOX / PRISM / AUTOSHAPE (front-face animation).
			# Show the mesh-mode dropdown (+ depth), restricted to those modes; hide the rest.
			main_tiling_group.visible = true
			manual_mode_group.visible = false
			smart_operations_group.visible = false
			sculp_mode_group.visible = false
			vertex_edit_group.visible = false
			self.visible = true
		TML3D_GlobalConstants.APP_SCULPT:
			main_tiling_group.visible = false
			manual_mode_group.visible = false
			smart_operations_group.visible = false
			sculp_mode_group.visible = true
			vertex_edit_group.visible = false
			self.visible = true
		TML3D_GlobalConstants.APP_VERTEX_EDIT:
			main_tiling_group.visible = false
			manual_mode_group.visible = false
			smart_operations_group.visible = false
			sculp_mode_group.visible = false
			vertex_edit_group.visible = true
			self.visible = true
		TML3D_GlobalConstants.APP_SCATTER:
			main_tiling_group.visible = false
			manual_mode_group.visible = false
			smart_operations_group.visible = false
			sculp_mode_group.visible = false
			vertex_edit_group.visible = false
			self.visible = true
		TML3D_GlobalConstants.APP_SETTINGS:
			self.visible = false
		_:
			main_tiling_group.visible = true
			manual_mode_group.visible = true
			smart_operations_group.visible = true
			sculp_mode_group.visible = true
			vertex_edit_group.visible = false
			self.visible = true

	_apply_anim_mode_mesh_restriction(active_tile_map_layer3d.settings.main_app_mode == TML3D_GlobalConstants.APP_ANIMATED_TILES)
	scatter_mode_group.visible = active_tile_map_layer3d.settings.main_app_mode == TML3D_GlobalConstants.APP_SCATTER
	place_opposite_check.visible = active_tile_map_layer3d.settings.main_app_mode in [
		TML3D_GlobalConstants.APP_MANUAL,
		TML3D_GlobalConstants.APP_AUTOTILE,
		TML3D_GlobalConstants.APP_ANIMATED_TILES,
		TML3D_GlobalConstants.APP_SCULPT,
	]

	var current_mesh_id: int = mesh_mode_dropdown.get_selected_id()
	# AUTOSHAPE also extrudes with depth, so it shares the box/prism depth control.
	box_prism_group.visible = true if (current_mesh_id == TML3D_GlobalConstants.BOX_MESH or current_mesh_id == TML3D_GlobalConstants.PRISM_MESH or current_mesh_id == TML3D_GlobalConstants.AUTOSHAPE_MESH) else false

	on_smart_operations_dropdown_changed(active_tile_map_layer3d.settings.smart_operations_main_mode)
	_updating_ui = false

	on_smart_select_target_mesh_changed(smart_select_target_mesh_opt.selected) # Update visibility of depth and texture repeat controls

func show_hide_arch_tiles(enable_arched_tiles: bool, show_arched_tiles_on_manual_mode: bool) -> void:
	mesh_mode_dropdown.create_items_from_enum()
	sculp_brush_dropdown.create_items_from_enum()
	arch_tile_sculpt_options_container.visible = enable_arched_tiles

	# Emits directly: the item_selected handlers early-return while _updating_ui is set.
	if not enable_arched_tiles or not show_arched_tiles_on_manual_mode:
		for i: int in range(mesh_mode_dropdown.item_count - 1, -1, -1):
			if TML3D_GlobalConstants.is_arch_mode(mesh_mode_dropdown.get_item_id(i)):
				mesh_mode_dropdown.remove_item(i)
		var mesh_mode: int = _select_option_by_item_id(mesh_mode_dropdown,
			active_tile_map_layer3d.settings.mesh_mode, TML3D_GlobalConstants.FLAT_SQUARE)
		if mesh_mode != active_tile_map_layer3d.settings.mesh_mode:
			mesh_mode_selection_changed.emit(mesh_mode)

	if not enable_arched_tiles:
		for i: int in range(sculp_brush_dropdown.item_count - 1, -1, -1):
			if sculp_brush_dropdown.get_item_id(i) == TML3D_GlobalConstants.ARCHED_RECT:
				sculp_brush_dropdown.remove_item(i)
		var brush: int = _select_option_by_item_id(sculp_brush_dropdown,
			active_tile_map_layer3d.settings.sculpt_brush_type, TML3D_GlobalConstants.DIAMOND)
		if brush != active_tile_map_layer3d.settings.sculpt_brush_type:
			sculp_brush_changed.emit(brush, sculpt_brush_size_hslider.value)
	_update_sculpt_depth_ui()




func _apply_anim_mode_mesh_restriction(restrict: bool) -> void:
	for i: int in mesh_mode_dropdown.item_count:
		var item_id: int = mesh_mode_dropdown.get_item_id(i)
		mesh_mode_dropdown.set_item_disabled(i, restrict and not _ANIM_SUPPORTED_MESH_MODES.has(item_id))
	if restrict and not _ANIM_SUPPORTED_MESH_MODES.has(mesh_mode_dropdown.get_selected_id()):
		_select_option_by_item_id(mesh_mode_dropdown, TML3D_GlobalConstants.FLAT_SQUARE, TML3D_GlobalConstants.FLAT_SQUARE)
		mesh_mode_selection_changed.emit(TML3D_GlobalConstants.FLAT_SQUARE)

func update_tile_position(world_pos: Vector3, grid_pos: Vector3, current_plane: int) -> void:

	var align_offset: Vector3 = TML3D_GlobalConstants.get_GRID_ALIGNMENT_OFFSET()
	match current_plane:
		0, 1:
			grid_pos.y += align_offset.y # Y plane
		2, 3:
			grid_pos.z += align_offset.z # Z plane
		4, 5:
			grid_pos.x += align_offset.x # X plane
		_:
			pass

	if tile_world_pos_label:
		tile_world_pos_label.text = "World: (%.1f, %.1f, %.1f)" % [world_pos.x, world_pos.y, world_pos.z]
	if tile_grid_pos_label:
		tile_grid_pos_label.text = "Grid: (%.1f, %.1f, %.1f)" % [grid_pos.x, grid_pos.y, grid_pos.z]
# --- Signal Handlers ---

func _on_rotate_right_pressed() -> void:
	rotate_btn_pressed.emit(-1)


func _on_rotate_left_pressed() -> void:
	rotate_btn_pressed.emit(+1)


func _on_tilt_pressed() -> void:
	# Check if shift is held for reverse tilt
	var reverse: bool = Input.is_key_pressed(KEY_SHIFT)
	tilt_btn_pressed.emit(reverse)


func _on_reset_pressed() -> void:
	reset_btn_pressed.emit()


func _on_mirror_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	mirror_btn_pressed.emit(pressed)


func _on_texture_rotate_pressed() -> void:
	texture_rotation_btn_pressed.emit(-1 if Input.is_key_pressed(KEY_SHIFT) else 1)


func _on_freeze_uv_toggled(pressed: bool) -> void:
	# Runs for programmatic changes too (set_freeze_uv, sync_from_settings), so the lock always matches.
	# Freeze UV keeps the texture fixed, so the Texture Rotation button is locked while it is on.
	if _texture_rotate_btn:
		_texture_rotate_btn.disabled = pressed
	if _updating_ui:
		return
	freeze_uv_changed.emit(pressed)


func _on_scatter_controls_changed(mode: int) -> void:
	if _updating_ui:
		return
	scatter_detection_changed.emit(mode, int(scatter_collision_mask.value))


func _on_scatter_mask_changed(_value: float) -> void:
	if _updating_ui:
		return
	scatter_detection_changed.emit(scatter_detection_mode.get_selected_id(), int(scatter_collision_mask.value))


func _on_scatter_brush_controls_changed(_index: int) -> void:
	_emit_scatter_brush_changed()


func _on_scatter_brush_value_changed(_value: float) -> void:
	_emit_scatter_brush_changed()


func _emit_scatter_brush_changed() -> void:
	if _updating_ui:
		return
	scatter_brush_changed.emit(
		scatter_tool.get_selected_id(),
		scatter_brush_radius.value,
		scatter_density.value,
		scatter_scale_strength.value
	)

func _on_create_sprite_mesh_btn_pressed() -> void:
	# Emit event to generate sprite mesh from current selection
	if not active_tile_map_layer3d or not active_tile_map_layer3d.settings or active_tile_map_layer3d.settings.selected_tiles.size() == 0:
		push_warning("SpriteMesh error: No tile selected for SpriteMesh generation")
		return

	if active_tile_map_layer3d.settings.tileset_texture == null:
		push_warning("SpriteMesh error: No texture loaded for SpriteMesh generation")
		return

	var current_grid_size: float = active_tile_map_layer3d.settings.grid_size
	current_grid_size = current_grid_size if current_grid_size > 0 else TML3D_GlobalConstants.get_DEFAULT_GRID_SIZE()

	var filter_mode: int = active_tile_map_layer3d.settings.texture_filter_mode


	TML3D_GlobalTileMapEvents.emit_request_sprite_mesh_creation(active_tile_map_layer3d.settings.tileset_texture, active_tile_map_layer3d.settings.selected_tiles, active_tile_map_layer3d.settings.tile_size, current_grid_size, filter_mode)

func _on_mesh_mode_selected(index: int) -> void:
	if _updating_ui:
		return
	var selected_mode: int = mesh_mode_dropdown.get_selected_id()
	_update_mesh_mode_controls_visibility(selected_mode)

	mesh_mode_selection_changed.emit(selected_mode)

	# AUTOSHAPE also extrudes with depth, so it shares the box/prism depth control.
	box_prism_group.visible = true if (selected_mode == TML3D_GlobalConstants.BOX_MESH or selected_mode == TML3D_GlobalConstants.PRISM_MESH or selected_mode == TML3D_GlobalConstants.AUTOSHAPE_MESH) else false


func _on_mesh_mode_depth_changed(value: float) -> void:
	if _updating_ui:
		return
	_updating_ui = true
	mesh_mode_depth_spin_box.value = value
	sculpt_depth_spin_box.value = value
	_updating_ui = false
	mesh_mode_depth_changed.emit(value)

func _on_arch_radius_ratio_changed(value: float) -> void:
	if _updating_ui:
		return
	# Both spinboxes edit settings.arch_radius_ratio; mirror the other one so they can't drift.
	_updating_ui = true
	arch_radius_spin_box.value = value
	sculpt_arch_radius_spin_box.value = value
	_updating_ui = false
	arch_radius_ratio_changed.emit(value)

func _update_mesh_mode_controls_visibility(mesh_mode: int) -> void:
	var is_arch: bool = TML3D_GlobalConstants.is_arch_mode(mesh_mode)
	arch_radius_lbl.visible = is_arch
	arch_radius_spin_box.visible = is_arch

func on_smart_operations_dropdown_changed(index_mode: int) -> void:
	smart_operations_mode_changed.emit(index_mode)

	smart_select_group.visible = false
	smart_fill_group.visible = false
	_set_smart_select_operations_visible(index_mode == TML3D_GlobalConstants.SMART_SELECT)
	match index_mode:
		TML3D_GlobalConstants.SMART_FILL:
			smart_fill_group.visible = true
		TML3D_GlobalConstants.SMART_SELECT:
			smart_select_group.visible = true
		TML3D_GlobalConstants.PATTERNS_FILL:
			smart_select_group.visible = true



func _set_smart_select_operations_visible(visible: bool) -> void:
	smart_select_operations_group.visible = visible

func _on_smart_select_mode_changed(mode: int) -> void:
	if _updating_ui:
		return

	smart_select_dropdown_changed.emit(smart_select_mode_option_btn.get_selected_id())


func _on_smart_select_additive_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	smart_select_additive_toggled.emit(pressed)


func _on_smart_select_replaceUV_pressed() -> void:
	smart_select_operation_btn_pressed.emit(TML3D_GlobalConstants.REPLACE_UV)


func _on_smart_select_delete_pressed() -> void:
	smart_select_operation_btn_pressed.emit(TML3D_GlobalConstants.DELETE)


func _on_smart_select_clear_pressed() -> void:
	smart_select_operation_btn_pressed.emit(TML3D_GlobalConstants.CLEAR)


func _on_smart_select_replace_mesh_pressed() -> void:
	smart_select_operation_btn_pressed.emit(TML3D_GlobalConstants.REPLACE_MESH_TYPE)


func on_smart_select_target_mesh_changed(index: int) -> void:
	var target_mode: int = smart_select_target_mesh_opt.get_item_id(index) if index >= 0 and index < smart_select_target_mesh_opt.item_count else smart_select_target_mesh_opt.get_selected_id()
	smart_select_target_mesh_depth_group.visible = (
		target_mode == TML3D_GlobalConstants.BOX_MESH
		or target_mode == TML3D_GlobalConstants.PRISM_MESH
		or target_mode == TML3D_GlobalConstants.AUTOSHAPE_MESH
	)

## Target mesh type chosen in the Smart Select group, used by the Replace Mesh Type op.
## Item IDs are aligned to MeshMode constants, including sparse values such as AUTOSHAPE_MESH.
func get_smart_select_target_mesh_mode() -> int:
	return smart_select_target_mesh_opt.get_selected_id()

func get_smart_depth_scale() -> float:
	return mesh_depth_spin_box.value

func get_smart_texture_repeat_mode() -> int:
	return TML3D_GlobalConstants.TEX_REPEAT_REPEAT if texture_repeat_checkbox.button_pressed else TML3D_GlobalConstants.TEX_REPEAT_DEFAULT

## Depth growth direction for Smart Replace Mesh Type (checked = INWARD).
func get_smart_select_depth_growth_mode() -> int:
	if mesh_replace_depth_inward_checkbox and mesh_replace_depth_inward_checkbox.button_pressed:
		return TML3D_GlobalConstants.INWARD
	return TML3D_GlobalConstants.OUTWARD

func _on_sculp_brush_selected(index: int) -> void:
	_update_sculpt_depth_ui()
	sculp_brush_changed.emit(sculp_brush_dropdown.get_selected_id(), sculpt_brush_size_hslider.value)

func _on_sculpt_brush_size_changed(value: float) -> void:
	sculp_brush_changed.emit(sculp_brush_dropdown.get_selected_id(), sculpt_brush_size_hslider.value)

func _on_sculpt_mode_ui_changed() -> void:
	_update_sculpt_depth_ui()
	sculp_mode_options_changed.emit(
		sculp_draw_top_check_box.button_pressed,
		sculp_draw_bottom_check_box.button_pressed,
		sculp_flip_sides_check_box.button_pressed,
		sculp_flip_top_check_box.button_pressed,
		sculp_flip_bottom_check_box.button_pressed,
		sculpt_build_with_depth_check_box.button_pressed)

func _update_sculpt_depth_ui() -> void:
	var brush: int = sculp_brush_dropdown.get_selected_id()
	var supports_depth: bool = brush == TML3D_GlobalConstants.DIAMOND or brush == TML3D_GlobalConstants.BRUSH_SQUARE
	var depth_enabled: bool = supports_depth and sculpt_build_with_depth_check_box.button_pressed
	arch_tile_sculpt_options_container.visible = brush == TML3D_GlobalConstants.ARCHED_RECT
	sculpt_depth_options_container.visible = supports_depth
	sculpt_depth_spin_box.editable = depth_enabled
	sculp_flip_sides_check_box.disabled = depth_enabled
	sculp_flip_top_check_box.disabled = depth_enabled
	sculp_flip_bottom_check_box.disabled = depth_enabled

func _update_stair_steps_controls() -> void:
	smart_fill_steps_group.visible = smart_fill_mode_opt_btn.get_selected_id() == TML3D_GlobalConstants.FILL_STAIRS
	smart_fill_freeze_uv_check_box.visible = smart_fill_steps_group.visible
	smart_fill_total_steps_spin_box.visible = not smart_fill_steps_auto_check_box.button_pressed

func _emit_smart_fill_changed() -> void:
	if _updating_ui:
		return
	_update_stair_steps_controls()
	smart_fill_changed.emit(
		smart_fill_mode_opt_btn.get_selected_id(),
		smart_fill_width_spin_box.value,
		smart_fill_direction_opt_btn.get_selected_id(),
		smart_fill_face_flip_check_box.button_pressed,
		smart_fill_ramp_sides_check_box.button_pressed,
		0 if smart_fill_steps_auto_check_box.button_pressed else int(smart_fill_total_steps_spin_box.value),
		smart_fill_freeze_uv_check_box.button_pressed)


# --- Vertex Edit Handlers ---

func _on_vertex_convert_pressed() -> void:
	vertex_convert_pressed.emit()


func _on_vertex_delete_pressed() -> void:
	vertex_delete_pressed.emit()


# --- Box/Prism Controls and Handlers ---

## Handler for BOX/PRISM texture repeat checkbox toggle
func _on_texture_repeat_checkbox_toggled(check_box_pressed: bool) -> void:
	if _updating_ui:
		return

	var texture_mode: int = TML3D_GlobalConstants.TEX_REPEAT_REPEAT if check_box_pressed else TML3D_GlobalConstants.TEX_REPEAT_DEFAULT

	texture_repeat_mode_changed.emit(texture_mode)

## Handler for BOX/PRISM depth inward checkbox toggle
func _on_depth_inward_checkbox_toggled(check_box_pressed: bool) -> void:
	if _updating_ui:
		return

	var depth_growth_mode: int = TML3D_GlobalConstants.INWARD if check_box_pressed else TML3D_GlobalConstants.OUTWARD

	depth_growth_mode_changed.emit(depth_growth_mode)


## Handler for the Paint UV Only checkbox (repaint existing tiles' UV without touching geometry).
func _on_paint_uv_only_toggled(check_box_pressed: bool) -> void:
	if _updating_ui:
		return

	paint_uv_only_changed.emit(check_box_pressed)


func _on_place_opposite_toggled(check_box_pressed: bool) -> void:
	if _updating_ui:
		return

	place_opposite_changed.emit(check_box_pressed)
