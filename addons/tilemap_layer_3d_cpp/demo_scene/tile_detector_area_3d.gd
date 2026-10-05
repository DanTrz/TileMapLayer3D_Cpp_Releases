extends Area3D
class_name TileDetectorArea3d
@export var tile_map_layer_3d: TileMapLayer3d_Cpp = null


@export_enum("SwapTiles:1", "ManageAnimation:2") var operation_type: int = 1
@export var input_action: Key = KEY_F1

@export_group("Tile Detection")
@export var use_raycast: bool = true
@export var raycas_direction: Vector3 = Vector3.ZERO
@export var tile_world_position: Vector3 = Vector3.ZERO

@export_group("SwapTiles")
@export var swap_all_collection: bool = false
@export var max_collection_step: int = 2
@onready var start_point_marker_3d: Marker3D = $StartPointMarker3D
@export var regenerate_collision: bool = false

@export_group("ManageAnimation")
@export var set_animation_frame: int = 0
@export var set_animation_speed: int = 0



@export_group("Debug Other")
@export var print_debug: bool = false
## Key that toggles a highlight of every tile in this detector's region (audit region scope).
@export var debug_region_highlight_key: Key = KEY_F4

@onready var action_label: Label3D = $ActionLabel
var can_execute_action: bool = false
var _region_highlight_on: bool = false

signal tile_swap_completed(
	tile_detector: TileDetectorArea3d,
	detected_tile_info: TML3D_PlacedTileInfo,
	region_chunk: TML3D_TerrainRegionChunk)


func _ready() -> void:
	self.body_entered.connect(on_body_entered)
	self.body_exited.connect(on_body_exited)

	action_label.visible = false
	can_execute_action = false

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == debug_region_highlight_key and can_execute_action:
		_toggle_region_highlight()
		return

	if event.keycode == input_action and can_execute_action:
		if operation_type == 1:
			swap_tiles()
			return
		manage_animation_tiles()

func manage_animation_tiles() -> void:
	var tile_info: TML3D_PlacedTileInfo = null
	if use_raycast:
		tile_info = get_tile_info_from_raycast()
	else:
		tile_info = get_tile_info_from_position(tile_world_position)

	if tile_info and tile_map_layer_3d:
		tile_map_layer_3d.runtime_api.set_animated_group_speed(tile_info, set_animation_speed)
		#tile_map_layer_3d.runtime_api.pause_animated_group(tile_info)
		#tile_map_layer_3d.runtime_api.resume_animated_group(tile_info)
		#tile_map_layer_3d.runtime_api.set_animated_group_frame(tile_info, set_animation_frame, true)

		# if print_debug:
	
	if print_debug:
			print("Checking Node: " + self.name)
			var region_chunk: TML3D_TerrainRegionChunk = tile_info.get_terrain_region_chunk()
			print("Manage Animation started with use_raycast: ", use_raycast, " . RESULT:",
			"  / detected_tile_atlascoods: ", tile_info.atlas_coords, 
			" / detected_tile_key: ", tile_info.tile_key, 
			"  / wordl_pos: ", tile_info.world_position, 
			"  / region_key: ", region_chunk.region_key, 
			"  / grid_pos: ", tile_info.grid_position ,
			" / set_animation_frame: ", set_animation_frame, 
			" / set_animation_speed: ", set_animation_speed)

