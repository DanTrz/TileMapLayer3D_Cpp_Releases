@tool
class_name TML3D_TileCursor3D
extends Node3D

## 3D grid cursor for grid alignment and plane placement modes.
## Shows where the next tile will be placed with a visual crosshair.

@export var grid_size: float = TML3D_GlobalConstants.get_DEFAULT_GRID_SIZE():
	set(value):
		if not Engine.is_editor_hint(): return
		if value > 0.0:
			grid_size = value
			position = grid_position * grid_size
			_update_cursor_visual()
			_update_plane_visualizer_position()
			if _plane_visualizer:
				_plane_visualizer.grid_size = value

@export var cursor_color: Color = Color.WHITE:
	set(value):
		if not Engine.is_editor_hint(): return
		cursor_color = value
		_update_cursor_visual()

@export var crosshair_length: float = TML3D_GlobalConstants.get_DEFAULT_CROSSHAIR_LENGTH():
	set(value):
		if not Engine.is_editor_hint(): return
		crosshair_length = value
		_update_cursor_visual()

@export var show_plane_grids: bool = true:
	set(value):
		if not Engine.is_editor_hint(): return
		show_plane_grids = value
		if _plane_visualizer:
			_plane_visualizer.visible_planes = value

## Keyboard movement increment in grid units.
@export var cursor_step_size: float = TML3D_GlobalConstants.get_DEFAULT_CURSOR_STEP_SIZE():
	set(value):
		if not Engine.is_editor_hint(): return
		if value > 0.0:
			cursor_step_size = value

@export var cursor_start_position: Vector3 = TML3D_EditorConst.DEFAULT_CURSOR_START_POSITION

## Cursor position in local-space grid units, including fractional coordinates.
var grid_position: Vector3 = Vector3.ZERO:
	set(value):
		if not Engine.is_editor_hint(): return
		grid_position = value
		position = grid_position * grid_size
		_update_cursor_visual()
		_update_plane_visualizer_position()

# Visual components
var _mesh_instance: MeshInstance3D = null
var _x_axis_line: MeshInstance3D = null
var _y_axis_line: MeshInstance3D = null
var _z_axis_line: MeshInstance3D = null
var _plane_visualizer: TML3D_CursorPlaneVisualizer = null

# Active plane tracking (for ray-plane intersection in area selection)
var _active_plane_normal: Vector3 = Vector3.UP  # Default to floor (XZ plane)

func _ready() -> void:
	if not Engine.is_editor_hint(): return
	_create_cursor_visual()
	_create_plane_visualizer()
	_update_cursor_visual()

func _create_cursor_visual() -> void:
	_mesh_instance = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = TML3D_EditorConst.CURSOR_CENTER_CUBE_SIZE
	_mesh_instance.mesh = box_mesh
	_mesh_instance.position = cursor_start_position

	_mesh_instance.material_override = TML3D_GlobalUtil.create_unshaded_material(TML3D_EditorConst.CURSOR_CENTER_COLOR)

	add_child(_mesh_instance)
	# DO NOT set owner - cursor is runtime-only and not saved to scene.

	_x_axis_line = _create_axis_line(Vector3.RIGHT, TML3D_EditorConst.CURSOR_X_AXIS_COLOR)
	_x_axis_line.position = cursor_start_position
	_y_axis_line = _create_axis_line(Vector3.UP, TML3D_EditorConst.CURSOR_Y_AXIS_COLOR)
	_y_axis_line.position = cursor_start_position
	_z_axis_line = _create_axis_line(Vector3.FORWARD, TML3D_EditorConst.CURSOR_Z_AXIS_COLOR)
	_z_axis_line.position = cursor_start_position

func _create_axis_line(direction: Vector3, line_color: Color) -> MeshInstance3D:
	var line_mesh: MeshInstance3D = MeshInstance3D.new()

	var box: BoxMesh = BoxMesh.new()
	var thickness: float = TML3D_GlobalConstants.get_CURSOR_AXIS_LINE_THICKNESS()
	if direction == Vector3.RIGHT:
		box.size = Vector3(crosshair_length * 2, thickness, thickness)
	elif direction == Vector3.UP:
		box.size = Vector3(thickness, crosshair_length * 2, thickness)
	else: # FORWARD
		box.size = Vector3(thickness, thickness, crosshair_length * 2)

	line_mesh.mesh = box
	line_mesh.material_override = TML3D_GlobalUtil.create_unshaded_material(line_color)

	add_child(line_mesh)
	# DO NOT set owner - cursor is runtime-only and not saved to scene.

	return line_mesh

func _create_plane_visualizer() -> void:
	_plane_visualizer = TML3D_CursorPlaneVisualizer.new()
	_plane_visualizer.grid_size = grid_size
	_plane_visualizer.grid_extent = TML3D_GlobalConstants.DEFAULT_GRID_EXTENT
	_plane_visualizer.line_color = TML3D_EditorConst.DEFAULT_GRID_LINE_COLOR
	_plane_visualizer.visible_planes = false
	_plane_visualizer.name = "PlaneVisualizer"
	_update_plane_visualizer_position()
	add_child(_plane_visualizer)
	_plane_visualizer.visible = false
	# DO NOT set owner - visualizer is runtime-only.

func _update_plane_visualizer_position() -> void:
	if _plane_visualizer:
		# Keep the lattice along the plane, but follow fractional plane heights/depths.
		var grid_origin: Vector3 = grid_position.floor()
		var normal_axis: int = _active_plane_normal.abs().max_axis_index()
		grid_origin[normal_axis] = grid_position[normal_axis]
		var offset: Vector3 = (grid_origin - grid_position) * grid_size
		_plane_visualizer.position = offset

func _update_cursor_visual() -> void:
	if not is_inside_tree():
		return

	# Scale all visuals with grid_size so they stay proportional.
	var scale_factor: float = grid_size / TML3D_GlobalConstants.get_DEFAULT_GRID_SIZE()

	if _mesh_instance and _mesh_instance.mesh:
		(_mesh_instance.mesh as BoxMesh).size = TML3D_EditorConst.CURSOR_CENTER_CUBE_SIZE * scale_factor

	var thickness: float = TML3D_GlobalConstants.get_CURSOR_AXIS_LINE_THICKNESS() * scale_factor
	if _x_axis_line and _x_axis_line.mesh:
		(_x_axis_line.mesh as BoxMesh).size = Vector3(crosshair_length * 2, thickness, thickness)
	if _y_axis_line and _y_axis_line.mesh:
		(_y_axis_line.mesh as BoxMesh).size = Vector3(thickness, crosshair_length * 2, thickness)
	if _z_axis_line and _z_axis_line.mesh:
		(_z_axis_line.mesh as BoxMesh).size = Vector3(thickness, thickness, crosshair_length * 2)

## Moves cursor by grid offset (respects cursor_step_size).
func move_by(offset: Vector3i) -> void:
	grid_position += Vector3(offset) * cursor_step_size

## Moves cursor to a specific grid position.
func move_to(pos: Vector3) -> void:
	grid_position = pos

## Returns current world position (where tiles are placed), incl. parent transform.
func get_world_position() -> Vector3:
	return global_position

## Highlights the active plane based on camera angle.
func set_active_plane(active_plane_normal: Vector3) -> void:
	_active_plane_normal = active_plane_normal
	_update_plane_visualizer_position()

	if _plane_visualizer:
		_plane_visualizer.visible = show_plane_grids
		_plane_visualizer.visible_planes = true
		_plane_visualizer._update_visibility()
		_plane_visualizer.set_active_plane(active_plane_normal)

func get_plane_normal() -> Vector3:
	return _active_plane_normal
