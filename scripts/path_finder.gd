extends Node2D

signal path_ready(points: PackedVector2Array)

@export_enum("Full","Reduced") var graph_mode := 0

@onready var obstacles = get_tree().get_nodes_in_group("Obstacles")
@onready var robot: CharacterBody2D = %Robot
@onready var finish: Area2D = %Finish
var visibilityGraph := AStar2D.new()
var verticesIdxInGraph: Dictionary = {}
# Array which contains arrays of vertices of obstacles
var obstaclesVertices: Array[PackedVector2Array] = []
# debug caches for drawing
var _dbg_vertices: PackedVector2Array = []
var _dbg_edges: Array[Vector2] = []  # flat: [a0,b0,a1,b1,...] in *local* coords
var _dbg_path: PackedVector2Array = []  # will store the current shortest path
const EPS := 1e-4

# Function to find all vertices of obstacles
func extract_global_pos_of_vertices():
	var global_points: PackedVector2Array = []
	for obstacle in obstacles:
		if obstacle is StaticBody2D:
			var collision_of_obstacle = obstacle.find_child("CollisionPolygon2D")
			if collision_of_obstacle == null:
				continue
			var local_points: PackedVector2Array = collision_of_obstacle.polygon
			for p in local_points:
				global_points.append(collision_of_obstacle.to_global(p))
	return global_points

func build_visibility_graph():
	visibilityGraph = AStar2D.new()
	verticesIdxInGraph.clear()
	
	var allVertices: PackedVector2Array = extract_global_pos_of_vertices()
	var start_point: Vector2 = robot.global_position
	var end_point: Vector2 = finish.global_position
	allVertices.append(start_point)
	allVertices.append(end_point)
	
	obstaclesVertices.clear()
	for obstacle in obstacles:
		if obstacle is StaticBody2D:
			var collision_of_obstacle: CollisionPolygon2D = obstacle.find_child("CollisionPolygon2D")
			if collision_of_obstacle == null: continue
			var polygonVertices := PackedVector2Array()
			for vertex in collision_of_obstacle.polygon:
				polygonVertices.append(collision_of_obstacle.to_global(vertex))
			obstaclesVertices.append(polygonVertices)
	
	# Add all nodes to visibilityGraph
	for i in allVertices.size():
		visibilityGraph.add_point(i,allVertices[i])
		verticesIdxInGraph[allVertices[i]] = i
	
	# fill debug vertices (convert to local for drawing)
	_dbg_vertices.clear()
	for v in allVertices:
		_dbg_vertices.append(to_local(v))

	# clear edges cache
	_dbg_edges.clear()
	
	# connect only visible pairs
	for i in allVertices.size():
		for j in range(i + 1, allVertices.size()):
			var a := allVertices[i]
			var b := allVertices[j]
			if not segment_intersect_obstacles(a, b):
				var weight := a.distance_to(b)
				visibilityGraph.connect_points(i,j,weight)
				# store edge for drawing (as local coords)
				_dbg_edges.append(to_local(a))
				_dbg_edges.append(to_local(b))
	
	var path = visibilityGraph.get_point_path(verticesIdxInGraph[start_point], verticesIdxInGraph[end_point])
	# store path for drawing (convert to local coords)
	_dbg_path.clear()
	for p in path:
		_dbg_path.append(to_local(p))
	queue_redraw()
	return path

func segment_intersect_obstacles(a: Vector2, b: Vector2) -> bool:
	for poly in obstaclesVertices:
		var n := poly.size()
		# --- reject internal diagonals ---
		var ia := _find_vertex_index(poly, a, EPS)
		var ib := _find_vertex_index(poly, b, EPS)
		if ia != -1 and ib != -1 and not _are_adjacent(n, ia, ib):
			var mid := (a + b) * 0.5
			if _point_inside_polygon_tolerant(mid, poly):
				# If the midpoint is deep inside, block it
				if not _is_point_on_polygon_border(mid, poly):
					return true

		# --- check each polygon edge for intersection ---
		for k in n:
			var c := poly[k]
			var d := poly[(k + 1) % n]

			# skip shared endpoints
			if a.distance_to(c) < EPS or a.distance_to(d) < EPS or b.distance_to(c) < EPS or b.distance_to(d) < EPS:
				continue

			# check intersection
			if Geometry2D.segment_intersects_segment(a, b, c, d):
				# ---  if colinear with the edge, allow (move along border) ---
				if _segments_are_colinear(a, b, c, d):
					continue
				return true

	# ---  last safety: both endpoints outside polygons (no through walls) ---
	var mid := (a + b) * 0.5
	for poly in obstaclesVertices:
		if _point_inside_polygon_tolerant(mid, poly):
			# If the midpoint is deep inside, block it
			if not _is_point_on_polygon_border(mid, poly):
				return true
	return false

func build_path_and_emit_signal():
	var path: PackedVector2Array
	if graph_mode == 0:
		path = build_visibility_graph()
	else:
		path = build_reduced_visibility_graph()
	emit_signal("path_ready", path)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	call_deferred("build_path_and_emit_signal")
	
# draw 10x10 squares at vertices + graph edges
func _draw() -> void:
	# draw vertices as 10x10 squares
	for v in _dbg_vertices:
		draw_rect(Rect2(v - Vector2(5, 5), Vector2(10, 10)), Color(0.2, 0.9, 0.4, 0.9), true)

	# draw edges in gray
	for i in range(0, _dbg_edges.size(), 2):
		draw_line(_dbg_edges[i], _dbg_edges[i + 1], Color(0.6, 0.6, 0.6), 1.0)

	# draw final path in bold yellow
	if _dbg_path.size() >= 2:
		draw_polyline(_dbg_path, Color.YELLOW, 4.0)

