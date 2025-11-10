extends Control
class_name MenuUI

signal reduced_visibility_toggled(toggled_on: bool)
signal start_navigating
signal robot_radius_changed(value: float)
signal restart_requested
signal exit_requested
#signal debug_collision_toggled(toggled_on: bool)
signal draw_button_pressed(new_state: bool)

@onready var reduced_visibility_button: CheckButton = %ReducedVisibilityButton
@onready var restart_button: Button = %RestartButton
@onready var robot_radius_slider: HSlider = %RobotRadiusSlider
@onready var go_button: Button = %GoButton
#@onready var debug_collision_check: CheckBox = %DebugCollisionCheck
@onready var exit_button: Button = %ExitButton
@onready var draw_button: Button = %DrawButton
@onready var draw_hint_1: Label = $DrawHint1
@onready var draw_hint_2: Label = $DrawHint2

var draw_active := false
var started_navigating := false

func _ready() -> void:
	# UI buttons connect
	reduced_visibility_button.toggled.connect(_on_reduced_visibility_button_toggled)
	go_button.pressed.connect(_on_start_navigating_button_pressed)
	draw_button.pressed.connect(_on_draw_button_pressed)
	robot_radius_slider.value_changed.connect(_on_robot_radius_slider_value_changed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	#debug_collision_check.toggled.connect(_on_debug_collision_check_toggled)
	
	# First states on ready
	reduced_visibility_toggled.emit(reduced_visibility_button.button_pressed)
	robot_radius_changed.emit(float(robot_radius_slider.value))
	#debug_collision_toggled.emit(debug_collision_check.button_pressed)
	draw_hint_1.text = "You can move anything while not in draw mode. To delete obstacles select them and press DELETE"
	draw_hint_2.visible = false

func _on_reduced_visibility_button_toggled(toggled_on: bool) -> void:
	reduced_visibility_toggled.emit(toggled_on)

func _on_start_navigating_button_pressed() -> void:
	reduced_visibility_button.disabled = !reduced_visibility_button.disabled
	robot_radius_slider.editable = !robot_radius_slider.editable
	#go_button.disabled = !go_button.disabled
	draw_button.disabled = !draw_button.disabled
	started_navigating = !started_navigating
	
	draw_active = false
	draw_button_pressed.emit(draw_active)
	
	if started_navigating:
		go_button.text = "Stop"
		draw_hint_1.visible = false
		draw_hint_2.visible = false
	else:
		draw_button.modulate = Color(1.0, 1.0, 1.0)
		go_button.text = "Go"
		draw_hint_1.visible = true
		draw_hint_1.text = "You can move anything while not in draw mode. To delete obstacles select them and press DELETE"
	
	reduced_visibility_button.visible = !reduced_visibility_button.visible
	robot_radius_slider.visible = !robot_radius_slider.visible
	#go_button.visible = !go_button.visible
	draw_button.visible = !draw_button.visible
	
	start_navigating.emit()
	
func _on_draw_button_pressed() -> void:
	draw_active = !draw_active
	if draw_active:
		draw_hint_1.text = "Left click to add point"
		draw_hint_2.visible = true
	else:
		draw_hint_1.text = "You can move anything while not in draw mode. To delete obstacles select them and press DELETE"
		draw_hint_2.visible = false
	if(draw_active):
		draw_button.modulate = Color(1.0, 0.0, 0.0)
	else:
		draw_button.modulate = Color(1.0, 1.0, 1.0)
	draw_button_pressed.emit(draw_active)

func _on_robot_radius_slider_value_changed(value: float) -> void:
	robot_radius_changed.emit(float(value))

func _on_restart_button_pressed() -> void:
	restart_requested.emit()

func _on_exit_button_pressed() -> void:
	exit_requested.emit()

#func _on_debug_collision_check_toggled(toggled_on: bool) -> void:
	#debug_collision_toggled.emit(toggled_on)
