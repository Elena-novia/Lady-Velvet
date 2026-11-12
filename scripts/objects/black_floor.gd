@tool
extends StaticBody2D

@export var dimensions: Vector2 = Vector2(800.0, 64.0):
	set(value):
		dimensions = Vector2(maxf(1.0, value.x), maxf(1.0, value.y))
		_sync_geometry()


func _ready() -> void:
	_sync_geometry()


func _sync_geometry() -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual != null:
		var half_size := dimensions * 0.5
		visual.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		])
		visual.color = Color("#161320")

	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		var rectangle := collision.shape as RectangleShape2D
		if rectangle != null:
			rectangle.size = dimensions
