@tool
class_name TML3D_TilePreview3D
extends Node3D

## Visual preview/ghost of the tile that will be placed.
## Shows where the tile will appear and auto-rotates based on camera angle.

@export var grid_size: float = TML3D_GlobalConstants.get_DEFAULT_GRID_SIZE():
	set(value):
		if not Engine.is_editor_hint(): return
		if value > 0.0:
			grid_size = value
			_update_preview_mesh()

@export var preview_color: Color = TML3D_EditorConst.DEFAULT_PREVIEW_COLOR:
	set(value):
		if not Engine.is_editor_hint(): return
		preview_color = value
		_update_preview_material()

@export var tile_model: Node3D = null  # Reference to TileMapLayer3d_Cpp

# Single-tile preview components
var _preview_mesh: MeshInstance3D = null
var _preview_material: ShaderMaterial = null
var _grid_indicator: MeshInstance3D = null

# Multi-tile preview pool
var _preview_instances: Array[MeshInstance3D] = []
var _preview_indicators: Array[MeshInstance3D] = []
var _is_multi_preview_active: bool = false

# Single baked-mesh preview for very large patterns (above the pooled limit)
var _pattern_mesh_instance: MeshInstance3D = null
var _pattern_mesh_cached: Mesh = null  # tracks which mesh the ghost material was built for

# Current preview state
var preview_visible: bool = false
var preview_grid_position: Vector3 = Vector3.ZERO
var preview_orientation: int = 0
var preview_uv_rect: Rect2 = Rect2()
var preview_mesh_rotation: int = 0
var preview_is_mirrored: bool = false
var preview_uv_rotation: int = 0
var preview_texture: Texture2D = null
var texture_filter_mode: int = TML3D_GlobalConstants.DEFAULT_TEXTURE_FILTER
var current_mesh_mode: int = TML3D_GlobalConstants.FLAT_SQUARE
var current_depth_scale: float = 0.1
var current_depth_growth_mode: int = TML3D_GlobalConstants.OUTWARD
var current_arch_radius_ratio: float = TML3D_GlobalConstants.get_ARCH_DEFAULT_RADIUS_RATIO()

# Cache last preview state to avoid unnecessary mesh rebuilds
var _cached_uv_rect: Rect2 = Rect2()
var _cached_orientation: int = -1
var _cached_rotation: int = -1
var _cached_texture: Texture2D = null
var _cached_mesh_mode: int = -1
var _cached_flip: bool = false
var _cached_uv_rotation: int = -1

func sync_from_settings(settings: TML3D_TileMapLayerSettings, mesh_mode_override: int = -1) -> void:
	if not settings:
		return
	grid_size = settings.grid_size
	texture_filter_mode = settings.texture_filter_mode
	current_mesh_mode = mesh_mode_override if mesh_mode_override >= 0 else settings.mesh_mode
	current_depth_scale = settings.current_depth_scale
	current_depth_growth_mode = settings.depth_growth_mode
	current_arch_radius_ratio = settings.arch_radius_ratio
	_update_preview_mesh()
	_update_preview_material()

func _ready() -> void:
	if not Engine.is_editor_hint(): return
	_create_preview_mesh()
	_create_grid_indicator()
	_create_preview_pool()

func _create_preview_mesh() -> void:
	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.name = "PreviewMesh"
	_preview_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview_mesh)

func _create_grid_indicator() -> void:
	_grid_indicator = MeshInstance3D.new()
	_grid_indicator.name = "GridIndicator"
	_grid_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = TML3D_EditorConst.PREVIEW_GRID_INDICATOR_SIZE
	_grid_indicator.mesh = box_mesh

	_grid_indicator.material_override = TML3D_GlobalUtil.create_unshaded_material(TML3D_EditorConst.PREVIEW_GRID_INDICATOR_COLOR)

	add_child(_grid_indicator)
	_grid_indicator.visible = false

func _build_preview_transform(grid_pos: Vector3, orientation: int, mesh_rotation: int, is_mirrored: bool, is_face_flipped: bool = false) -> Transform3D:
	# is_mirrored only affects the material's sampled U; the geometry flip is a separate field.
	return TML3D_GlobalUtil.build_tile_transform(
		grid_pos, orientation, mesh_rotation, grid_size, is_face_flipped,
		0.0, 0.0, 0.0, 0.0,
		current_mesh_mode, current_depth_scale,
		current_depth_growth_mode == TML3D_GlobalConstants.INWARD
	)

