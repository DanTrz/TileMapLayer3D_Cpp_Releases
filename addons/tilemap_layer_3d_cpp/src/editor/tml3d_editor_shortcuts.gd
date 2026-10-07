@tool
extends RefCounted

const DEBUG_INPUT: bool = false
const CURSOR_REPEAT_DELAY: float = 0.3

enum Action {
	NONE,
	ROTATE_LEFT, ROTATE_RIGHT, TILT_FORWARD, TILT_BACKWARD, MIRROR, RESET,
	MOVE_FORWARD, MOVE_BACKWARD, MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN,
	CANCEL, DELETE_TILES, TOGGLE_ADDITIVE,
	FAST_MOVE,
	TEXTURE_ROTATE_CW, TEXTURE_ROTATE_CCW,
}

# Exact chords: Ctrl/Alt/Meta combinations are deliberately absent.
const PHYSICAL_BINDINGS: Dictionary[int, int] = {
	KEY_SPACE | KEY_MASK_SHIFT: Action.FAST_MOVE,
	KEY_Q: Action.ROTATE_LEFT, KEY_Q | KEY_MASK_SHIFT: Action.ROTATE_LEFT,
	KEY_E: Action.ROTATE_RIGHT, KEY_E | KEY_MASK_SHIFT: Action.ROTATE_RIGHT,
	KEY_R: Action.TILT_FORWARD, KEY_R | KEY_MASK_SHIFT: Action.TILT_BACKWARD,
	KEY_F: Action.MIRROR, KEY_F | KEY_MASK_SHIFT: Action.MIRROR,
	KEY_G: Action.TEXTURE_ROTATE_CW, KEY_G | KEY_MASK_SHIFT: Action.TEXTURE_ROTATE_CCW,
	KEY_T: Action.RESET, KEY_T | KEY_MASK_SHIFT: Action.RESET,
	KEY_W: Action.MOVE_FORWARD, KEY_W | KEY_MASK_SHIFT: Action.MOVE_UP,
	KEY_S: Action.MOVE_BACKWARD, KEY_S | KEY_MASK_SHIFT: Action.MOVE_DOWN,
	KEY_A: Action.MOVE_LEFT, KEY_A | KEY_MASK_SHIFT: Action.MOVE_LEFT,
	KEY_D: Action.MOVE_RIGHT, KEY_D | KEY_MASK_SHIFT: Action.MOVE_RIGHT,
	KEY_ESCAPE: Action.CANCEL, KEY_ESCAPE | KEY_MASK_SHIFT: Action.CANCEL,
	KEY_DELETE: Action.DELETE_TILES, KEY_DELETE | KEY_MASK_SHIFT: Action.DELETE_TILES,
}
# Z preserves the logical-key binding previously stored on the additive toolbar button.
const LOGICAL_BINDINGS: Dictionary[int, int] = {
	KEY_Z: Action.TOGGLE_ADDITIVE,
}
const CURSOR_DIRECTIONS: Dictionary[int, Vector3] = {
	Action.MOVE_FORWARD: Vector3.FORWARD, Action.MOVE_BACKWARD: Vector3.BACK,
	Action.MOVE_LEFT: Vector3.LEFT, Action.MOVE_RIGHT: Vector3.RIGHT,
	Action.MOVE_UP: Vector3.UP, Action.MOVE_DOWN: Vector3.DOWN,
}

var _plugin: TML3D_TileMapLayer3DPlugin
var _captured_keys: Dictionary[int, bool] = {}
var _cursor_repeat_remaining: Dictionary[int, float] = {}
var _cursor_physical_keys: Dictionary[int, bool] = {}
var _cursor_hold_time: float = 0.0
var _fast_move_camera: Camera3D = null
var _captured_mouse_buttons: int = 0


func _init(plugin: TML3D_TileMapLayer3DPlugin) -> void:
	_plugin = plugin