func swap_tiles() -> void:
	var tile_info: TML3D_PlacedTileInfo = null
	if use_raycast:
		tile_info = get_tile_info_from_raycast()
	else:
		tile_info = get_tile_info_from_position(tile_world_position)

	if tile_info and tile_map_layer_3d:
		var region_chunk: TML3D_TerrainRegionChunk = tile_info.get_terrain_region_chunk()

		if print_debug:
			print("Checking Node: " + self.name)
			var default_variant_tile: Vector2i = tile_map_layer_3d.runtime_api.get_variant_tile_data(tile_info.tile_key)
			print("Swap Tile started with use_raycast: ", use_raycast, " . RESULT: region_key: ", region_chunk.region_key ,
			"  / wordl_pos: ", tile_info.world_position, 
			"  / region_key: ", region_chunk.region_key, 
			"  / grid_pos: ", tile_info.grid_position ,
			"  / detected_tile_atlascoods: ", tile_info.atlas_coords, " / detected_tile_key: ", tile_info.tile_key, " / detected_tile.mesh_mode: ", tile_info.mesh_mode, " / default_variant_tile: ", default_variant_tile, " / swap_all_collection: ", swap_all_collection, " / max_collection_step: ", max_collection_step, " / regenerate_collision: ", regenerate_collision)

		if swap_all_collection:
			tile_map_layer_3d.runtime_api.swap_tile_collection_texture(tile_info, true, max_collection_step, 0.15)
		else:
			tile_map_layer_3d.runtime_api.swap_tile_texture(tile_info, true)

		if regenerate_collision:
			tile_map_layer_3d.runtime_api.set_collision_for_region(tile_info, true, true)

		tile_swap_completed.emit(self, tile_info, region_chunk)
	else:
		if print_debug:
			print("Swap Tile failed. No tile detected at the specified position or raycast direction.")

		# tile_map_layer_3d.runtime_api.place_tile(tile_info.world_position + Vector3(0, 2.0, 0), tile_info.uv_rect, tile_info.orientation, tile_info)
		# print("Tile_info World Pos", tile_info.world_position, " Placing Tile at " + str(tile_info.world_position + Vector3(0, 2.0, 0)) + " with UV: " + str(tile_info.uv_rect) + " and orientation: " + str(tile_info.orientation))


## Region audit: draws our OWN MultiMeshInstance3D (a child of this detector), so nothing in
## the addon's highlight system can clear it. Shows one cube per tile in the region plus the
## region's world AABB as a wireframe-ish translucent box. Press the key again to remove.
func _toggle_region_highlight() -> void:
	if tile_map_layer_3d == null:
		return
	if _region_highlight_on:
		tile_map_layer_3d.clear_highlights()
		_region_highlight_on = false
		print("TML3D REGION AUDIT cleared")
		return

	var tile_info: TML3D_PlacedTileInfo = null
	if use_raycast:
		tile_info = get_tile_info_from_raycast()
	else:
		tile_info = get_tile_info_from_position(tile_world_position)
	if tile_info == null:
		print("TML3D REGION AUDIT: no tile detected")
		return
	var region_chunk: TML3D_TerrainRegionChunk = tile_info.get_terrain_region_chunk()
	if region_chunk == null:
		print("TML3D REGION AUDIT: tile has NO region chunk")
		return

	var keys: PackedInt64Array = region_chunk.get_tile_keys()
	tile_map_layer_3d.highlight_tiles(keys)
	_region_highlight_on = true
	print("TML3D REGION AUDIT node=", tile_map_layer_3d.name,
		" region=", region_chunk.region_key,
		" region_tiles=", keys.size(),
		" node_total_tiles=", tile_map_layer_3d.get_tile_count())

func on_body_entered(body: Node3D) -> void:
	if body is TestPlayer:
		action_label.visible = true
		can_execute_action = true

func on_body_exited(body: Node3D) -> void:
	if body is TestPlayer:
		action_label.visible = false
		can_execute_action = false

func get_tile_info_from_raycast() -> TML3D_PlacedTileInfo:
	if not tile_map_layer_3d:
		return
	var ray_origin: Vector3 = start_point_marker_3d.global_position
	var tile_info: TML3D_PlacedTileInfo = tile_map_layer_3d.runtime_api.get_first_tile_from_raycast(ray_origin, raycas_direction, 5.5)
	return tile_info

func get_tile_info_from_position(position: Vector3) -> TML3D_PlacedTileInfo:
	if not tile_map_layer_3d:
		return
	var tile_info: TML3D_PlacedTileInfo = tile_map_layer_3d.runtime_api.find_tile(position)
	return tile_info