## Builds a normalized-UV ArrayMesh for the given mesh mode (shared by all preview paths).
func _build_preview_array_mesh(uv: Rect2, atlas_size: Vector2, texture: Texture2D = null, source_uv_rect: Rect2 = Rect2()) -> ArrayMesh:
	var gs := Vector2(grid_size, grid_size)
	match current_mesh_mode:
		TML3D_GlobalConstants.FLAT_STAIRS, TML3D_GlobalConstants.FLAT_STAIRS_I, TML3D_GlobalConstants.FLAT_STAIRS_SIDE:
			return TML3D_TileMeshFactory.get_mesh(current_mesh_mode, grid_size)
		TML3D_GlobalConstants.FLAT_SQUARE:
			return TML3D_TileMeshGenerator.create_tile_quad(uv, atlas_size, gs)
		TML3D_GlobalConstants.FLAT_TRIANGULE:
			return TML3D_TileMeshGenerator.create_tile_triangle(uv, atlas_size, gs)
		TML3D_GlobalConstants.BOX_MESH:
			return TML3D_TileMeshGenerator.create_box_mesh(grid_size, 1.0)
		TML3D_GlobalConstants.PRISM_MESH:
			return TML3D_TileMeshGenerator.create_prism_mesh(grid_size, 1.0)
		TML3D_GlobalConstants.AUTOSHAPE_MESH:
			var active_texture: Texture2D = texture if texture else preview_texture
			var shape_uv: Rect2 = source_uv_rect if source_uv_rect.has_area() else preview_uv_rect
			if active_texture and shape_uv.has_area():
				if TML3D_AutoshapeMeshBuilder.is_solid_opaque_tile(active_texture, shape_uv):
					return TML3D_TileMeshGenerator.create_box_mesh(grid_size, 1.0)
				var mesh: ArrayMesh = TML3D_AutoshapeMeshBuilder.build_mesh(active_texture, shape_uv, grid_size)
				if mesh:
					return mesh
			return TML3D_TileMeshGenerator.create_box_mesh(grid_size, 1.0)
		TML3D_GlobalConstants.FLAT_ARCH_CORNER:
			return TML3D_TileMeshGenerator.create_arch_corner_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
		TML3D_GlobalConstants.FLAT_ARCH:
			return TML3D_TileMeshGenerator.create_arch_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
		TML3D_GlobalConstants.FLAT_ARCH_I:
			return TML3D_TileMeshGenerator.create_arch_i_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
		TML3D_GlobalConstants.FLAT_ARCH_CORNER_I:
			return TML3D_TileMeshGenerator.create_arch_corner_i_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
		TML3D_GlobalConstants.FLAT_ARCH_CORNER_CAP:
			return TML3D_TileMeshGenerator.create_arch_corner_cap_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
		TML3D_GlobalConstants.FLAT_ARCH_CORNER_CAP_I:
			return TML3D_TileMeshGenerator.create_arch_corner_cap_i_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
		TML3D_GlobalConstants.FLAT_ARCH_CORNER_CAP_DUO:
			return TML3D_TileMeshGenerator.create_arch_corner_cap_duo_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
		TML3D_GlobalConstants.FLAT_ARCH_CORNER_CAP_I_DUO:
			return TML3D_TileMeshGenerator.create_arch_corner_cap_i_duo_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
		TML3D_GlobalConstants.FLAT_ARCH_CORNER_C:
			return TML3D_TileMeshGenerator.create_arch_corner_c_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
		TML3D_GlobalConstants.FLAT_ARCH_CORNER_C_I:
			return TML3D_TileMeshGenerator.create_arch_corner_c_i_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
		TML3D_GlobalConstants.FLAT_ARCH_CORNER_S:
			return TML3D_TileMeshGenerator.create_arch_corner_s_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
		TML3D_GlobalConstants.FLAT_ARCH_CORNER_S_I:
			return TML3D_TileMeshGenerator.create_arch_corner_s_i_mesh(uv, atlas_size, gs, current_arch_radius_ratio)
	return null

