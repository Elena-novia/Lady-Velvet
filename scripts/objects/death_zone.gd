@tool
extends Area2D

@export var dimensions: Vector2 = Vector2(300.0, 180.0):
	set(value):
		dimensions = Vector2(maxf(1.0, value.x), maxf(1.0, value.y))
		_sync_geometry()
		if Engine.is_editor_hint():
			queue_redraw()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_sync_geometry()
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var preview_rect := Rect2(-dimensions * 0.5, dimensions)
	draw_rect(preview_rect, Color(1.0, 0.12, 0.12, 0.12), true)
	draw_rect(preview_rect, Color(1.0, 0.2, 0.2, 0.9), false, 2.0)
	draw_line(Vector2(-dimensions.x * 0.5, 0.0), Vector2(dimensions.x * 0.5, 0.0), Color(1.0, 0.2, 0.2, 0.75), 1.0)


func _sync_geometry() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		var rectangle := collision.shape as RectangleShape2D
		if rectangle != null:
			rectangle.size = dimensions


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("die"):
		body.call("die")
