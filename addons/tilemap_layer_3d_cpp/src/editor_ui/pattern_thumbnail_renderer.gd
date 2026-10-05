@tool
extends RefCounted
class_name PatternThumbnailRenderer

## Renders a single baked pattern mesh (from TML3D_TileMeshMerger.merge_tiles_to_array_mesh with
## tiles_override) into a Texture2D for the pattern card thumbnail.

const ISO_DIR := Vector3(-1, -1, -1)  # camera look direction for the SubViewport 
const ICON_SIZE:int = 64

static func render(mesh: Mesh, material: Material, size: int = ICON_SIZE) -> Texture2D:
	if mesh == null:
		return null
	return _render_make_previews(mesh, size)


## Strategy A — built-in thumbnailer. One call; Godot supplies camera + lighting. The mesh already
## carries its baked material on surface 0, so no separate material wiring is needed here.
static func _render_make_previews(mesh: Mesh, size: int) -> Texture2D:
	var previews: Array = EditorInterface.make_mesh_previews([mesh], size)
	if previews.is_empty():
		return null
	return _finalize(previews[0], size)


## Locks the stored thumbnail to size×size as a plain ImageTexture (keeps RGBA8 alpha for the
## transparent card cutout). Shared by both render strategies so the serialized size is consistent.
static func _finalize(tex: Texture2D, size: int) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	if img.get_width() != size or img.get_height() != size:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


## Strategy B (swap-in) — off-screen SubViewport with an isometric ortho camera and our real material.
## Async: caller must `await` it. Returns a transparent-background ImageTexture.
static func _render_subviewport(mesh: Mesh, material: Material, size: int) -> Texture2D:
	var aabb: AABB = mesh.get_aabb()
	var center: Vector3 = aabb.get_center()
	var radius: float = maxf(aabb.size.length() * 0.5, 0.001)

	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	if material != null:
		mesh_inst.material_override = material
	vp.add_child(mesh_inst)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -45, 0)
	vp.add_child(light)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = radius * 2.2
	cam.position = center - ISO_DIR.normalized() * (radius * 4.0)
	cam.look_at(center, Vector3.UP)
	cam.near = 0.01
	cam.far = radius * 12.0
	vp.add_child(cam)

	EditorInterface.get_base_control().add_child(vp)
	await RenderingServer.frame_post_draw

	var tex: Texture2D = _finalize(vp.get_texture(), size)
	vp.queue_free()
	return tex