## Updates the preview to show a tile at a position with orientation.
func update_preview(
	grid_pos: Vector3,
	orientation: int,
	uv_rect: Rect2,
	texture: Texture2D,
	mesh_rotation: int = 0,
	is_mirrored: bool = false,
	show: bool = true,
	is_decal = false,
	uv_rotation: int = 0
) -> void:
	preview_grid_position = grid_pos
	preview_orientation = orientation
	preview_uv_rect = uv_rect
	preview_mesh_rotation = mesh_rotation
	preview_is_mirrored = is_mirrored
	preview_uv_rotation = uv_rotation
	preview_texture = texture
	preview_visible = show

	if not show:
		hide_preview()
		return

	var transform: Transform3D = _build_preview_transform(grid_pos, orientation, mesh_rotation, is_mirrored)

	position = transform.origin
	basis = Basis.IDENTITY
	if _preview_mesh:
		_preview_mesh.basis = transform.basis

	if is_decal:
		position += TML3D_GlobalUtil.get_rotation_axis_for_orientation(preview_orientation) * TML3D_GlobalConstants.get_DECAL_NODE_OFFSET()

	var needs_mesh_rebuild: bool = (
		_cached_uv_rect != uv_rect or
		_cached_orientation != orientation or
		_cached_rotation != mesh_rotation or
		_cached_texture != texture or
		_cached_mesh_mode != current_mesh_mode or
		_cached_flip != is_mirrored or
		_cached_uv_rotation != uv_rotation
	)

	if needs_mesh_rebuild:
		_update_preview_mesh()
		_update_preview_material()

		_cached_uv_rect = uv_rect
		_cached_orientation = orientation
		_cached_rotation = mesh_rotation
		_cached_texture = texture
		_cached_mesh_mode = current_mesh_mode
		_cached_flip = is_mirrored
		_cached_uv_rotation = uv_rotation

	_preview_mesh.visible = true
	if _grid_indicator:
		_grid_indicator.visible = true

func hide_preview() -> void:
	preview_visible = false
	if _preview_mesh:
		_preview_mesh.visible = false
	if _grid_indicator:
		_grid_indicator.visible = false
	_hide_all_preview_instances()
	_hide_pattern_mesh_preview()

func _create_preview_pool() -> void:
	_ensure_preview_pool(TML3D_GlobalConstants.PREVIEW_POOL_SIZE)

## Appends mesh/indicator slot pairs until the pool holds at least `count`. The pool starts at
## PREVIEW_POOL_SIZE and only grows when a large pattern needs more (capped by the caller).
func _ensure_preview_pool(count: int) -> void:
	while _preview_instances.size() < count:
		_add_preview_pool_slot(_preview_instances.size())

func _add_preview_pool_slot(i: int) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "MultiPreviewMesh_%d" % i
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visible = false
	add_child(mesh_instance)
	_preview_instances.append(mesh_instance)

	var indicator: MeshInstance3D = MeshInstance3D.new()
	indicator.name = "MultiPreviewIndicator_%d" % i
	indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = TML3D_EditorConst.PREVIEW_GRID_INDICATOR_SIZE
	indicator.mesh = box_mesh

	indicator.material_override = TML3D_GlobalUtil.create_unshaded_material(TML3D_EditorConst.PREVIEW_GRID_INDICATOR_COLOR)

	indicator.visible = false
	add_child(indicator)
	_preview_indicators.append(indicator)

func _hide_all_preview_instances() -> void:
	for instance: MeshInstance3D in _preview_instances:
		instance.visible = false
	for indicator: MeshInstance3D in _preview_indicators:
		indicator.visible = false
	_is_multi_preview_active = false

