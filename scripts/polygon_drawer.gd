extends Node2D

signal new_obstacle_added(new_obstacle: Node)

@export var obstacle_scene: PackedScene 
@onready var obstacles_parent: Node = %Obstacles   # parent node for obstacles
@onready var preview_line: Line2D = $PreviewLine
#@onready var preview_point: Polygon2D = $Polygon
@onready var drawing_area_collision: CollisionShape2D = $DrawingArea/CollisionShape2D

var drawing := false
var drawing_allowed := false
var points: PackedVector2Array = []

func toggle_drawing_allowed(new_state: bool) -> void:
	drawing_allowed = new_state
	points.clear()
	preview_line.clear_points()
	preview_line.visible = new_state
	Global.drawing_allowed = new_state

func _unhandled_input(event: InputEvent) -> void:
	if not drawing_allowed:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not drawing:
				drawing = true
				points.clear()
			#points.append(get_global_mouse_position())
			try_add_point(get_global_mouse_position())
			preview_line.points = points
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and drawing:
			# Finish polygon on right click
			finalize_polygon()
			drawing = false

	elif event is InputEventMouseMotion and drawing:
		# update last preview segment
		var temp_points = points.duplicate()
		var mouse_pos := get_global_mouse_position()
		if(point_in_drawing_area(mouse_pos)): # CHANGE HERE=========================================
			temp_points.append(mouse_pos)
		preview_line.points = temp_points

func finalize_polygon() -> void:
	if points.size() < 3:
		preview_line.clear_points()
		return

	var obstacle: Node2D = obstacle_scene.instantiate()
	var poly2d: Polygon2D = obstacle.get_node("Polygon2D")
	var colpoly: CollisionPolygon2D = obstacle.get_node("CollisionPolygon2D")

	# make sure inner nodes start from (0, 0)
	poly2d.position = Vector2.ZERO
	colpoly.position = Vector2.ZERO

	# anchor obstacle at first point
	var origin := points[0]
	obstacle.global_position = origin

	# convert all global points to obstacle-local coordinates
	var local_points: PackedVector2Array = []
	for p in points:
		local_points.append(p - origin)

	poly2d.polygon = local_points
	colpoly.polygon = local_points

	# add to parent and group
	obstacles_parent.add_child(obstacle)
	obstacle.add_to_group("Obstacles")
	new_obstacle_added.emit(obstacle)

	points.clear()
	preview_line.clear_points()

# Call this when LEFT-click adds a new point `p_new`
func try_add_point(p_new: Vector2) -> void:
	if(not point_in_drawing_area(p_new)): #CHANGE HERE =======================================================
		return
	if points.size() >= 2:
		var a := points[points.size() - 1]
		var b := p_new
		# Check new edge (a,b) against all non-adjacent previous edges
		for i in range(points.size() - 2):
			var c := points[i]
			var d := points[i + 1]
			if Geometry2D.segment_intersects_segment(a, b, c, d):
				#_flash_invalid_segment(a, b)  # optional UX
				return  # reject this point
	points.append(p_new)
	preview_line.points = points

#func point_in_drawing_area(point: Vector2) -> bool:
	#return drawing_area.has_point(point)
func point_in_drawing_area(point: Vector2) -> bool:
	var local_point = drawing_area_collision.to_local(point)
	
	return drawing_area_collision.shape.get_rect().has_point(local_point)
# TO DO:
#
# 1) de adaugat conditie de invaliditate poligon: daca se trece pe el insusi - DONE
# 2) daca poligon invalid (points < 3) liniile raman, nu ar trebui - DONE
# 3) pathfinder-ul trebuie anuntat cand un obstacol e adaugat - DONE
# 4) optional: de adaugat buton de drawing - DONE
# 5) de adaugat posibilitate de mutat robotul si finisul (optional: de le adaugat tot cu buton)
# 6) de asigurat ca robotul nu poate fi pus in obstacol si obstacolul in robot (simplu de pornit coliziunea?)
# 7) optional: import harta din .csv
# 8) width la previewLine trebuie micsorat - DONE
# 9) optional: interfata mai frumoasa
