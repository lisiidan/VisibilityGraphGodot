@tool
extends StaticBody2D

@onready var polygon_2d: Polygon2D = $Polygon2D
@onready var collision_polygon_2d: CollisionPolygon2D = $CollisionPolygon2D
@onready var robot: CharacterBody2D = $"../../Robot"
var dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO
@onready var path_finder: Node2D = $"../../PathFinder"

signal moved
signal move_finished
signal clicked(new_obstacle: Node)
signal move_started
var original_poly: PackedVector2Array

func _ready() -> void:
	input_pickable = true
	add_to_group("Obstacles")
	get_tree().debug_collisions_hint = false
	original_poly = polygon_2d.polygon
	_update_collision_polygon(5.0)  # initial value

	# Connect to the robot’s signal if possible
	if robot and robot.has_signal("radius_changed"):
		robot.radius_changed.connect(_on_radius_changed)
		
func _on_radius_changed(new_radius: float) -> void:
	_update_collision_polygon(new_radius)

func _update_collision_polygon(dist: float) -> void:
	var expanded := Geometry2D.offset_polygon(original_poly, dist + 2, Geometry2D.JOIN_MITER)
	if expanded.size() > 0:
		collision_polygon_2d.polygon = expanded[0]
	else:
		collision_polygon_2d.polygon = original_poly
	collision_polygon_2d.global_position = polygon_2d.global_position

func _on_robot_radius_changed(new_radius: float) -> void:
	_update_collision_polygon(new_radius) # Replace with function body.

func _input_event(_viewport, event, _shape_idx) -> void:
	#if Input.is_action_pressed("delete_btn"):
		#self.queue_free()
		#path_finder.call_deferred("update_obstacles_info")
	if Global.drawing_allowed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_grab_offset = global_position - get_global_mouse_position()
			dragging = true
			emit_signal("move_started", global_position)
			emit_signal("clicked", self)
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
	path_finder.call_deferred("update_path")
	emit_signal("moved")
