class_name TML3D_TileMapLayerGizmo
extends EditorNode3DGizmo

## Sculpt brush / Smart Fill / Vertex Edit preview gizmo (C++ build). Reads all state from
## the managers via bound get_*() accessors (GDExtension getters are not dot-accessible).

func _redraw() -> void:
	clear()

	var gizmo_plugin: TML3D_TileMapLayerGizmoPlugin = get_plugin() as TML3D_TileMapLayerGizmoPlugin
	if not gizmo_plugin:
		return

	var active_node: TileMapLayer3d_Cpp = gizmo_plugin.active_tile_map_layer3d
	if not active_node or get_node_3d() != active_node:
		return

	match active_node.settings.main_app_mode:
		TML3D_GlobalConstants.APP_SMART_OPERATIONS:
			_draw_smart_fill_preview(gizmo_plugin)
		TML3D_GlobalConstants.APP_SCULPT:
			_draw_sculpt_preview(gizmo_plugin)
		TML3D_GlobalConstants.APP_VERTEX_EDIT:
			_draw_vertex_edit_handles(gizmo_plugin)
		TML3D_GlobalConstants.APP_SCATTER:
			_draw_scatter_preview(gizmo_plugin)


func _draw_scatter_preview(gizmo_plugin: TML3D_TileMapLayerGizmoPlugin) -> void:
	if not gizmo_plugin.scatter_preview_valid or not gizmo_plugin.scatter_preview_mesh:
		return

	var center: Vector3 = gizmo_plugin.scatter_preview_local_position
	var normal: Vector3 = gizmo_plugin.scatter_preview_local_normal.normalized()
	if normal.length_squared() < 0.001:
		normal = Vector3.UP

	var reference_axis: Vector3 = Vector3.RIGHT if absf(normal.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var tangent: Vector3 = reference_axis.cross(normal).normalized()
	var bitangent: Vector3 = tangent.cross(normal).normalized()
	var orientation := Basis(tangent, normal, bitangent)

	var radius: float = maxf(0.1, gizmo_plugin.scatter_preview_radius)
	var material: Material = gizmo_plugin.scatter_paint_material
	if gizmo_plugin.scatter_preview_rejected:
		material = gizmo_plugin.scatter_rejected_material
	elif gizmo_plugin.scatter_preview_tool == 1:
		material = gizmo_plugin.scatter_scale_material

	var brush_basis: Basis = orientation.scaled(Vector3.ONE * radius)
	var brush_transform := Transform3D(brush_basis, center + normal * 0.01)
	add_mesh(gizmo_plugin.scatter_preview_mesh, material, brush_transform)


func _draw_vertex_edit_handles(gizmo_plugin: TML3D_TileMapLayerGizmoPlugin) -> void:
	var vem: TML3D_VertexEditManager = gizmo_plugin.vertex_edit_manager
	if not vem or vem.get_selected_tile_key() == -1:
		return

	var corners: PackedVector3Array = vem.get_handle_positions(vem.get_selected_tile_key())
	if corners.size() != 4:
		return

	var node: Node3D = get_node_3d()
	var node_inv: Transform3D = node.global_transform.affine_inverse() if node else Transform3D()

	var local_corners: PackedVector3Array = PackedVector3Array()
	for corner: Vector3 in corners:
		local_corners.append(node_inv * corner)

	var wireframe_mat: Material = get_plugin().get_material("vertex_wireframe", self)

	var lines: PackedVector3Array = PackedVector3Array()
	lines.append(local_corners[0]); lines.append(local_corners[1])
	lines.append(local_corners[1]); lines.append(local_corners[2])
	lines.append(local_corners[2]); lines.append(local_corners[3])
	lines.append(local_corners[3]); lines.append(local_corners[0])
	lines.append(local_corners[0]); lines.append(local_corners[2])
	lines.append(local_corners[1]); lines.append(local_corners[3])
	add_lines(lines, wireframe_mat, false)

	var handle_mat: Material = get_plugin().get_material("vertex_handle", self)
	add_handles(local_corners, handle_mat, PackedInt32Array([0, 1, 2, 3]))


func _draw_sculpt_preview(gizmo_plugin: TML3D_TileMapLayerGizmoPlugin) -> void:
	var sculpt_manager: TML3D_SculptManager = gizmo_plugin.sculpt_manager
	if not sculpt_manager or not sculpt_manager.get_is_active():
		return

	var cell_mat: Material = get_plugin().get_material("brush_cell", self)
	var pattern_mat: Material = get_plugin().get_material("brush_pattern", self)
	var pattern_ready_mat: Material = get_plugin().get_material("brush_pattern_ready", self)
	var raise_mat: Material = get_plugin().get_material("brush_raise", self)
	var lower_mat: Material = get_plugin().get_material("brush_lower", self)

	var center: Vector3 = sculpt_manager.get_brush_grid_pos()
	var gs: float = sculpt_manager.get_grid_size()
	var radius: int = sculpt_manager.get_brush_type()
	var raise_amount: float = sculpt_manager.get_raise_amount()
	var sm_state: int = sculpt_manager.get_state()
	var align_offset: Vector3 = TML3D_GlobalConstants.get_GRID_ALIGNMENT_OFFSET()
	var floor_off: float = TML3D_GlobalConstants.get_SCULPT_GIZMO_FLOOR_OFFSET()

	# Working plane: columns are (u, n, v). Cell meshes are authored in local XZ, so using this
	# as the mesh basis orients squares, triangles and arch caps onto the plane for free.
	var plane: Basis = sculpt_manager.get_plane_basis()
	var p_u: Vector3 = plane.x
	var p_n: Vector3 = plane.y
	var p_v: Vector3 = plane.z

	# Base offset along the plane normal, nudged off the surface so the gizmo does not z-fight.
	var base_grid_pos: Vector3 = sculpt_manager.get_drag_anchor_grid_pos() if sm_state == TML3D_SculptManager.SETTING_HEIGHT else center
	var base_h: float = (p_n.dot(base_grid_pos) + p_n.dot(align_offset)) * gs + floor_off

	# In-plane cell position -> world, mirroring grid_to_world's half-cell alignment.
	var cell_to_world: Callable = func(cu: float, cv: float, ch: float) -> Vector3:
		var in_plane: Vector3 = p_u * (cu + p_u.dot(align_offset)) + p_v * (cv + p_v.dot(align_offset))
		return in_plane * gs + p_n * ch

	var gap_factor: float = TML3D_GlobalConstants.get_SCULPT_CELL_GAP_FACTOR()
	var cell_mesh: PlaneMesh = PlaneMesh.new()
	cell_mesh.size = Vector2(gs * gap_factor, gs * gap_factor)

	var h: float = gs * 0.5 * gap_factor
	var gap_size: float = gs * gap_factor
	var tri_meshes: Array[ArrayMesh] = [
		null,
		_make_triangle_mesh(h, TML3D_GlobalConstants.TRI_NE),
		_make_triangle_mesh(h, TML3D_GlobalConstants.TRI_NW),
		_make_triangle_mesh(h, TML3D_GlobalConstants.TRI_SE),
		_make_triangle_mesh(h, TML3D_GlobalConstants.TRI_SW),
		_make_arch_cap_gizmo_mesh(gap_size, 0),
		_make_arch_cap_gizmo_mesh(gap_size, 3),
		_make_arch_cap_gizmo_mesh(gap_size, 1),
		_make_arch_cap_gizmo_mesh(gap_size, 2),
	]

	var snap_u: int = roundi(p_u.dot(center))
	var snap_v: int = roundi(p_v.dot(center))

	var brush_template: Dictionary = sculpt_manager.get_brush_template()
	var drag_pattern: Dictionary = sculpt_manager.get_drag_pattern()

	var show_live_brush: bool = (sm_state == TML3D_SculptManager.IDLE or sm_state == TML3D_SculptManager.DRAWING)
	if show_live_brush:
		for offset: Vector2i in brush_template:
			var cell_type: int = brush_template[offset]
			var cell_pos: Vector3 = cell_to_world.call(float(snap_u + offset.x), float(snap_v + offset.y), base_h)
			if cell_type == TML3D_GlobalConstants.SQUARE:
				add_mesh(cell_mesh, cell_mat, Transform3D(plane, cell_pos))
			else:
				add_mesh(tri_meshes[cell_type], cell_mat, Transform3D(plane, cell_pos))

	var show_pattern: bool = not drag_pattern.is_empty() and (
		sm_state == TML3D_SculptManager.DRAWING or
		sm_state == TML3D_SculptManager.PATTERN_READY or
		sm_state == TML3D_SculptManager.SETTING_HEIGHT)
	if show_pattern:
		var use_mat: Material
		if sm_state == TML3D_SculptManager.DRAWING:
			use_mat = pattern_mat
		elif sculpt_manager.get_is_hovering_pattern():
			use_mat = raise_mat
		else:
			use_mat = pattern_ready_mat

		for cell: Vector2i in drag_pattern:
			var cell_type: int = drag_pattern[cell]
			var pattern_pos: Vector3 = cell_to_world.call(float(cell.x), float(cell.y), base_h)
			if cell_type == TML3D_GlobalConstants.SQUARE:
				add_mesh(cell_mesh, use_mat, Transform3D(plane, pattern_pos))
			else:
				add_mesh(tri_meshes[cell_type], use_mat, Transform3D(plane, pattern_pos))

	if sm_state == TML3D_SculptManager.SETTING_HEIGHT and abs(raise_amount) > 0.01:
		var preview_mat: Material = raise_mat if raise_amount > 0.0 else lower_mat
		var preview_h: float = base_h + raise_amount

		for cell: Vector2i in drag_pattern:
			var cell_type: int = drag_pattern[cell]
			var floor_pos: Vector3 = cell_to_world.call(float(cell.x), float(cell.y), base_h)
			var preview_pos: Vector3 = cell_to_world.call(float(cell.x), float(cell.y), preview_h)

			if cell_type == TML3D_GlobalConstants.SQUARE:
				add_mesh(cell_mesh, preview_mat, Transform3D(plane, preview_pos))
			else:
				add_mesh(tri_meshes[cell_type], preview_mat, Transform3D(plane, preview_pos))

			var height_line: PackedVector3Array = PackedVector3Array()
			height_line.append(floor_pos)
			height_line.append(preview_pos)
			add_lines(height_line, preview_mat, false)


func _draw_smart_fill_preview(gizmo_plugin: TML3D_TileMapLayerGizmoPlugin) -> void:
	var sfm: TML3D_SmartFillManager = gizmo_plugin.smart_fill_manager
	if not sfm or sfm.get_state() == TML3D_SmartFillManager.IDLE:
		return

	var start_mat: Material = get_plugin().get_material("smart_fill_start", self)
	var gs: float = sfm.get_grid_size()
	var floor_off: float = TML3D_GlobalConstants.get_SCULPT_GIZMO_FLOOR_OFFSET()
	var gap_factor: float = TML3D_GlobalConstants.get_SCULPT_CELL_GAP_FACTOR()

	var marker_mesh: PlaneMesh = PlaneMesh.new()
	marker_mesh.size = Vector2(gs * gap_factor, gs * gap_factor)
	var marker_pos: Vector3 = sfm.get_start_world_pos()
	var sf_node: TileMapLayer3d_Cpp = sfm.get_active_node()
	var is_stairs: bool = sf_node and sf_node.settings.smart_fill_mode == TML3D_GlobalConstants.FILL_STAIRS
	var marker_basis := Basis()
	if is_stairs:
		var normal: Vector3 = sfm.get_surface_normal_public()
		var axis: Vector3 = Vector3.RIGHT if absf(normal.x) < 0.9 else Vector3.BACK
		marker_basis = Basis(axis, normal, axis.cross(normal))
		marker_pos += normal * floor_off
	else:
		marker_pos.y += floor_off
	add_mesh(marker_mesh, start_mat, Transform3D(marker_basis, marker_pos))

	if not sfm.get_preview_active():
		return

	if is_stairs:
		var stair_mesh: ArrayMesh = sfm.get_stair_preview_mesh()
		if stair_mesh:
			var stair_mat: Material = get_plugin().get_material("smart_fill_preview", self)
			add_mesh(stair_mesh, stair_mat, Transform3D(Basis(), sfm.get_surface_normal_public() * floor_off))
		return

	var ramp_mesh: ArrayMesh = sfm.get_ramp_preview_mesh()
	if ramp_mesh:
		var preview_mat: Material = get_plugin().get_material("smart_fill_preview", self)
		add_mesh(ramp_mesh, preview_mat, Transform3D(Basis(), Vector3(0, floor_off, 0)))


func _make_triangle_mesh(h: float, cell_type: int) -> ArrayMesh:
	var a: Vector3
	var b: Vector3
	var c: Vector3
	match cell_type:
		TML3D_GlobalConstants.TRI_NE:
			a = Vector3( h, 0, -h);  b = Vector3(-h, 0, -h);  c = Vector3( h, 0,  h)
		TML3D_GlobalConstants.TRI_NW:
			a = Vector3(-h, 0, -h);  b = Vector3( h, 0, -h);  c = Vector3(-h, 0,  h)
		TML3D_GlobalConstants.TRI_SE:
			a = Vector3( h, 0,  h);  b = Vector3(-h, 0,  h);  c = Vector3( h, 0, -h)
		_: ## TRI_SW
			a = Vector3(-h, 0,  h);  b = Vector3( h, 0,  h);  c = Vector3(-h, 0, -h)

	var v: PackedVector3Array = PackedVector3Array()
	v.append(a); v.append(b); v.append(c)
	v.append(a); v.append(c); v.append(b)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_arch_cap_gizmo_mesh(cell_size: float, mesh_rotation: int) -> ArrayMesh:
	var size: Vector2 = Vector2(cell_size, cell_size)
	var cap_mesh: ArrayMesh = TML3D_TileMeshGenerator.create_arch_corner_cap_mesh(
		Rect2(0, 0, 1, 1), Vector2(1, 1), size,
		TML3D_GlobalConstants.get_ARCH_DEFAULT_RADIUS_RATIO())
	if mesh_rotation == 0:
		return cap_mesh
	var angle: float = float(mesh_rotation) * PI * 0.5
	var rot_basis: Basis = Basis(Vector3.UP, angle)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arrays: Array = cap_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in range(0, verts.size(), 3):
		var v0: Vector3 = rot_basis * verts[i]
		var v1: Vector3 = rot_basis * verts[i + 1]
		var v2: Vector3 = rot_basis * verts[i + 2]
		st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
	return st.commit()