func update_multi_preview(
	anchor_grid_pos: Vector3,
	selected_tiles: Array[Rect2],
	orientation: int,
	mesh_rotation: int = 0,
	texture: Texture2D = null,
	is_mirrored: bool = false,
	show: bool = true,
	uv_rotation: int = 0,
	layout_rotation: int = -1
) -> void:
	if _preview_mesh:
		_preview_mesh.visible = false
	if _grid_indicator:
		_grid_indicator.visible = false

	if not show or selected_tiles.is_empty():
		_hide_all_preview_instances()
		return

	_is_multi_preview_active = true

	var transform: Transform3D = _build_preview_transform(anchor_grid_pos, orientation, mesh_rotation, is_mirrored)

	position = transform.origin
	basis = transform.basis

	var first_tile_rect: Rect2 = selected_tiles[0]
	var first_tile_pixel_pos: Vector2 = first_tile_rect.position
	var selection_min_x: float = first_tile_pixel_pos.x
	var selection_max_x: float = first_tile_pixel_pos.x
	if is_mirrored:
		for selected_uv: Rect2 in selected_tiles:
			selection_min_x = minf(selection_min_x, selected_uv.position.x)
			selection_max_x = maxf(selection_max_x, selected_uv.position.x)

	var active_texture: Texture2D = texture if texture else preview_texture
	if not active_texture:
		_hide_all_preview_instances()
		return

	# Cells are placed where placement puts them, converted into this node's (scaled, rotated) frame.
	var cell_rotation: int = layout_rotation if layout_rotation >= 0 else mesh_rotation
	var to_local: Basis = basis.inverse()
	var tile_count: int = min(selected_tiles.size(), TML3D_GlobalConstants.PREVIEW_POOL_SIZE)
	for i: int in range(tile_count):
		var tile_uv_rect: Rect2 = selected_tiles[i]
		var tile_pixel_pos: Vector2 = tile_uv_rect.position
		var pixel_offset: Vector2 = tile_pixel_pos - first_tile_pixel_pos
		# Mirror the complete selected image, not just each tile in isolation. The preview
		# keeps the same footprint and reverses the texture-column assignment within it.
		if is_mirrored:
			var mirrored_pixel_x: float = selection_min_x + selection_max_x - tile_pixel_pos.x
			pixel_offset.x = mirrored_pixel_x - first_tile_pixel_pos.x
		var tile_pixel_size: Vector2 = first_tile_rect.size
		var grid_offset: Vector2 = pixel_offset / tile_pixel_size
		var offset_3d: Vector3 = to_local * TML3D_GlobalUtil.multi_tile_cell_offset(grid_offset, orientation, cell_rotation)
		_update_single_preview_instance(i, offset_3d, orientation, tile_uv_rect, active_texture, mesh_rotation, is_mirrored, uv_rotation)

	for i: int in range(tile_count, TML3D_GlobalConstants.PREVIEW_POOL_SIZE):
		_preview_instances[i].visible = false
		_preview_indicators[i].visible = false

func update_pattern_preview(
	pattern_tiles: Array[TML3D_PlacedTileInfo],
	texture: Texture2D = null,
	show: bool = true,
	pool_limit: int = 0
) -> void:
	_hide_pattern_mesh_preview()
	if _preview_mesh:
		_preview_mesh.visible = false
	if _grid_indicator:
		_grid_indicator.visible = false

	if not show or pattern_tiles.is_empty():
		_hide_all_preview_instances()
		return

	var active_texture: Texture2D = texture if texture else preview_texture
	if not active_texture:
		_hide_all_preview_instances()
		return

	_is_multi_preview_active = true
	position = Vector3.ZERO
	basis = Basis.IDENTITY

	var cap: int = pattern_tiles.size()
	if pool_limit > 0:
		cap = min(cap, pool_limit)
	_ensure_preview_pool(cap)

	for i: int in range(cap):
		var tile_info: TML3D_PlacedTileInfo = pattern_tiles[i]
		if tile_info == null:
			_preview_instances[i].visible = false
			_preview_indicators[i].visible = false
			continue
		_update_pattern_preview_instance(i, tile_info.grid_position, tile_info, active_texture)

	for i: int in range(cap, _preview_instances.size()):
		_preview_instances[i].visible = false
		_preview_indicators[i].visible = false

## Large-pattern fallback: shows the whole pattern as ONE pre-baked translucent mesh that follows the
## cursor (O(1) per move). The manager supplies the node-local transform (pattern turn + stamp offset).
func update_pattern_mesh_preview(mesh: Mesh, material: Material, local_transform: Transform3D, show: bool = true) -> void:
	_hide_all_preview_instances()
	if _preview_mesh:
		_preview_mesh.visible = false
	if _grid_indicator:
		_grid_indicator.visible = false

	if not show or mesh == null:
		_hide_pattern_mesh_preview()
		return

	if _pattern_mesh_instance == null:
		_pattern_mesh_instance = MeshInstance3D.new()
		_pattern_mesh_instance.name = "PatternMeshPreview"
		_pattern_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_pattern_mesh_instance)

	position = Vector3.ZERO
	basis = Basis.IDENTITY
	# Only rebuild mesh + ghost material when the pattern (mesh) actually changes; per cursor
	# move we just update position, keeping this O(1).
	if mesh != _pattern_mesh_cached:
		_pattern_mesh_cached = mesh
		_pattern_mesh_instance.mesh = mesh
		_pattern_mesh_instance.material_override = _make_ghost_material(material)
	_pattern_mesh_instance.transform = local_transform
	_pattern_mesh_instance.visible = true
	_is_multi_preview_active = true

