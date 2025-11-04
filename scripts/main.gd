extends Node2D

@onready var menu: MenuUI = $Menu
@onready var path_finder: Node2D = $PathFinder
@onready var robot: CharacterBody2D = %Robot
@onready var obstacles = get_tree().get_nodes_in_group("Obstacles")

signal debug_collision_toggled(toggled_on: bool)

func _ready() -> void:
	menu.reduced_visibility_toggled.connect(_on_reduced_visibility_button_toggled)
	menu.start_navigating.connect(_on_start_navigating_button_pressed)
	menu.robot_radius_changed.connect(_on_robot_radius_slider_value_changed)
	menu.restart_requested.connect(_on_restart_button_pressed)
	menu.exit_requested.connect(_on_exit_button_pressed)
	menu.debug_collision_toggled.connect(_on_debug_collision_check_toggled)

func _on_reduced_visibility_button_toggled(toggled_on: bool) -> void:
	path_finder.call_deferred("on_reduced_visibility_button_toggled", toggled_on)

func _on_start_navigating_button_pressed() -> void:
	path_finder.call_deferred("on_start_navigating_button_pressed")
	robot.call_deferred("on_go_button_pressed")

func _on_robot_radius_slider_value_changed(value: float) -> void:
	path_finder.call_deferred("on_robot_radius_slider_value_changed", value)

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_debug_collision_check_toggled(toggled_on: bool) -> void:
	get_tree().debug_collisions_hint = toggled_on
	get_tree().call_group("Obstacles", "_update_collision_polygon", robot.robot_radius)
