# Robot.gd (pe nodul robot, ex. CharacterBody2D/Node2D)
@tool 

extends CharacterBody2D
signal radius_changed(new_radius: float)
var can_move: bool = false
@onready var reduced_visibility_button: CheckButton = %ReducedVisibilityButton
@onready var robot_radius_slider: HSlider = %RobotRadiusSlider
@onready var go_button: Button = %GoButton

@onready var cshape: CollisionShape2D = $CollisionShape2D
@export var speed: float = 120.0
@export var arrive_radius: float = 5.0 
@export_range(1.0, 30.0, 0.1, "px")
var robot_radius: float:
	set(value):
		if is_equal_approx(_robot_radius, value):
			return
		_robot_radius = clamp(value, 1.0, 30.0)
		_apply_radius_to_shape(_robot_radius)
		emit_signal("radius_changed", _robot_radius)
	get:
		return _robot_radius
var _robot_radius := 1.0
var _path: PackedVector2Array = []
var _next_waypoint = 0
func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed
	
func _physics_process(delta: float) -> void:
	# If path is not ready yet or finish is reached, stop
	if _path.is_empty() or _next_waypoint >= _path.size() or !can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var target := _path[_next_waypoint]
	var to_target := (target - global_position)
	var dist := to_target.length()
	
	if(dist <= arrive_radius):
		_next_waypoint += 1
	var dir := to_target.normalized()
	velocity = dir * speed
	move_and_slide()

func _on_path_finder_path_ready(points: PackedVector2Array) -> void:
	_path = points
	_next_waypoint = 0

func _ready():
	if cshape and cshape.shape:
		cshape.shape = cshape.shape.duplicate()
	_apply_radius_to_shape(_robot_radius)
	call_deferred("emit_signal", "radius_changed", _robot_radius)

func _apply_radius_to_shape(r: float) -> void:
	if not cshape:
		return
	if cshape.shape == null:
		cshape.shape = CircleShape2D.new()
	var circle := cshape.shape as CircleShape2D
	if circle:
		circle.radius = r
		cshape.queue_redraw()
		queue_redraw()
		
func _draw():
	# Draw circle in both editor and runtime
	draw_circle(Vector2.ZERO, _robot_radius, Color(0, 0, 1, 0.3))
	draw_circle(Vector2.ZERO, _robot_radius, Color(0, 0, 1, 1), false, 2)


func on_go_button_pressed() -> void:
	can_move = true
