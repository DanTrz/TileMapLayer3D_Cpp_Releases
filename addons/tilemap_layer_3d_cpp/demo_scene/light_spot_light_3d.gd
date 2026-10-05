extends SpotLight3D

@export var tile_detector: TileDetectorArea3d
@export var debug_print: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.visible = false
	if tile_detector:
		tile_detector.tile_swap_completed.connect(on_tile_swap_completed)


func on_tile_swap_completed(tile_detector: TileDetectorArea3d,
detected_tile_info: TML3D_PlacedTileInfo, 
region_chunk: TML3D_TerrainRegionChunk) -> void:
	self.visible = !self.visible
	if debug_print:
		print("Setting Lights to: " , !self.visible)
		
		
