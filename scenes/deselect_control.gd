extends LineEdit

# stolen from
# https://ask.godotengine.org/151265/how-do-i-deselect-defocus-a-gui-element-by-clicking-anywhere
func _input(event:InputEvent):
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 1:
		if not Rect2(Vector2.ZERO, size).has_point(make_input_local(event).position):
			release_focus()
