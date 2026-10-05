@tool
extends FlowContainer
class_name ScatterModeGroup
@onready var tool_label: Label = %ToolLabel
@onready var detection_label: Label = %DetectionLabel
@onready var scatter_detection_mode: OptionButton = %ScatterDetectionMode
@onready var collision_mask_label: Label = %CollisionMaskLabel
@onready var scatter_collision_mask: SpinBox = %ScatterCollisionMask
@onready var radius_label: Label = %RadiusLabel
@onready var scatter_brush_radius: SpinBox = %ScatterBrushRadius
@onready var density_label: Label = %DensityLabel
@onready var scatter_density: SpinBox = %ScatterDensity
@onready var strength_label: Label = %StrengthLabel
@onready var scatter_scale_strength: SpinBox = %ScatterScaleStrength
@onready var tile_grid_pos_label: Label = %TileGridPosLabel
@onready var tile_world_pos_label: Label = %TileWorldPosLabel
@onready var scatter_tool: OptionButton = %ScatterTool

func _ready() -> void:
	resize_items() 
	

func resize_items() -> void:
	var ui_scale: float = TML3D_GlobalUtil.get_editor_ui_scale()

	tool_label.add_theme_font_size_override("font_size", int(10 * ui_scale))
	detection_label.add_theme_font_size_override("font_size", int(10 * ui_scale))
	collision_mask_label.add_theme_font_size_override("font_size", int(10 * ui_scale))
	radius_label.add_theme_font_size_override("font_size", int(10 * ui_scale))
	density_label.add_theme_font_size_override("font_size", int(10 * ui_scale))
	strength_label.add_theme_font_size_override("font_size", int(10 * ui_scale))
	tile_grid_pos_label.add_theme_font_size_override("font_size", int(10 * ui_scale))
	tile_world_pos_label.add_theme_font_size_override("font_size", int(10 * ui_scale))
	scatter_detection_mode.add_theme_font_size_override("font_size", int(10 * ui_scale))
	scatter_tool.add_theme_font_size_override("font_size", int(10 * ui_scale))
	
	scatter_collision_mask.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))
	scatter_brush_radius.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))
	scatter_density.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))
	scatter_scale_strength.get_line_edit().add_theme_font_size_override("font_size", int(10 * ui_scale))


	
	
	
