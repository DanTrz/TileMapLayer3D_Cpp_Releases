@tool
extends ShaderMaterial
class_name TML3D_FoliageAtlasMaterial

const FOLIAGE_SHADER: Shader = preload(
	"res://addons/tilemap_layer_3d_cpp/demo_scene/temp_tileset/FoliageAnimation_toon.gdshader"
)

@export_category("Atlas")
@export var atlas_region: AtlasTexture:
	set(value):
		if atlas_region == value:
			return
		_disconnect_atlas_region()
		atlas_region = value
		_connect_atlas_region()
		_sync_atlas_region()
		emit_changed()


func _init() -> void:
	shader = FOLIAGE_SHADER
	_connect_atlas_region()
	_sync_atlas_region()


func _connect_atlas_region() -> void:
	if atlas_region and not atlas_region.changed.is_connected(_on_atlas_region_changed):
		atlas_region.changed.connect(_on_atlas_region_changed)


func _disconnect_atlas_region() -> void:
	if atlas_region and atlas_region.changed.is_connected(_on_atlas_region_changed):
		atlas_region.changed.disconnect(_on_atlas_region_changed)


func _on_atlas_region_changed() -> void:
	_sync_atlas_region()
	emit_changed()


func _sync_atlas_region() -> void:
	if shader != FOLIAGE_SHADER:
		shader = FOLIAGE_SHADER
	if not atlas_region or not atlas_region.atlas:
		set_shader_parameter("albedo_tex", null)
		set_shader_parameter("use_albedo_region", false)
		return

	var atlas: Texture2D = atlas_region.atlas
	var region: Rect2 = atlas_region.region
	if region.size.x <= 0.0:
		region.size.x = atlas.get_width()
	if region.size.y <= 0.0:
		region.size.y = atlas.get_height()

	set_shader_parameter("albedo_tex", atlas)
	set_shader_parameter(
		"albedo_region_px",
		Vector4(region.position.x, region.position.y, region.size.x, region.size.y)
	)
	set_shader_parameter("use_albedo_region", true)
