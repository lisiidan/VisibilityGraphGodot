@tool
extends StaticBody2D

@onready var polygon_2d: Polygon2D = $Polygon2D
@onready var collision_polygon_2d: CollisionPolygon2D = $CollisionPolygon2D
@onready var robot: CharacterBody2D = %Robot
@onready var debug_collision_check: CheckBox = %DebugCollisionCheck

var original_poly: PackedVector2Array

func _ready() -> void:
	get_tree().debug_collisions_hint = false
	original_poly = polygon_2d.polygon
	_update_collision_polygon(5.0)  # initial value

	# Connect to the robot’s signal if possible
	if robot and robot.has_signal("radius_changed"):
		robot.radius_changed.connect(_on_radius_changed)
		
	if debug_collision_check and debug_collision_check.has_signal("toggled"):
		debug_collision_check.toggled.connect(_on_debug_collision_check_toggled)

func _on_radius_changed(new_radius: float) -> void:
	_update_collision_polygon(new_radius)

func _update_collision_polygon(dist: float) -> void:
	var expanded := Geometry2D.offset_polygon(original_poly, dist, Geometry2D.JOIN_MITER)
	if expanded.size() > 0:
		collision_polygon_2d.polygon = expanded[0]
	else:
		collision_polygon_2d.polygon = original_poly
	collision_polygon_2d.global_position = polygon_2d.global_position

func _on_robot_radius_changed(new_radius: float) -> void:
	_update_collision_polygon(new_radius) # Replace with function body.


func _on_debug_collision_check_toggled(toggled_on: bool) -> void:
	get_tree().debug_collisions_hint = toggled_on
	_update_collision_polygon(robot.robot_radius)
