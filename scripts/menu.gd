extends Control
class_name MenuUI

signal reduced_visibility_toggled(toggled_on: bool)
signal start_navigating
signal robot_radius_changed(value: float)
signal restart_requested
signal exit_requested
signal debug_collision_toggled(toggled_on: bool)

@onready var reduced_visibility_button: CheckButton = %ReducedVisibilityButton
@onready var restart_button: Button = %RestartButton
@onready var robot_radius_slider: HSlider = %RobotRadiusSlider
@onready var go_button: Button = %GoButton
@onready var debug_collision_check: CheckBox = %DebugCollisionCheck
@onready var exit_button: Button = %ExitButton

func _ready() -> void:
	reduced_visibility_button.toggled.connect(_on_reduced_visibility_button_toggled)
	go_button.pressed.connect(_on_start_navigating_button_pressed)
	robot_radius_slider.value_changed.connect(_on_robot_radius_slider_value_changed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	debug_collision_check.toggled.connect(_on_debug_collision_check_toggled)
	
	# First states on ready
	reduced_visibility_toggled.emit(reduced_visibility_button.button_pressed)
	robot_radius_changed.emit(float(robot_radius_slider.value))
	debug_collision_toggled.emit(debug_collision_check.button_pressed)

func _on_reduced_visibility_button_toggled(toggled_on: bool) -> void:
	reduced_visibility_toggled.emit(toggled_on)

func _on_start_navigating_button_pressed() -> void:
	reduced_visibility_button.disabled = true
	robot_radius_slider.editable = false
	go_button.disabled = true
	
	reduced_visibility_button.visible = false
	robot_radius_slider.visible = false
	go_button.visible = false
	start_navigating.emit()

func _on_robot_radius_slider_value_changed(value: float) -> void:
	robot_radius_changed.emit(float(value))

func _on_restart_button_pressed() -> void:
	restart_requested.emit()

func _on_exit_button_pressed() -> void:
	exit_requested.emit()

func _on_debug_collision_check_toggled(toggled_on: bool) -> void:
	debug_collision_toggled.emit(toggled_on)
