@tool
extends Node3D

@export var tile_map_3d: TileMapLayer3d_Cpp
@export var player: TestPlayer
@export var fame_skip: int = 12
@export var terrain_lbl_3d: Label3D
@export_group("Runtime Tile Operation")
@export_tool_button("AddWallAbovePlayer") var add_wall_tile_runtime: Callable = create_square_walls_above_player
@export_tool_button("AddCubeAbovePlayer") var add_cube_runtime: Callable = create_cube_above_player

@export_tool_button("DeleteTileAbovePlayer") var delete_tile_runtime: Callable = delete_tile_above_player
@export var mesh_mode: TML3D_GlobalConstants.MeshMode = TML3D_GlobalConstants.MeshMode.BOX_MESH
# @export var create_tile_test_key: Key = KEY_F5
# @export var delete_tile_test_key: Key = KEY_F6
@export_group("Debug Options")
@export var debug_tile_info: bool = true
@export var debug_highlight_on_query: bool = true


var last_terrain_name: String = ""
var frame_count: int = 0
var _last_tile_key: int = -1

## Calculate the player world feet position
var player_feet_world_pos: Vector3:
	get:
		if !Engine.is_editor_hint():
			var shape: CapsuleShape3D = player.player_col_shape.shape as CapsuleShape3D
			if player and shape:
				# We subtract slightly less than the half-height, since Global Position is at center
				var height_offset: float = (shape.height / 2.0) - (shape.height / 5.0)
				return player.global_position - Vector3(0, height_offset, 0)
			return Vector3.ZERO
		return Vector3.ZERO

func _process(_delta: float) -> void:
	if debug_tile_info:
		_check_player_terrain()


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if not key_event or not key_event.pressed or key_event.echo:
		return
	# match event.keycode:
	# 	create_tile_test_key: 
	# 		create_tile_above_player()
	# 	delete_tile_test_key:
	# 		pass
	# 	_:
	# 		pass


func _check_player_terrain() -> void:
	if not tile_map_3d or not player:
		return
	
	await get_tree().process_frame
	frame_count += 1
	if frame_count % fame_skip == 0:
		_get_tile_at_player_feet()
		frame_count = 0


## Get tile data at the player's feet position using raycast.
func _get_tile_at_player_feet() -> void:
	last_terrain_name = "No Terrain Found"
	var custom_data_value: Variant = null
	
	if not tile_map_3d or not player:
		return
	# Start the Raycast on player location and Y axis we use the player base (feet position)
	var ray_origin: Vector3 = Vector3(player.global_position.x, player_feet_world_pos.y +0.5, player.global_position.z)
	# Get the first tile that hits downwads
	var tile_info: TML3D_PlacedTileInfo = tile_map_3d.runtime_api.get_first_tile_from_raycast(ray_origin, Vector3.DOWN, 1.0)

	# Get TileData from the tile key
	var tile_data : TileData = null
	if tile_info:
		tile_data = tile_map_3d.runtime_api.get_tile_data_from_key(tile_info.tile_key)

	if tile_data:

		##From here you can do whatever you want, like swapt the texture or get the Terrain Name, etc. 
		# Example 0: Retriving the value from custom_data for a giving custom_data layer
		custom_data_value = tile_data.get_custom_data("VariantTile") if tile_data.has_custom_data("VariantTile") else null;

		# Example 1: Retriving data from default VariantTile or CollectionTile data layers
		var variant_data: Vector2i = tile_map_3d.runtime_api.get_variant_tile_data(tile_info.tile_key)
		var collection_data: PackedVector2Array = tile_map_3d.runtime_api.get_collection_tile_data(tile_info.tile_key)

		#Example 1: Swap the texture of all related items in the CollectionTiles
		# if tile_info.tile_key != _last_tile_key:
		# 	_last_tile_key = tile_info.tile_key
		# 	tile_map_3d.runtime_api.swap_tile_collection_texture(tile_info, true)

		#Example 2: Swap the texture of just the Source Tile
		# tile_map_3d.runtime_api.set_tile_texture(tile_info, true)  

		#Example 3: Return the TerrainName and CustomData value to a Label3D in the scene
		last_terrain_name = get_terrain_name(tile_data)

		# to get the CustomData and TerrainName
		terrain_lbl_3d.text = "VariantTile: %s\nCollectionTile: %s\nTerrain: %s" % [
			custom_data_value, 
			collection_data, 
			last_terrain_name]
	else:
		terrain_lbl_3d.text = "No tile data found"

	if debug_highlight_on_query and tile_info:
		tile_map_3d.highlight_tiles([tile_info.tile_key])

