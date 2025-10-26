extends Node2D

signal path_ready(points: PackedVector2Array)

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
	
	# Collect obstacle vertices positions
	obstaclesVertices.clear()
	for obstacle in obstacles:
		if obstacle is StaticBody2D:
			var collision_of_obstacle: CollisionPolygon2D = obstacle.find_child("CollisionPolygon2D")
			if collision_of_obstacle == null: continue
			var polygonVertices := PackedVector2Array()
			for vertex in collision_of_obstacle.polygon:
				#print("Append vertex: " + str(vertex))
				polygonVertices.append(collision_of_obstacle.to_global(vertex))
			obstaclesVertices.append(polygonVertices)
	
	# Add all nodes to visibilityGraph
	for i in allVertices.size():
		visibilityGraph.add_point(i,allVertices[i])
		verticesIdxInGraph[allVertices[i]] = i
	
	# ▶ fill debug vertices (convert to local for drawing)
	_dbg_vertices.clear()
	for v in allVertices:
		_dbg_vertices.append(to_local(v))

	# ▶ clear edges cache
	_dbg_edges.clear()
	
	# connect only visible pairs
	for i in allVertices.size():
		for j in range(i + 1, allVertices.size()):
			var a := allVertices[i]
			var b := allVertices[j]
			if not segment_intersect_obstacles(a, b):
				var weight := a.distance_to(b)
				visibilityGraph.connect_points(i,j,weight)
				# ▶ store edge for drawing (as local coords)
				_dbg_edges.append(to_local(a))
				_dbg_edges.append(to_local(b))
	
	print("path from :" + str(start_point) + " to " + str(end_point) + " is: ")
	var path = visibilityGraph.get_point_path(verticesIdxInGraph[start_point], verticesIdxInGraph[end_point])
	# ▶ store path for drawing (convert to local coords)
	_dbg_path.clear()
	for p in path:
		_dbg_path.append(to_local(p))

	# ▶ redraw
	queue_redraw()
	print(path)
	
	# ▶ redraw debug graphics
	queue_redraw()
	
	return path

func segment_intersect_obstacles(a: Vector2, b: Vector2) -> bool:
	for poly in obstaclesVertices:
		var n := poly.size()

		# --- 1️⃣ reject internal diagonals ---
		var ia := _find_vertex_index(poly, a, EPS)
		var ib := _find_vertex_index(poly, b, EPS)
		if ia != -1 and ib != -1 and not _are_adjacent(n, ia, ib):
			var mid := (a + b) * 0.5
			if _point_inside_polygon_tolerant(mid, poly):
				# If the midpoint is deep inside, block it
				if not _is_point_on_polygon_border(mid, poly):
					return true

		# --- 2️⃣ check each polygon edge for intersection ---
		for k in n:
			var c := poly[k]
			var d := poly[(k + 1) % n]

			# skip shared endpoints
			if a.distance_to(c) < EPS or a.distance_to(d) < EPS or b.distance_to(c) < EPS or b.distance_to(d) < EPS:
				continue

			# check intersection
			if Geometry2D.segment_intersects_segment(a, b, c, d):
				# --- 3️⃣ if colinear with the edge, allow (move along border) ---
				if _segments_are_colinear(a, b, c, d):
					continue
				return true

	# --- 4️⃣ last safety: both endpoints outside polygons (no through walls) ---
	var mid := (a + b) * 0.5
	for poly in obstaclesVertices:
		if _point_inside_polygon_tolerant(mid, poly):
			# If the midpoint is deep inside, block it
			if not _is_point_on_polygon_border(mid, poly):
				return true


	return false




func segment_intersect_except_endpoints(a,b,c,d):
	# if some of the points are the same point there it's irrelevant
	if a.distance_to(c) < EPS or a.distance_to(d) < EPS or b.distance_to(c) < EPS or b.distance_to(d) < EPS:
		return false
	return Geometry2D.segment_intersects_segment(a,b,c,d)
	
func build_path_and_emit_signal():
	var path = build_visibility_graph()
	emit_signal("path_ready", path)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	call_deferred("build_path_and_emit_signal")
	
# ▶ draw 10x10 squares at vertices + graph edges
func _draw() -> void:
	# draw vertices as 10x10 squares
	for v in _dbg_vertices:
		draw_rect(Rect2(v - Vector2(5, 5), Vector2(10, 10)), Color(0.2, 0.9, 0.4, 0.9), true)

	# draw edges in gray
	for i in range(0, _dbg_edges.size(), 2):
		draw_line(_dbg_edges[i], _dbg_edges[i + 1], Color(0.6, 0.6, 0.6), 1.0)

	# ▶ draw final path in bold yellow
	if _dbg_path.size() >= 2:
		draw_polyline(_dbg_path, Color.YELLOW, 4.0)


func _find_vertex_index(poly: PackedVector2Array, p: Vector2, eps: float) -> int:
	for i in poly.size():
		if p.distance_to(poly[i]) < eps:
			return i
	return -1

func _are_adjacent_indices(n: int, i: int, j: int) -> bool:
	if i == j:
		return true
	return (abs(i - j) == 1) or ((i == 0 and j == n - 1) or (j == 0 and i == n - 1))

# More robust "midpoint inside" test (nudge off segment to avoid boundary ambiguity)
func _midpoint_inside(poly: PackedVector2Array, a: Vector2, b: Vector2) -> bool:
	var mid := (a + b) * 0.5
	# Try mid, and a tiny perpendicular nudge in case mid lies exactly on boundary
	var d := (b - a)
	if d.length() == 0.0:
		return false
	var n := Vector2(-d.y, d.x).normalized() * 1e-3
	return Geometry2D.is_point_in_polygon(mid, poly) \
		or Geometry2D.is_point_in_polygon(mid + n, poly) \
		or Geometry2D.is_point_in_polygon(mid - n, poly)

func _are_adjacent(n: int, i: int, j: int) -> bool:
	return i != -1 and j != -1 and (abs(i - j) == 1 or (i == 0 and j == n - 1) or (j == 0 and i == n - 1))

func _orientation(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

func _on_segment(a: Vector2, b: Vector2, p: Vector2) -> bool:
	# p colinear with a-b and within the bounding box
	if absf(_orientation(a, b, p)) > 1e-7: return false
	return p.x >= min(a.x, b.x) - 1e-7 and p.x <= max(a.x, b.x) + 1e-7 \
		and p.y >= min(a.y, b.y) - 1e-7 and p.y <= max(a.y, b.y) + 1e-7

func _segments_overlap_colinear(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	# a-b and c-d colinear and the projections overlap
	if absf(_orientation(a, b, c)) > 1e-7 or absf(_orientation(a, b, d)) > 1e-7:
		return false
	return _on_segment(a, b, c) or _on_segment(a, b, d) or _on_segment(c, d, a) or _on_segment(c, d, b)

func _point_inside_tolerant(poly: PackedVector2Array, p: Vector2) -> bool:
	# test p and tiny nudges to avoid boundary ambiguity
	if Geometry2D.is_point_in_polygon(p, poly): return true
	var nudge := Vector2(1e-3, 0)
	return Geometry2D.is_point_in_polygon(p + nudge, poly) \
		or Geometry2D.is_point_in_polygon(p - nudge, poly) \
		or Geometry2D.is_point_in_polygon(p + nudge.rotated(1.5707963), poly) \
		or Geometry2D.is_point_in_polygon(p - nudge.rotated(1.5707963), poly)

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
