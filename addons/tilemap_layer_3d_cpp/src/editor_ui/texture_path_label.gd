@tool
extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mouse_entered.connect(on_mouse_entered)
	tooltip_text = text
	

func on_mouse_entered() ->void:
	tooltip_text = text
	print("Mouse Entered")

	