func _hide_pattern_mesh_preview() -> void:
	if _pattern_mesh_instance:
		_pattern_mesh_instance.visible = false

## Duplicates the baked material and makes it translucent so the fallback reads as a ghost,
## matching the pooled preview's Color(1,1,1,0.7) look.
func _make_ghost_material(material: Material) -> Material:
	if material == null:
		return TML3D_GlobalUtil.create_unshaded_material(TML3D_EditorConst.DEFAULT_PREVIEW_COLOR)
	var ghost: Material = material.duplicate()
	if ghost is BaseMaterial3D:
		var bm: BaseMaterial3D = ghost
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.albedo_color = Color(bm.albedo_color.r, bm.albedo_color.g, bm.albedo_color.b, TML3D_EditorConst.DEFAULT_PREVIEW_COLOR.a)
	return ghost

func _update_pattern_preview_instance(index: int, grid_pos: Vector3, tile_info: TML3D_PlacedTileInfo, texture: Texture2D) -> void:
	if index < 0 or index >= _preview_instances.size() or tile_info == null:
		return

	var mesh_instance: MeshInstance3D = _preview_instances[index]
	var indicator: MeshInstance3D = _preview_indicators[index]

	var saved_mesh_mode: int = current_mesh_mode
	var saved_depth_scale: float = current_depth_scale
	var saved_depth_growth_mode: int = current_depth_growth_mode
	current_mesh_mode = tile_info.mesh_mode
	current_depth_scale = tile_info.depth_scale
	current_depth_growth_mode = tile_info.depth_growth_mode

	var transform: Transform3D = _build_preview_transform(grid_pos, tile_info.orientation, tile_info.mesh_rotation, tile_info.is_texture_mirrored, tile_info.is_face_flipped)
	if tile_info.has_custom_transform:
		transform = tile_info.custom_transform
		transform = TML3D_GlobalUtil.apply_custom_transform_depth(transform, tile_info.mesh_mode, tile_info.depth_scale, tile_info.depth_growth_mode, grid_size)
	mesh_instance.position = transform.origin
	mesh_instance.basis = transform.basis
	indicator.position = transform.origin

	var normalized_uv := Rect2(0, 0, 1, 1)
	var normalized_size := Vector2(1, 1)
	mesh_instance.mesh = _build_preview_array_mesh(normalized_uv, normalized_size, texture, tile_info.uv_rect)

	current_mesh_mode = saved_mesh_mode
	current_depth_scale = saved_depth_scale
	current_depth_growth_mode = saved_depth_growth_mode

	var atlas_size: Vector2 = texture.get_size()
	var uv_data: Dictionary = TML3D_GlobalUtil.calculate_normalized_uv(tile_info.uv_rect, atlas_size)
	var material: ShaderMaterial = TML3D_GlobalUtil.create_preview_material(
		texture, uv_data.uv_min, uv_data.uv_max, texture_filter_mode, 99, tile_info.is_texture_mirrored
	)
	material.set_shader_parameter("uv_rotation", tile_info.get_uv_rotation())
	material.render_priority = 99
	mesh_instance.material_override = material

	var scale_factor: float = grid_size / TML3D_GlobalConstants.get_DEFAULT_GRID_SIZE()
	(indicator.mesh as BoxMesh).size = TML3D_EditorConst.PREVIEW_GRID_INDICATOR_SIZE * scale_factor

	mesh_instance.visible = true
	indicator.visible = true
