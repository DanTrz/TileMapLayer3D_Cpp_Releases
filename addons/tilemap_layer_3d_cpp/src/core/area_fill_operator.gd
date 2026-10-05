@tool
class_name TML3D_AreaFillOperator
extends RefCounted
## Handles area fill/erase operations for TileMapLayer3d_Cpp.
## Encapsulates state and coordinates the selection workflow.

# --- Signals ---
signal highlight_requested(start_pos: Vector3, end_pos: Vector3, orientation: int, is_erase: bool)
signal clear_highlights_requested()
signal out_of_bounds_warning(position: Vector3, orientation: int)

# --- State Variables ---
var is_selecting: bool = false
var _start_pos: Vector3 = Vector3.ZERO
var _start_orientation: int = 0
var _is_erase_mode: bool = false

# --- Dependencies ---
var _area_fill_selector: TML3D_AreaFillSelector3D = null
var _placement_manager: TML3D_PlacementManager = null


func setup(area_fill_selector: TML3D_AreaFillSelector3D, placement_manager: TML3D_PlacementManager) -> void:
	_area_fill_selector = area_fill_selector
	_placement_manager = placement_manager


func is_ready() -> bool:
	return _area_fill_selector != null and _placement_manager != null


func is_area_selecting() -> bool:
	return is_selecting


# --- Workflow Methods ---

func start(camera: Camera3D, screen_pos: Vector2, is_erase: bool, cursor_3d: TML3D_TileCursor3D) -> void:
	if not is_ready() or not is_instance_valid(cursor_3d):
		return

	var result: Dictionary
	if is_erase:
		# ERASE: 3D world-space raycast (all planes), so the box can span floor/walls/ceiling.
		result = _placement_manager.calculate_3d_world_position(camera, screen_pos, cursor_3d.get_world_position(), cursor_3d.get_plane_normal())
	else:
		# PAINT: plane-locked raycast (single orientation).
		result = _placement_manager.calculate_cursor_plane_placement(camera, screen_pos, cursor_3d.grid_position)

	if result.is_empty():
		return

	is_selecting = true
	_is_erase_mode = is_erase
	_start_pos = result.grid_pos
	_start_orientation = result.get("orientation", 0)

	_area_fill_selector.start_selection(
		result.grid_pos,
		result.get("orientation", 0),
		result.get("active_plane", Vector3.UP)
	)


func update(camera: Camera3D, screen_pos: Vector2, cursor_3d: TML3D_TileCursor3D) -> void:
	if not is_selecting or not is_ready() or not is_instance_valid(cursor_3d):
		return

	var result: Dictionary
	if _is_erase_mode:
		result = _placement_manager.calculate_3d_world_position(camera, screen_pos, cursor_3d.get_world_position(), cursor_3d.get_plane_normal())
	else:
		result = _placement_manager.calculate_cursor_plane_placement(camera, screen_pos, cursor_3d.grid_position)

	if result.is_empty():
		return

	_area_fill_selector.update_selection(result.grid_pos)
	highlight_requested.emit(_start_pos, result.grid_pos, _start_orientation, _is_erase_mode)


## Completes the area selection. Returns {min_pos, max_pos, orientation, is_erase}, or {} when
## there is nothing to apply. The caller performs the fill or erase.
func complete() -> Dictionary:
	if not is_selecting or not is_ready():
		cancel()
		return {}

	var selection: Dictionary = _area_fill_selector.complete_selection()
	if selection.is_empty():
		cancel()
		return {}

	var min_pos: Vector3 = selection.min_pos
	var max_pos: Vector3 = selection.max_pos
	var orientation: int = selection.orientation

	# Only block FILL outside bounds; ERASE is always allowed (legacy/old-save cleanup).
	if not _is_erase_mode and not _is_area_within_bounds(min_pos, max_pos):
		push_warning("TileMapLayer3D: Area fill blocked - selection extends beyond valid range (±%.1f)" % TML3D_GlobalConstants.get_MAX_GRID_RANGE())
		out_of_bounds_warning.emit(_start_pos, orientation)
		cancel()
		return {}

	clear_highlights_requested.emit()
	is_selecting = false
	return {"min_pos": min_pos, "max_pos": max_pos, "orientation": orientation, "is_erase": _is_erase_mode}


func cancel() -> void:
	if _area_fill_selector:
		_area_fill_selector.cancel_selection()
	clear_highlights_requested.emit()
	is_selecting = false


func reset_state() -> void:
	is_selecting = false
	_start_pos = Vector3.ZERO
	_start_orientation = 0
	_is_erase_mode = false
	if _area_fill_selector:
		_area_fill_selector.cancel_selection()


# --- Helper Methods ---

func _is_area_within_bounds(min_pos: Vector3, max_pos: Vector3) -> bool:
	var max_range: float = TML3D_GlobalConstants.get_MAX_GRID_RANGE()
	return (
		abs(min_pos.x) <= max_range and abs(min_pos.y) <= max_range and abs(min_pos.z) <= max_range and
		abs(max_pos.x) <= max_range and abs(max_pos.y) <= max_range and abs(max_pos.z) <= max_range
	)
