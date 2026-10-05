@tool
class_name TML3D_DebugInfoGenerator
extends RefCounted
## Generates diagnostic information for TileMapLayer3d_Cpp nodes (C++ build).
##
## The legacy DebugInfoGenerator performed a deep columnar-data audit by reading the node's
## private internals (_tile_positions, _saved_tiles_lookup, _tile_lookup, region registry, etc.).
## Those are C++ internals not exposed to GDScript. This version reports the same high-level
## diagnostics from the node's BOUND query API — preserving the "Show Debug Info" feature with
## real data. If a deeper audit is needed later, expose the specific internals from src/.


static func print_report(active_tile_map_layer3d: TileMapLayer3d_Cpp, placement_manager: TML3D_PlacementManager = null) -> void:
	if not active_tile_map_layer3d:
		push_warning("DebugInfoGenerator: No TileMapLayer3d_Cpp provided")
		return
	print(generate_report(active_tile_map_layer3d, placement_manager))


static func generate_report(active_tile_map_layer3d: TileMapLayer3d_Cpp, placement_manager: TML3D_PlacementManager = null) -> String:
	if not active_tile_map_layer3d:
		return "DebugInfoGenerator: No node."

	var report: String = ""
	report += "----------------------------------------------------------------------\n"
	report += " TileMapLayer3D (C++) DEBUG REPORT                                     \n"
	report += "----------------------------------------------------------------------\n"
	report += "  Node:            %s\n" % active_tile_map_layer3d.name
	report += "  Tile count:      %d\n" % active_tile_map_layer3d.get_tile_count()
	report += "  Chunk count:     %d\n" % active_tile_map_layer3d.chunk_count()
	report += "  Visible insts:   %d\n" % active_tile_map_layer3d.visible_instance_total()

	var ts: TileSet = active_tile_map_layer3d.get_tileset()
	report += "  TileSet:         %s\n" % (ts.resource_path if ts and ts.resource_path else ("<embedded>" if ts else "<none>"))

	var tex: Texture2D = TML3D_TileAtlasResolver.get_active_texture(active_tile_map_layer3d)
	report += "  Active texture:  %s\n" % (tex.resource_path if tex and tex.resource_path else ("<embedded>" if tex else "<none>"))

	var settings: TML3D_TileMapLayerSettings = active_tile_map_layer3d.settings
	if settings:
		report += "\n  --- Settings ---\n"
		report += "  grid_size:       %.3f\n" % settings.grid_size
		report += "  grid_snap_size:  %.3f\n" % settings.grid_snap_size
		report += "  mesh_mode:       %d\n" % settings.mesh_mode
		report += "  main_app_mode:   %d\n" % settings.main_app_mode
		report += "  texture_filter:  %d\n" % settings.texture_filter_mode
		report += "  picker_tile_sz:  %s\n" % str(settings.picker_tile_size)
		report += "  enable_collision:%s\n" % str(settings.enable_collision)
		report += "  animate_tiles:   %d\n" % settings.animate_tiles_list.size()

	if placement_manager:
		report += "\n  --- Placement Manager ---\n"
		report += "  pm grid_size:    %.3f\n" % placement_manager.get_grid_size()
		report += "  mesh_rotation:   %d\n" % placement_manager.get_current_mesh_rotation()
		report += "  texture_mirror:  %s\n" % str(placement_manager.get_is_current_texture_mirrored())
		report += "  texture_rot:     %d\n" % (placement_manager.get_current_texture_rotation() * 90)
		report += "  depth_scale:     %.3f\n" % placement_manager.get_current_depth_scale()
		report += "  placement_mode:  %d\n" % placement_manager.get_placement_mode()
		report += "  current_tile_uv: %s\n" % str(placement_manager.get_current_tile_uv())

	report += "----------------------------------------------------------------------\n"
	return report
