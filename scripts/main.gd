extends Node2D

@onready var menu: MenuUI = $Menu
@onready var path_finder: Node2D = $PathFinder
@onready var robot: CharacterBody2D = $Robot
@onready var finish: Area2D = $Finish
@onready var obstacles = get_tree().get_nodes_in_group("Obstacles")
@onready var polygon_drawer: Node2D = $PolygonDrawer
@onready var border = get_tree().get_nodes_in_group("border")

var selected_obstacle: Node = null

func _ready() -> void:
	for b in border:
		b.input_pickable = false
	menu.reduced_visibility_toggled.connect(_on_reduced_visibility_button_toggled)
	menu.start_navigating.connect(_on_start_navigating_button_pressed)
	menu.draw_button_pressed.connect(polygon_drawer.toggle_drawing_allowed)
	menu.robot_radius_changed.connect(path_finder.on_robot_radius_slider_value_changed)
	menu.restart_requested.connect(_on_restart_button_pressed)
	menu.exit_requested.connect(_on_exit_button_pressed)
	#menu.debug_collision_toggled.connect(_on_debug_collision_check_toggled)
	
	robot.moved.connect(path_finder.update_path)
	finish.moved.connect(path_finder.update_path)
	path_finder.path_ready.connect(robot.on_path_finder_path_ready)
	polygon_drawer.new_obstacle_added.connect(new_polygon_added)

func _on_reduced_visibility_button_toggled(toggled_on: bool) -> void:
	path_finder.call_deferred("on_reduced_visibility_button_toggled", toggled_on)

func _on_start_navigating_button_pressed() -> void:
	path_finder.call_deferred("update_path")
	robot.call_deferred("on_go_button_pressed")

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()

func _on_exit_button_pressed() -> void:
	get_tree().quit()

#func _on_debug_collision_check_toggled(toggled_on: bool) -> void:
	#get_tree().debug_collisions_hint = toggled_on
	#get_tree().call_group("Obstacles", "_update_collision_polygon", robot.robot_radius)

func new_polygon_added(obstacle: Node) -> void:
	obstacle.clicked.connect(_on_obstacle_clicked)
	get_tree().call_group("Obstacles", "_update_collision_polygon", robot.robot_radius)
	path_finder.call_deferred("update_obstacles_info")


func _on_robot_mouse_entered() -> void:
	print("mouse on robot")
	
func _on_obstacle_clicked(obstacle):
	# Deselect previous
	if is_instance_valid(selected_obstacle):
		_reset_obstacle_visual(selected_obstacle)

	# Select new
	selected_obstacle = obstacle
	_set_obstacle_selected_visual(obstacle)

func _set_obstacle_selected_visual(obstacle):
	if obstacle.has_node("Polygon2D"):
		obstacle.get_node("Polygon2D").modulate = Color(1, 0.5, 0.5) # highlight

func _reset_obstacle_visual(obstacle):
	if obstacle.has_node("Polygon2D"):
		obstacle.get_node("Polygon2D").modulate = Color(1,1,1) # normal color

func _unhandled_input(event: InputEvent) -> void:
	# Deselect on click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_nodes = get_tree().get_nodes_in_group("Obstacles")
		var clicked_any = false
		for ob in clicked_nodes:
			if ob.get_global_mouse_position().distance_to(ob.global_position) < 10: 
				# simple check; optional: raycast or collision check
				clicked_any = true
				break
		if not clicked_any:
			_deselect_obstacle()

	# Delete key
	if event is InputEventKey and event.pressed:
		if event.is_action("delete_btn") and is_instance_valid(selected_obstacle):
			selected_obstacle.remove_from_group("Obstacles")
			selected_obstacle.queue_free()
			selected_obstacle = null
			path_finder.call_deferred("update_obstacles_info")

func _deselect_obstacle():
	if is_instance_valid(selected_obstacle):
		_reset_obstacle_visual(selected_obstacle)
	selected_obstacle = null