func _find_vertex_index(poly: PackedVector2Array, p: Vector2, eps: float) -> int:
	for i in poly.size():
		if p.distance_to(poly[i]) < eps:
			return i
	return -1

func _are_adjacent(n: int, i: int, j: int) -> bool:
	return i != -1 and j != -1 and (abs(i - j) == 1 or (i == 0 and j == n - 1) or (j == 0 and i == n - 1))

func _orientation(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

func _segments_are_colinear(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var v1 := (b - a).normalized()
	var v2 := (d - c).normalized()
	return absf(v1.dot(v2)) > 0.9999 and absf(_orientation(a, b, c)) < 1e-6
	
func _point_inside_polygon_tolerant(p: Vector2, poly: PackedVector2Array, eps := 0.001) -> bool:
	# Treats points on edges as OUTSIDE
	if Geometry2D.is_point_in_polygon(p, poly):
		return true
	# If it's extremely close to an edge, treat as outside (allowed)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if _distance_point_to_segment(p, a, b) < eps:
			return false  # close enough to edge, not really inside
	return false
	
func _is_point_on_polygon_border(p: Vector2, poly: PackedVector2Array, eps := 0.001) -> bool:
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if _distance_point_to_segment(p, a, b) < eps:
			return true
	return false
	
func _distance_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	# Compute the shortest distance from point p to segment ab
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 0.0:
		t = clamp((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var closest := a + ab * t
	return p.distance_to(closest)


# ================================= REDUCED GRAPH BUILDER AND HELPERS ===============================
func build_reduced_visibility_graph() -> PackedVector2Array:
	visibilityGraph = AStar2D.new()
	verticesIdxInGraph.clear()
	
	obstaclesVertices.clear()
	for obstacle in obstacles:
		if obstacle is StaticBody2D:
			var cpo: CollisionPolygon2D = obstacle.find_child("CollisionPolygon2D")
			if cpo == null: continue
			var poly := PackedVector2Array()
			for vtx in cpo.polygon:
				poly.append(cpo.to_global(vtx))
			obstaclesVertices.append(_ensure_ccw(poly))
	
	var allVertices: PackedVector2Array = []
	for poly in obstaclesVertices:
		for p in poly:
			allVertices.append(p)
	
	var start_point: Vector2 = robot.global_position
	var end_point: Vector2 = finish.global_position
	var start_id := allVertices.size()
	allVertices.append(start_point)
	var goal_id := allVertices.size()
	allVertices.append(end_point)
	
	# 3) adaugă noduri în AStar2D
	for i in allVertices.size():
		visibilityGraph.add_point(i, allVertices[i])
	
	# 4) debug caches
	_dbg_vertices.clear()
	for v in allVertices: _dbg_vertices.append(to_local(v))
	_dbg_edges.clear()
	
	for i in allVertices.size():
		for j in range(i + 1, allVertices.size()):
			var a := allVertices[i]
			var b := allVertices[j]
			if a.distance_to(b) < EPS:
				continue
			if segment_intersect_obstacles(a, b):
				continue
			
			var la := _vertex_location(a)
			var lb := _vertex_location(b)
			
			var ok_a := true
			var ok_b := true
			if la["poly"] != null:
				ok_a = _is_tangent_at_vertex(a, b, la["poly"], la["idx"])
			if lb["poly"] != null:
				ok_b = _is_tangent_at_vertex(b, a, lb["poly"], lb["idx"])
			if (not (ok_a and ok_b)):
				continue
			
			visibilityGraph.connect_points(i, j, true)  # bidirectional
			_dbg_edges.append(to_local(a))
			_dbg_edges.append(to_local(b))

	# 6) cale + debug path
	var path := visibilityGraph.get_point_path(start_id, goal_id)
	_dbg_path.clear()
	for p in path: _dbg_path.append(to_local(p))
	queue_redraw()
	return path

func _neighbors(poly: PackedVector2Array, i: int) -> Dictionary:
	var n := poly.size()
	return {"prev": poly[(i - 1 + n) % n], "next": poly[(i + 1) % n]}

func _signed_area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i+1)%poly.size()]
		s += p.x*q.y - p.y*q.x
	return 0.5*s

func _ensure_ccw(poly: PackedVector2Array) -> PackedVector2Array:
	if _signed_area(poly) < 0.0:
		poly.reverse()
	return poly

func _is_tangent_at_vertex(v: Vector2, u: Vector2, poly: PackedVector2Array, i: int, eps := 1e-9) -> bool:
	var nn = _neighbors(poly, i)
	var s1 := _orientation(v, u, nn["prev"])
	var s2 := _orientation(v, u, nn["next"])
	if absf(s1) <= eps and absf(s2) <= eps:
		return true
	return s1 * s2 >= -eps

func _vertex_location(p: Vector2) -> Dictionary:
	for poly in obstaclesVertices:
		var i := _find_vertex_index(poly, p, EPS)
		if i != -1:
			return {"poly": poly, "idx": i}
	return {"poly": null, "idx": -1}

# ========================= UI interactions ===================================

func on_reduced_visibility_button_toggled(toggled_on: bool) -> void:
	if(toggled_on):
		graph_mode = 1
	else:
		graph_mode = 0
	call_deferred("build_path_and_emit_signal")


func on_start_navigating_button_pressed() -> void:
	call_deferred("build_path_and_emit_signal")

func on_robot_radius_slider_value_changed(value: float) -> void:
	robot.robot_radius = value
	call_deferred("build_path_and_emit_signal")