func get_terrain_name(tile_data: TileData) -> String:	
	var terrain_data: int = tile_data.terrain
	var terrain_set_id: int = tile_data.terrain_set

	# Access the TileSet resource from your TileMapLayer
	var tile_set: TileSet = tile_map_3d.runtime_api.get_tileset()
	var terrain_name: String = "NoTerrain"
	# Check if the tile actually belongs to a terrain (returns -1 if it doesn't)
	if terrain_set_id != -1 and terrain_data != -1:
		terrain_name = tile_set.get_terrain_name(terrain_set_id, terrain_data)
	
	return terrain_name


func delete_tile_above_player() -> void:
	if not tile_map_3d or not player:
		return
	
	#Construct the Tile Coordinates and Parameters
	var pos_offset: Vector3 = Vector3(0, 2, 0)
	var tile_pos: Vector3 = player.global_position + pos_offset

	#Erase the Tile at Runtime or Procedurally.
	tile_map_3d.runtime_api.erase_tile(tile_pos, TML3D_GlobalUtil.TileOrientation.FLOOR)


func create_square_walls_above_player() -> void:
	if not tile_map_3d or not player:
		return

	#Construct the Tile Coordinates and Parameters
	var square_size : Vector2 = Vector2(4, 4)
	var atlas_floor_coords: Rect2 = tile_map_3d.runtime_api.atlas_coord_to_uv_rect(Vector2i(9, 2))
	var atlas_wall_coords: Rect2 = tile_map_3d.runtime_api.atlas_coord_to_uv_rect(Vector2i(9, 10))
	var grid_size: float = tile_map_3d.settings.grid_size
	var start_tile_pos: Vector3 = player.global_position + Vector3(0, 2, 0)
	var tile_pos: Vector3 = start_tile_pos

	## Create a square on the floor (With Regular Flat Square Tiles)
	for col: int in range(square_size.x):
		tile_pos.z = start_tile_pos.z + (grid_size * col) # Add gridsize to Z position for each column
		for row: int in range(square_size.y):
			tile_pos.x = start_tile_pos.x + (grid_size * row) # Add gridsize to X position for each row
			tile_map_3d.runtime_api.place_tile(tile_pos, atlas_floor_coords, TML3D_GlobalUtil.TileOrientation.FLOOR)

	## Create a wall of tiles on North Wall (Shows how to use the PlacedTileInfo to set the MeshMode and other parameters)
	tile_pos = start_tile_pos # Reset tile position to start position
	var new_tile_info := TML3D_PlacedTileInfo.new()
	new_tile_info.mesh_mode = mesh_mode
	# optional, pass more parameters if needed:
	# new_tile_info.texture_repeat_mode = 1
	# new_tile_info.depth_scale = 1.0
	# new_tile_info.depth_growth_mode = TML3D_GlobalConstants.DepthGrowthMode.INWARD
	for col: int in range(square_size.x):
		tile_pos.y = start_tile_pos.y + (grid_size * col) # Add gridsize to Y position for each column
		for row: int in range(square_size.y):
			tile_pos.x = start_tile_pos.x + (grid_size * row) # Add gridsize to X position for each row
			tile_map_3d.runtime_api.place_tile(tile_pos, atlas_wall_coords, TML3D_GlobalUtil.TileOrientation.WALL_NORTH, new_tile_info)


func create_cube_above_player() -> void:
	if not tile_map_3d or not player:
		return

	var square_size : Vector2 = Vector2(4, 4)
	var atlas_uv_coords: Rect2 = tile_map_3d.runtime_api.atlas_coord_to_uv_rect(Vector2i(7, 24))
	var grid_size: float = tile_map_3d.settings.grid_size
	var start_tile_pos: Vector3 = player.global_position + Vector3(0, 7, 0)
	var tile_pos: Vector3 = start_tile_pos

	#Create 1x1 box with 6 sides (Floor, Ceiling, 4 Walls)
	tile_map_3d.runtime_api.place_tile(tile_pos, atlas_uv_coords, TML3D_GlobalUtil.TileOrientation.CEILING)
	tile_map_3d.runtime_api.place_tile(tile_pos, atlas_uv_coords, TML3D_GlobalUtil.TileOrientation.WALL_SOUTH)
	tile_map_3d.runtime_api.place_tile(tile_pos, atlas_uv_coords, TML3D_GlobalUtil.TileOrientation.WALL_EAST)

	tile_map_3d.runtime_api.place_tile(tile_pos + Vector3(grid_size, 0, 0), atlas_uv_coords, TML3D_GlobalUtil.TileOrientation.WALL_WEST)
	tile_map_3d.runtime_api.place_tile(tile_pos + Vector3(0, grid_size, 0), atlas_uv_coords, TML3D_GlobalUtil.TileOrientation.FLOOR)
	tile_map_3d.runtime_api.place_tile(tile_pos + Vector3(0, 0, grid_size), atlas_uv_coords, TML3D_GlobalUtil.TileOrientation.WALL_NORTH)
