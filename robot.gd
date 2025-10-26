# Robot.gd (pe nodul robot, ex. CharacterBody2D/Node2D)
extends CharacterBody2D

@export var speed: float = 120.0

func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed
	
func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()
