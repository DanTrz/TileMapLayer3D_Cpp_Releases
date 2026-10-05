@tool
class_name TML3D_EditorConst
extends RefCounted

## Editor-only VISUAL constants for the C++ addon's GDScript editor layer.
##
## These are colors, UI sizes, and option arrays used purely by editor UI / cursor /
## preview / gizmo visuals. They are NOT serialized and NOT part of the runtime data
## contract, so they live here in the editor layer rather than bloating the C++
## TML3D_GlobalConstants runtime class. Values mirror the legacy global_const.gd 1:1.
## Access statically: TML3D_EditorConst.CURSOR_X_AXIS_COLOR, etc.

# --- Cursor visuals (tile_cursor_3d / cursor_plane_visualizer) ---
const CURSOR_CENTER_COLOR: Color = Color(1, 1, 1, 0.8)
const CURSOR_CENTER_CUBE_SIZE: Vector3 = Vector3(0.2, 0.2, 0.2)
const CURSOR_X_AXIS_COLOR: Color = Color(1, 0, 0, 0.6)
const CURSOR_Y_AXIS_COLOR: Color = Color(0, 1, 0, 0.6)
const CURSOR_Z_AXIS_COLOR: Color = Color(0, 0, 1, 0.6)
const DEFAULT_CURSOR_START_POSITION: Vector3 = Vector3.ZERO

# --- Plane overlay colors (cursor_plane_visualizer) ---
const XY_PLANE_COLOR: Color = Color(0, 0, 1, 0.0)
const XZ_PLANE_COLOR: Color = Color(0, 1, 0, 0.0)
const YZ_PLANE_COLOR: Color = Color(1, 0, 0, 0.0)
const DEFAULT_GRID_LINE_COLOR: Color = Color(0.5, 0.5, 0.5, 1.0)

# --- Preview visuals (tile_preview_3d) ---
const DEFAULT_PREVIEW_COLOR: Color = Color(1, 1, 1, 0.7)
const PREVIEW_GRID_INDICATOR_COLOR: Color = Color(1.0, 0.8, 0.0, 0.9)
const PREVIEW_GRID_INDICATOR_SIZE: Vector3 = Vector3(0.15, 0.15, 0.15)

# --- Area fill selector visuals ---
const AREA_FILL_BOX_COLOR: Color = Color(0.0, 0.8, 1.0, 0.3)
const AREA_FILL_GRID_LINE_COLOR: Color = Color(0.0, 0.8, 1.0, 0.4)
const MIN_AREA_FILL_SIZE: Vector3 = Vector3(0.1, 0.1, 0.1)

# --- Smart fill gizmo visuals ---
const SMART_FILL_PREVIEW_COLOR: Color = Color(0.0, 0.8, 1.0, 0.3)
const SMART_FILL_START_MARKER_COLOR: Color = Color(0.0, 0.9, 0.0, 0.5)

# --- Vertex edit gizmo visuals ---
const VERTEX_WIREFRAME_COLOR: Color = Color(1.0, 0.4, 0.4, 0.8)

# --- Debug visuals / flags (debug_info_generator) ---
const DEBUG_CHUNK_BOUNDS_COLOR: Color = Color(0.0, 1.0, 1.0, 0.6)
const DEBUG_CHUNK_MANAGEMENT: bool = false
const DEBUG_VALIDATE_AFTER_MUTATION: bool = false

# --- UI dialog sizes (popup_centered base sizes; scaled via TML3D_GlobalUtil.scale_ui_size) ---
const UI_DIALOG_SIZE_CONFIRM: Vector2i = Vector2i(450, 200)
const UI_DIALOG_SIZE_DEFAULT: Vector2i = Vector2i(800, 600)

# --- Dropdown option arrays ---
const CURSOR_STEP_OPTIONS: Array[float] = [0.25, 0.5, 1.0, 2.0]
const GRID_SNAP_OPTIONS: Array[float] = [1.0, 0.5, 0.25]
const PLACEMENT_MODE_NAMES: Array[String] = ["CURSOR_PLANE", "CURSOR", "RAYCAST"]
const TEXTURE_FILTER_OPTIONS: Array[String] = [
	"Nearest",           # 0 - TEXTURE_FILTER_NEAREST
	"Nearest Mipmap",    # 1 - TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	"Linear",            # 2 - TEXTURE_FILTER_LINEAR
	"Linear Mipmap"      # 3 - TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
]