## Returning True means the plugin can handle and will consume this event. Only EditorPlugin._input calls this.
func can_handle_key_event(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	var fast_move: bool = is_fast_move_active()
	if not event.pressed:
		if key in [KEY_SHIFT, KEY_SPACE]:
			stop_fast_move()
		_stop_cursor_key(key)
		var captured_release: bool = _captured_keys.erase(key)
		return fast_move or captured_release
	if fast_move:
		_captured_keys[key] = false
		return true
	var fast_move_chord: bool = (
		PHYSICAL_BINDINGS.get(key | event.get_modifiers_mask(), Action.NONE) == Action.FAST_MOVE
		or (key == KEY_SHIFT and Input.is_key_pressed(KEY_SPACE) and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed)
	)
	if not event.echo and fast_move_chord and _can_fast_move():
		var camera: Camera3D = get_focused_camera()
		if camera and _plugin.get_window().has_focus():
			_fast_move_camera = camera
			stop_cursor_movement()
			for captured_key: int in _captured_keys:
				_captured_keys[captured_key] = false
			_captured_keys[KEY_SHIFT] = false
			_captured_keys[KEY_SPACE] = false
			_captured_mouse_buttons = Input.get_mouse_button_mask()
			_plugin._prepare_fast_move()
			_trace(event, Action.FAST_MOVE, true)
			return true
	if not event.echo:
		_stop_cursor_key(key)
		_captured_keys.erase(key)  # A key release can be lost while the editor lacks focus.
	var captured: bool = _captured_keys.has(key)
	if event.echo and captured and not _captured_keys[key]:
		return true
	if not PHYSICAL_BINDINGS.has(key) and not LOGICAL_BINDINGS.has(event.keycode):
		return captured
	if event.echo and not captured:
		return false
	if not _has_active_layer():
		return captured
	var camera: Camera3D = get_focused_camera()
	if not camera or _plugin._is_editor_viewport_navigation(Input.get_mouse_button_mask()):
		return captured

	var action: Action = PHYSICAL_BINDINGS.get(key | event.get_modifiers_mask(),
		LOGICAL_BINDINGS.get(event.get_keycode_with_modifiers(), Action.NONE))
	var handler: Callable = _get_action_handler(action, camera)
	if not handler.is_valid():
		_trace(event, Action.NONE, captured)
		return captured

	_captured_keys[key] = true
	if CURSOR_DIRECTIONS.has(action):
		if not event.echo:
			handler.call()
			_cursor_repeat_remaining[key] = maxf(CURSOR_REPEAT_DELAY, 1.0 / _plugin.current_tile_map3d.settings.cursor_move_speed)
			_cursor_physical_keys[key] = event.physical_keycode != 0
			_plugin.set_process(true)
	elif not event.echo or action not in [Action.CANCEL, Action.DELETE_TILES, Action.TOGGLE_ADDITIVE]:
		handler.call()
	_trace(event, action, true)
	return true


func stop_cursor_movement() -> void:
	_cursor_repeat_remaining.clear()
	_cursor_physical_keys.clear()
	_cursor_hold_time = 0.0
	_update_processing()


func _stop_cursor_key(key: int) -> void:
	_cursor_repeat_remaining.erase(key)
	_cursor_physical_keys.erase(key)
	if _cursor_repeat_remaining.is_empty():
		_cursor_hold_time = 0.0
	_update_processing()


func _update_processing() -> void:
	_plugin.set_process(is_instance_valid(_fast_move_camera) or _captured_mouse_buttons != 0 or not _cursor_repeat_remaining.is_empty())


func stop_fast_move() -> void:
	_fast_move_camera = null
	_update_processing()


func reset_input() -> void:
	_fast_move_camera = null
	_captured_mouse_buttons = 0
	for key: int in _captured_keys:
		_captured_keys[key] = false
	stop_cursor_movement()


func _can_fast_move() -> bool:
	return _has_active_layer() and is_instance_valid(_plugin.tile_cursor) and _plugin.tile_cursor.is_visible_in_tree() and _has_cursor_placement()


func is_fast_move_active() -> bool:
	if not is_instance_valid(_fast_move_camera):
		return false
	if not _can_fast_move() or not _plugin.get_window().has_focus() or get_focused_camera() != _fast_move_camera:
		stop_fast_move()
		return false
	if not Input.is_key_pressed(KEY_SHIFT) or not Input.is_key_pressed(KEY_SPACE):
		stop_fast_move()
		return false
	return true


func capture_mouse_release(event: InputEvent) -> bool:
	if not event is InputEventMouseButton or event.pressed:
		return false
	var button_mask: int = 1 << (event.button_index - 1)
	if (_captured_mouse_buttons & button_mask) == 0:
		return false
	_captured_mouse_buttons &= ~button_mask
	_update_processing()
	return true


func handle_fast_move_mouse(camera: Camera3D, event: InputEvent) -> bool:
	if not event is InputEventMouse:
		return false
	if capture_mouse_release(event):
		return true
	if not is_fast_move_active():
		return _captured_mouse_buttons != 0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
			_captured_mouse_buttons |= 1 << (event.button_index - 1)
		if event.button_index == MOUSE_BUTTON_LEFT and camera == _fast_move_camera:
			_plugin._fast_move_cursor_to_tile(camera, event.position)
	return true


func process_cursor_movement(delta: float) -> void:
	if not _has_active_layer() or not _plugin.get_window().has_focus():
		reset_input()
		return
	_captured_mouse_buttons &= Input.get_mouse_button_mask()
	if is_fast_move_active():
		return
	if _cursor_repeat_remaining.is_empty():
		_update_processing()
		return
	var camera: Camera3D = get_focused_camera()
	if not camera or _plugin._is_editor_viewport_navigation(Input.get_mouse_button_mask()):
		stop_cursor_movement()
		return
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_META):
		stop_cursor_movement()
		return

	var modifiers: int = KEY_MASK_SHIFT if Input.is_key_pressed(KEY_SHIFT) else 0
	var frame_delta: float = minf(delta, 0.1)
	_cursor_hold_time += frame_delta
	var speed_multiplier: float = lerpf(1.0, 4.0, smoothstep(CURSOR_REPEAT_DELAY, 2.0, _cursor_hold_time))
	var interval: float = 1.0 / (_plugin.current_tile_map3d.settings.cursor_move_speed * speed_multiplier)
	for key: int in _cursor_repeat_remaining.keys():
		var pressed: bool = Input.is_physical_key_pressed(key) if _cursor_physical_keys[key] else Input.is_key_pressed(key)
		var action: Action = PHYSICAL_BINDINGS.get(key | modifiers, Action.NONE)
		var handler: Callable = _get_action_handler(action, camera)
		if not pressed or not CURSOR_DIRECTIONS.has(action) or not handler.is_valid():
			_stop_cursor_key(key)
			continue
		# Do not replay a long backlog after an editor stall.
		var remaining: float = _cursor_repeat_remaining[key] - frame_delta
		while remaining <= 0.0:
			handler.call()
			remaining += interval
		_cursor_repeat_remaining[key] = remaining


