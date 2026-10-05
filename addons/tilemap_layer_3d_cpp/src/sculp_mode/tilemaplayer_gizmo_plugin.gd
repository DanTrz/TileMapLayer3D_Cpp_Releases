class_name TML3D_TileMapLayerGizmoPlugin
extends EditorNode3DGizmoPlugin

const SCATTER_BRUSH_SHADER: Shader = preload("res://addons/tilemap_layer_3d_cpp/src/sculp_mode/scatter_brush_preview.gdshader")

## Sculpt/SmartFill/VertexEdit gizmo plugin (C++ build). The managers are the state hubs;
## the gizmo reads from them via bound get_*() accessors. Set by the plugin after construction.

var sculpt_manager: TML3D_SculptManager = null
var smart_fill_manager: TML3D_SmartFillManager = null
var vertex_edit_manager: TML3D_VertexEditManager = null

var scatter_preview_valid: bool = false
var scatter_preview_rejected: bool = false
var scatter_preview_local_position: Vector3 = Vector3.ZERO
var scatter_preview_local_normal: Vector3 = Vector3.UP
var scatter_preview_radius: float = 2.0
var scatter_preview_tool: int = 0
var scatter_preview_mesh: SphereMesh = null
var scatter_paint_material: ShaderMaterial = null
var scatter_scale_material: ShaderMaterial = null
var scatter_rejected_material: ShaderMaterial = null

var active_tile_map_layer3d: TileMapLayer3d_Cpp = null

## EditorUndoRedoManager (from EditorPlugin.get_undo_redo()) for vertex handle commits.
var _undo_redo: EditorUndoRedoManager = null

## The active gizmo instance, stored so the plugin can call update_gizmos().
var current_gizmo: TML3D_TileMapLayerGizmo = null


func _init() -> void:
	create_material("brush_cell", Color(0.2, 0.8, 1.0, 0.4), false, true)
	create_material("brush_pattern", Color(0.1, 0.5, 0.8, 0.3), false, true)
	create_material("brush_pattern_ready", Color(0.9, 0.8, 0.1, 0.4), false, true)
	create_material("brush_raise", Color(1.0, 0.9, 0.0, 0.5), false, true)
	create_material("brush_lower", Color(1.0, 0.2, 0.2, 0.5), false, true)
	create_material("smart_fill_start", TML3D_EditorConst.SMART_FILL_START_MARKER_COLOR, false, true)
	create_material("smart_fill_preview", TML3D_EditorConst.SMART_FILL_PREVIEW_COLOR, false, true)
	create_handle_material("vertex_handle", false, null)
	create_material("vertex_wireframe", TML3D_EditorConst.VERTEX_WIREFRAME_COLOR, false, true)
	scatter_paint_material = _create_scatter_brush_material(Color(1.0, 0.7, 0.05, 0.95))
	scatter_scale_material = _create_scatter_brush_material(Color(0.2, 0.75, 1.0, 0.95))
	scatter_rejected_material = _create_scatter_brush_material(Color(1.0, 0.22, 0.08, 0.95))

	scatter_preview_mesh = SphereMesh.new()
	scatter_preview_mesh.radius = 1.0
	scatter_preview_mesh.height = 2.0
	scatter_preview_mesh.radial_segments = 32
	scatter_preview_mesh.rings = 16


func _create_scatter_brush_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SCATTER_BRUSH_SHADER
	material.set_shader_parameter("brush_color", color)
	return material


func set_active_node(tile_map_node: TileMapLayer3d_Cpp, smart_fill_node: TML3D_SmartFillManager, sculpt_node: TML3D_SculptManager) -> void:
	var previous_node: TileMapLayer3d_Cpp = active_tile_map_layer3d
	active_tile_map_layer3d = tile_map_node
	smart_fill_manager = smart_fill_node
	sculpt_manager = sculpt_node
	# Each TileMap node owns a gizmo instance. Redraw the old instance after changing
	# the active node so its cached preview geometry is cleared immediately.
	if is_instance_valid(previous_node) and previous_node != active_tile_map_layer3d:
		previous_node.update_gizmos()
	if is_instance_valid(active_tile_map_layer3d):
		active_tile_map_layer3d.update_gizmos()


func _has_gizmo(node: Node3D) -> bool:
	return node is TileMapLayer3d_Cpp


func _create_gizmo(node: Node3D) -> EditorNode3DGizmo:
	current_gizmo = TML3D_TileMapLayerGizmo.new()
	return current_gizmo


func _get_gizmo_name() -> String:
	return "TileMapLayer Brush"


# --- Vertex Edit Handle Methods ---

func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
	var names: Array[String] = ["BL", "BR", "TR", "TL"]
	if handle_id >= 0 and handle_id < 4:
		return names[handle_id]
	return "Unknown"


func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
	if not vertex_edit_manager or vertex_edit_manager.get_selected_tile_key() == -1:
		return Vector3.ZERO
	var corners: PackedVector3Array = vertex_edit_manager.get_handle_positions(vertex_edit_manager.get_selected_tile_key())
	if handle_id >= 0 and handle_id < corners.size():
		return corners[handle_id]
	return Vector3.ZERO


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_point: Vector2) -> void:
	if not vertex_edit_manager or vertex_edit_manager.get_selected_tile_key() == -1:
		return
	if handle_id < 0 or handle_id > 3:
		return

	var tile_key: int = vertex_edit_manager.get_selected_tile_key()
	var corners: PackedVector3Array = vertex_edit_manager.get_handle_positions(tile_key)
	if corners.size() != 4:
		return

	var gs: float = 1.0
	if active_tile_map_layer3d and active_tile_map_layer3d.settings:
		gs = active_tile_map_layer3d.settings.grid_size
	var result: Variant = vertex_edit_manager.project_to_snapped_position(camera, screen_point, corners[handle_id], gs)
	if result == null:
		return

	vertex_edit_manager.update_corner(tile_key, handle_id, result as Vector3)
	gizmo.get_node_3d().update_gizmos()


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	if not vertex_edit_manager or vertex_edit_manager.get_selected_tile_key() == -1:
		return
	if handle_id < 0 or handle_id > 3:
		return

	var tile_key: int = vertex_edit_manager.get_selected_tile_key()
	var node: Node3D = gizmo.get_node_3d()

	# Handle values (`restore`, get_handle_positions) are WORLD space; corners are STORED node-local,
	# so these writes must go through update_corner_world, not update_corner.
	if cancel:
		vertex_edit_manager.update_corner_world(tile_key, handle_id, restore as Vector3)
		node.update_gizmos()
		return

	if _undo_redo and node:
		var new_pos: Vector3 = vertex_edit_manager.get_handle_positions(tile_key)[handle_id]
		_undo_redo.create_action("Move Vertex Corner", 0, node)
		_undo_redo.add_do_method(vertex_edit_manager, "update_corner_world", tile_key, handle_id, new_pos)
		_undo_redo.add_undo_method(vertex_edit_manager, "update_corner_world", tile_key, handle_id, restore)
		_undo_redo.add_do_method(node, "update_gizmos")
		_undo_redo.add_undo_method(node, "update_gizmos")
		_undo_redo.commit_action(false)