func _update_single_preview_instance(
	index: int,
	local_offset: Vector3,
	orientation: int,
	uv_rect: Rect2,
	texture: Texture2D,
	mesh_rotation: int,
	mirror_texture: bool,
	uv_rotation: int = 0
) -> void:
	if index < 0 or index >= _preview_instances.size():
		return

	var mesh_instance: MeshInstance3D = _preview_instances[index]
	var indicator: MeshInstance3D = _preview_indicators[index]

	var local_world_offset: Vector3 = local_offset * grid_size
	mesh_instance.position = local_world_offset
	indicator.position = local_world_offset

	var normalized_uv := Rect2(0, 0, 1, 1)
	var normalized_size := Vector2(1, 1)
	mesh_instance.mesh = _build_preview_array_mesh(normalized_uv, normalized_size, texture, uv_rect)
	mesh_instance.basis = Basis.IDENTITY

	var atlas_size: Vector2 = texture.get_size()
	var uv_data: Dictionary = TML3D_GlobalUtil.calculate_normalized_uv(uv_rect, atlas_size)
	var material: ShaderMaterial = TML3D_GlobalUtil.create_preview_material(
		texture, uv_data.uv_min, uv_data.uv_max, texture_filter_mode, 99, mirror_texture
	)
	material.set_shader_parameter("uv_rotation", uv_rotation)
	material.render_priority = 99
	mesh_instance.material_override = material

	var scale_factor: float = grid_size / TML3D_GlobalConstants.get_DEFAULT_GRID_SIZE()
	(indicator.mesh as BoxMesh).size = TML3D_EditorConst.PREVIEW_GRID_INDICATOR_SIZE * scale_factor

	mesh_instance.visible = true
	indicator.visible = true

func _update_preview_mesh() -> void:
	if not _preview_mesh or not preview_texture:
		return

	var normalized_uv := Rect2(0, 0, 1, 1)
	var normalized_size := Vector2(1, 1)
	_preview_mesh.mesh = _build_preview_array_mesh(normalized_uv, normalized_size, preview_texture, preview_uv_rect)

	_preview_mesh.basis = _build_preview_transform(Vector3.ZERO, preview_orientation, preview_mesh_rotation, preview_is_mirrored).basis

	if _grid_indicator and _grid_indicator.mesh:
		var scale_factor: float = grid_size / TML3D_GlobalConstants.get_DEFAULT_GRID_SIZE()
		(_grid_indicator.mesh as BoxMesh).size = TML3D_EditorConst.PREVIEW_GRID_INDICATOR_SIZE * scale_factor

func _update_preview_material() -> void:
	if not _preview_mesh or not preview_texture:
		return

	var atlas_size: Vector2 = preview_texture.get_size()
	var uv_data: Dictionary = TML3D_GlobalUtil.calculate_normalized_uv(preview_uv_rect, atlas_size)

	_preview_material = TML3D_GlobalUtil.create_preview_material(
		preview_texture, uv_data.uv_min, uv_data.uv_max, texture_filter_mode, 99, preview_is_mirrored
	)
	_preview_material.set_shader_parameter("uv_rotation", preview_uv_rotation)
	_preview_material.render_priority = 99
	_preview_mesh.material_override = _preview_material

## Shows a solid color preview (no texture) for autotile mode.
func update_color_preview(
	grid_pos: Vector3,
	orientation: int,
	color: Color,
	mesh_rotation: int = 0,
	is_mirrored: bool = false,
	show: bool = true
) -> void:
	if not Engine.is_editor_hint():
		return

	preview_grid_position = grid_pos
	preview_orientation = orientation
	preview_mesh_rotation = mesh_rotation
	preview_is_mirrored = is_mirrored

	_is_multi_preview_active = false
	_hide_all_preview_instances()

	if not show:
		hide_preview()
		return

	var transform: Transform3D = _build_preview_transform(grid_pos, orientation, mesh_rotation, is_mirrored)

	position = transform.origin
	basis = Basis.IDENTITY

	_update_color_mesh()
	_update_color_material(color)

	if _preview_mesh:
		_preview_mesh.visible = true
	if _grid_indicator:
		_grid_indicator.visible = true
	preview_visible = true

func _update_color_mesh() -> void:
	if not _preview_mesh:
		return

	var dummy_uv := Rect2(0, 0, 1, 1)
	var dummy_atlas_size := Vector2(1, 1)
	_preview_mesh.mesh = _build_preview_array_mesh(dummy_uv, dummy_atlas_size, preview_texture, preview_uv_rect)

	_preview_mesh.basis = _build_preview_transform(Vector3.ZERO, preview_orientation, preview_mesh_rotation, preview_is_mirrored).basis

func _update_color_material(color: Color) -> void:
	if not _preview_mesh:
		return
	_preview_mesh.material_override = TML3D_GlobalUtil.create_unshaded_material(color, false, 99)
