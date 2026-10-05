extends StaticBody3D
@export var tile_detector: TileDetectorArea3d
@export var door_collision: CollisionShape3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if tile_detector:
		tile_detector.tile_swap_completed.connect(_on_tile_swap_completed)


func _on_tile_swap_completed(tile_detector: TileDetectorArea3d,
detected_tile_info: TML3D_PlacedTileInfo, 
region_chunk: TML3D_TerrainRegionChunk) -> void:

	if door_collision:
		door_collision.disabled = !door_collision.disabled
	print("Change ", self.name, " collision to: ", !door_collision.disabled )


	
