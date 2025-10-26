extends Node2D

@onready var obstacles = get_tree().get_nodes_in_group("Obstacles")
@onready var robot: CharacterBody2D = %Robot
@onready var finish: Area2D = %Finish

# Function to find all vertices of obstacles
func extract_global_pos_of_vertices():
	var global_points: PackedVector2Array = []
	for obstacle in obstacles:
		if obstacle is StaticBody2D:
			var collision_of_obstacle = obstacle.find_child("CollisionPolygon2D")
			var local_points: PackedVector2Array = collision_of_obstacle.polygon
			for p in local_points:
				global_points.append(collision_of_obstacle.to_global(p))
	print(global_points)
	return global_points

func build_visibility_graph():
	var start_point: Vector2 = robot.global_position
	var end_point: Vector2 = finish.global_position
	var all_vertices: PackedVector2Array = extract_global_pos_of_vertices()
	all_vertices.append(start_point)
	all_vertices.append(end_point)
	print(all_vertices)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	call_deferred("build_visibility_graph")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# Pseudocod pentru versiunea optimizata:

#graph buildVisibilityGraph(Set<Segment> segments)
#	vertices = getVertices(segments) + start + finish
#	graph = visibilityGraph(verticies)
#	for Vertex v in vetices
#		for Vertex w in getVisibileVertices(v, segments)
#			visibilityGraph.addEdge(v,w)
#	return visibilityGraph

#Set<Vertex> getVisibileVertices(Vertex v, set<Segment> segments)
#	set<Vertex> answer
#	for Segment s in segments
#		if intersect(s, l)
#			status.add(s)
#	for Point w in segments
#		if v.x <= w.x
#			currentVertices.add(w)
#	sort(currentVertices) by angle
#	for Point w in currentVertices
#		if not intersect(vw, status.closest)
#			answer.add(w)
#		for Segment s edning in w
#			status.delete(s)
#		for Segment S beginning in w
#			status.add(s)
#	return answer