func _has_active_layer() -> bool:
	return (
		_plugin.is_active
		and is_instance_valid(_plugin.current_tile_map3d)
		and _plugin.current_tile_map3d.settings != null
		and _plugin.placement_manager != null
		and EditorInterface.get_selection().get_selected_nodes().has(_plugin.current_tile_map3d)
	)


func get_focused_camera() -> Camera3D:
	var focused_control: Control = _plugin.get_viewport().gui_get_focus_owner()
	if not focused_control or not focused_control.is_visible_in_tree():
		return null
	for index: int in range(4):
		var viewport: SubViewport = EditorInterface.get_editor_viewport_3d(index)
		if not viewport or not viewport.get_parent():
			continue
		# The editor's focused 3D input surface is a sibling of its SubViewportContainer.
		if focused_control.get_parent() == viewport.get_parent().get_parent():
			return viewport.get_camera_3d()
	return null


func _has_cursor_placement() -> bool:
	if _plugin._is_scatter_mode():
		return _plugin.current_tile_map3d.settings.scatter_detection_mode == TML3D_ScatterSurfacePicker.DETECT_GRID_PLANE
	return _plugin.placement_manager.get_placement_mode() in [TML3D_PlacementManager.CURSOR_PLANE, TML3D_PlacementManager.CURSOR]


