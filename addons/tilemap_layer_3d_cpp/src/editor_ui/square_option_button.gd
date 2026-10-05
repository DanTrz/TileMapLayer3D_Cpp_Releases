@tool
class_name TML3D_SquareOptionButton
extends OptionButton

@export var option_items: Array[TML3D_OptionItem] = []
@export var icon_size: Vector2 = Vector2(16, 16)

func _ready() -> void:
	create_items_from_enum()
	fit_to_longest_item = false
	clip_text = true

	# Strip internal padding for a compact layout
	add_theme_constant_override("arrow_margin", 0)
	add_theme_constant_override("h_separation", 0)

	# Clear text on selection so only the icon shows
	item_selected.connect(_on_item_selected)

	_on_item_selected(selected)

	apply_opt_button_theme()

func _on_item_selected(_index: int) -> void:
	text = ""

func apply_opt_button_theme() -> void:
	# Sizing based on editor scale
	var scale: float = TML3D_GlobalUtil.get_editor_ui_scale()

	var icon_size_px: float = TML3D_GlobalConstants.BUTTOM_CONTEXT_UI_SIZE * scale
	custom_minimum_size = Vector2(icon_size_px, icon_size_px)

	# Prevent button from growing to fit text
	fit_to_longest_item = false
	clip_text = true

func create_items_from_enum() -> void:
	clear()
	var scale: float = TML3D_GlobalUtil.get_editor_ui_scale()
	var editor_theme: Theme = EditorInterface.get_editor_theme()

	for index: int in range(option_items.size()):
		var option_item: TML3D_OptionItem = option_items[index]
		if option_item == null:
			continue

		var icon: Texture2D = null
		if editor_theme.has_icon(option_item.icon_name, "EditorIcons"):
			icon = editor_theme.get_icon(option_item.icon_name, "EditorIcons")
		else:
			icon = editor_theme.get_icon("BoneMapperHandleCircle", "EditorIcons")

		var item_text: String = option_item.label
		var item_id: int = option_item.item_id if option_item.item_id >= 0 else index

		var image: Image = icon.get_image()
		image.decompress()

		if icon_size.x <= 0 and icon_size.y <= 0:
			icon_size = Vector2(icon.get_width(), icon.get_height())

		image.resize(icon_size.x * scale, icon_size.y * scale, Image.INTERPOLATE_NEAREST)

		image.adjust_bcs(1.0, 1.0, 0.0)
		var grey_icon: Texture2D = ImageTexture.create_from_image(image)

		if not grey_icon:
			grey_icon = editor_theme.get_icon("BoneMapperHandleCircle", "EditorIcons")

		add_icon_item(grey_icon, item_text, item_id)

class CustomObject:
	
	var item_reg: Dictionary[String, int]
