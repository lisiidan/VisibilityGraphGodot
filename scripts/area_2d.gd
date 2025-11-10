extends Area2D

var dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO

signal moved
signal move_finished
signal clicked
signal move_started

func _on_body_entered(_body: Node2D) -> void:
	print("Finish!")

func _input_event(_viewport, event, _shape_idx) -> void:
	if Global.drawing_allowed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			emit_signal("move_started", global_position)
			emit_signal("clicked")
		else:
			if dragging:
				dragging = false
				emit_signal("move_finished", global_position)
	elif event is InputEventMouseMotion and dragging:
		global_position += event.relative
		emit_signal("moved")
		
func _process(_delta: float) -> void:
	if not dragging:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		emit_signal("move_finished", global_position)
		return
	var new_pos:= get_global_mouse_position() + _grab_offset
	global_position = new_pos
	emit_signal("moved")