func _get_action_handler(action: Action, camera: Camera3D) -> Callable:
	if CURSOR_DIRECTIONS.has(action):
		if _plugin.tile_cursor and _has_cursor_placement():
			return _move_cursor.bind(camera, CURSOR_DIRECTIONS[action])
		return Callable()

	match action:
		Action.CANCEL:
			if _plugin._area_fill_operator and _plugin._area_fill_operator.is_selecting:
				return _plugin._area_fill_operator.cancel
			if _plugin._is_sculpting_mode() and _plugin._sculpt_manager and _plugin._sculpt_manager.get_state() != TML3D_SculptManager.IDLE:
				return _cancel_sculpt
			return Callable()
		Action.DELETE_TILES:
			if _plugin._is_vertex_edit_mode() and _plugin._vertex_edit_manager:
				return _plugin._on_vertex_delete_requested
			return Callable()
		Action.TOGGLE_ADDITIVE:
			if _plugin.is_smart_select_mode():
				return _plugin._on_smart_select_additive_toggled.bind(not _plugin.current_tile_map3d.settings.smart_select_additive)
			return Callable()

	# if _plugin._is_autotile_mode() or _plugin._is_animated_tile_mode() or _plugin._is_vertex_edit_mode():
	if _plugin._is_autotile_mode() or _plugin._is_vertex_edit_mode():
		return Callable()
	match action:
		Action.ROTATE_LEFT:
			return _plugin._on_editor_ui_rotate_requested.bind(-1, camera)
		Action.ROTATE_RIGHT:
			return _plugin._on_editor_ui_rotate_requested.bind(1, camera)
		Action.TILT_FORWARD, Action.TILT_BACKWARD:
			return _plugin._on_editor_ui_tilt_requested.bind(action == Action.TILT_BACKWARD, camera)
		Action.MIRROR:
			return _plugin._on_editor_ui_mirror_requested.bind(not _plugin.placement_manager.get_is_current_texture_mirrored(), camera)
		Action.TEXTURE_ROTATE_CW, Action.TEXTURE_ROTATE_CCW:
			return _plugin._on_editor_ui_texture_rotation_requested.bind(1 if action == Action.TEXTURE_ROTATE_CW else -1, camera)
		Action.RESET:
			return _plugin._on_editor_ui_reset_requested.bind(camera)
	return Callable()


func _move_cursor(camera: Camera3D, direction: Vector3) -> void:
	var movement: Vector3 = _plugin._get_snapped_cardinal_vector(camera.global_basis * direction)
	if not movement.is_zero_approx():
		_plugin.tile_cursor.move_by(Vector3i(movement))
		if DEBUG_INPUT:
			_plugin._print_cursor_position("move")


func _cancel_sculpt() -> void:
	_plugin._sculpt_manager.on_cancel()
	_plugin.current_tile_map3d.update_gizmos()


func _trace(event: InputEventKey, action: Action, consumed: bool) -> void:
	if not DEBUG_INPUT or event.echo:
		return
	var chord: String = event.as_text_physical_keycode() if event.physical_keycode else event.as_text_keycode()
	if action == Action.TOGGLE_ADDITIVE:
		chord = event.as_text_keycode()
	if not consumed:
		print("TML3D: shortcut PASS %s (no tile action)" % chord)
	elif action == Action.NONE:
		print("TML3D: shortcut CAPTURE %s (held key; no tile action)" % chord)
	else:
		print("TML3D: shortcut CAPTURE %s -> %s" % [chord, Action.keys()[action]])
