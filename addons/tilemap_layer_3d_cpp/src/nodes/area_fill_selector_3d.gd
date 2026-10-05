@tool
class_name TML3D_AreaFillSelector3D
extends Node3D

## Area Fill Selection Visualizer for TileMapLayer3d_Cpp.
## Visual feedback during Shift+Drag area selection for paint/erase fill.
## Pattern (Signal UP, Call DOWN): plugin calls start/update/complete_selection;
## this node emits selection_started/updated/completed/cancelled.

# --- Signals ---
signal selection_started(start_pos: Vector3, orientation: int)
signal selection_updated(start_pos: Vector3, end_pos: Vector3, orientation: int)
signal selection_completed(min_pos: Vector3, max_pos: Vector3, orientation: int)
signal selection_cancelled()

# --- Exported Properties ---
@export_category("Selection Box")

@export var grid_size: float = TML3D_GlobalConstants.get_DEFAULT_GRID_SIZE():
	set(value):
		if grid_size != value:
			grid_size = value
			if not Engine.is_editor_hint(): return
			_update_visuals()

@export var box_color: Color = TML3D_EditorConst.AREA_FILL_BOX_COLOR:
	set(value):
		if box_color != value:
			box_color = value
			if not Engine.is_editor_hint(): return
			_update_box_material()

@export var grid_line_color: Color = TML3D_EditorConst.AREA_FILL_GRID_LINE_COLOR:
	set(value):
		if grid_line_color != value:
			grid_line_color = value
			if not Engine.is_editor_hint(): return
			_update_grid_material()

# --- Private State ---
var is_selecting: bool = false
var start_grid_pos: Vector3 = Vector3.ZERO
var end_grid_pos: Vector3 = Vector3.ZERO
var current_orientation: int = 0
var current_plane: Vector3 = Vector3.UP

var _box_mesh: MeshInstance3D = null
var _grid_lines: MeshInstance3D = null

# --- Lifecycle ---
func _ready() -> void:
	if not Engine.is_editor_hint(): return
	_create_selection_box()
	_create_grid_lines()
	visible = false

# --- Public API ---
func start_selection(grid_pos: Vector3, orientation: int, plane: Vector3) -> void:
	if not Engine.is_editor_hint(): return
	is_selecting = true
	start_grid_pos = grid_pos
	end_grid_pos = grid_pos
	current_orientation = orientation
	current_plane = plane
	visible = true
	_update_visuals()
	selection_started.emit(grid_pos, orientation)

func update_selection(new_end_pos: Vector3) -> void:
	if not Engine.is_editor_hint(): return
	if not is_selecting:
		return
	end_grid_pos = new_end_pos
	_update_visuals()
	selection_updated.emit(start_grid_pos, end_grid_pos, current_orientation)

func complete_selection() -> Dictionary:
	if not Engine.is_editor_hint(): return {}
	if not is_selecting:
		return {}

	var min_pos: Vector3 = Vector3(
		min(start_grid_pos.x, end_grid_pos.x),
		min(start_grid_pos.y, end_grid_pos.y),
		min(start_grid_pos.z, end_grid_pos.z)
	)
	var max_pos: Vector3 = Vector3(
		max(start_grid_pos.x, end_grid_pos.x),
		max(start_grid_pos.y, end_grid_pos.y),
		max(start_grid_pos.z, end_grid_pos.z)
	)

	var size: Vector3 = max_pos - min_pos
	var min_size: Vector3 = TML3D_EditorConst.MIN_AREA_FILL_SIZE
	if size.x < min_size.x and size.y < min_size.y and size.z < min_size.z:
		cancel_selection()
		return {}

	is_selecting = false
	visible = false

	var result: Dictionary = {
		"min_pos": min_pos,
		"max_pos": max_pos,
		"orientation": current_orientation
	}
	selection_completed.emit(min_pos, max_pos, current_orientation)
	return result

func cancel_selection() -> void:
	if not Engine.is_editor_hint(): return
	is_selecting = false
	visible = false
	selection_cancelled.emit()

# --- Visual Creation ---
func _create_selection_box() -> void:
	if not Engine.is_editor_hint(): return
	_box_mesh = MeshInstance3D.new()
	_box_mesh.name = "SelectionBox"
	_box_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(grid_size, grid_size, grid_size)
	_box_mesh.mesh = box

	_box_mesh.material_override = TML3D_GlobalUtil.create_area_selection_material()

	add_child(_box_mesh)

func _create_grid_lines() -> void:
	if not Engine.is_editor_hint(): return
	_grid_lines = MeshInstance3D.new()
	_grid_lines.name = "GridLines"
	_grid_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Local material (needs no_depth_test + cull settings specific to this use case);
	# render priority 1 above AREA_FILL so grid lines draw above the box.
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = grid_line_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.render_priority = TML3D_GlobalConstants.AREA_FILL_RENDER_PRIORITY + 1
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_grid_lines.material_override = material
	add_child(_grid_lines)

# --- Visual Updates ---
func _update_visuals() -> void:
	if not Engine.is_editor_hint(): return
	if not _box_mesh or not _grid_lines:
		return

	var min_pos: Vector3 = Vector3(
		min(start_grid_pos.x, end_grid_pos.x),
		min(start_grid_pos.y, end_grid_pos.y),
		min(start_grid_pos.z, end_grid_pos.z)
	)
	var max_pos: Vector3 = Vector3(
		max(start_grid_pos.x, end_grid_pos.x),
		max(start_grid_pos.y, end_grid_pos.y),
		max(start_grid_pos.z, end_grid_pos.z)
	)

	var center_grid: Vector3 = (min_pos + max_pos) / 2.0
	var size_grid: Vector3 = max_pos - min_pos + Vector3.ONE

	var center_world: Vector3 = TML3D_GlobalUtil.grid_to_world(center_grid, grid_size)
	var size_world: Vector3 = size_grid * grid_size

	_update_box(center_world, size_world)
	_update_grid(min_pos, max_pos)

func _update_box(center: Vector3, size: Vector3) -> void:
	if not Engine.is_editor_hint(): return
	if not _box_mesh:
		return
	_box_mesh.position = center
	var box_mesh_data: BoxMesh = _box_mesh.mesh as BoxMesh
	if box_mesh_data:
		box_mesh_data.size = size

func _update_grid(min_grid: Vector3, max_grid: Vector3) -> void:
	if not Engine.is_editor_hint(): return
	if not _grid_lines:
		return
	# Grid line rendering skipped (parity with legacy — box visualization only).
	_grid_lines.visible = false

func _update_box_material() -> void:
	if not Engine.is_editor_hint(): return
	if not _box_mesh:
		return
	var material: StandardMaterial3D = _box_mesh.material_override as StandardMaterial3D
	if material:
		material.albedo_color = box_color

func _update_grid_material() -> void:
	if not Engine.is_editor_hint(): return
	if not _grid_lines:
		return
	var material: StandardMaterial3D = _grid_lines.material_override as StandardMaterial3D
	if material:
		material.albedo_color = grid_line_color
