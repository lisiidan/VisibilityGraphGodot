extends StaticBody2D

@onready var polygon_2d: Polygon2D = $Polygon2D
@onready var collision_polygon_2d: CollisionPolygon2D = $CollisionPolygon2D

@export var expand_distance: float = 5.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var original_poly := polygon_2d.polygon
	var expanded := Geometry2D.offset_polygon(original_poly, expand_distance)
	
	# offset_polygon() întoarce un Array de poligoane (de obicei 1)
	if expanded.size() > 0:
		collision_polygon_2d.polygon = expanded[0]
	else:
		# fallback dacă offset eșuează (ex. poligon prea mic)
		collision_polygon_2d.polygon = original_poly
	
	collision_polygon_2d.global_position = polygon_2d.global_position
