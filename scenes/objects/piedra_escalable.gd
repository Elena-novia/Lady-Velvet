@tool
extends Node2D

const STONE_WIDTH := 753.0
const STONE_HEIGHT := 1122.0
const STONE_LEFT := -376.5
const STONE_RIGHT := 376.5
const STONE_TOP := -1122.0
const STONE_BOTTOM := 0.0
const VISUAL_Y_OFFSET := -556.5

@export var climb_enabled: bool = true:
	set(value):
		climb_enabled = value
		_update_configuration()

@export_range(0.0, 500.0, 1.0) var interaction_margin: float = 120.0:
	set(value):
		interaction_margin = maxf(0.0, value)
		_update_configuration()

@export_range(0.0, 500.0, 1.0) var top_non_climbable_margin: float = 40.0:
	set(value):
		top_non_climbable_margin = maxf(0.0, value)
		_update_configuration()

@export_range(0.0, 500.0, 1.0) var bottom_non_climbable_margin: float = 40.0:
	set(value):
		bottom_non_climbable_margin = maxf(0.0, value)
		_update_configuration()

@export_range(1.0, 500.0, 1.0) var climb_speed: float = 100.0
@export_range(0.0, 250.0, 1.0) var top_clearance: float = 0.0:
	set(value):
		top_clearance = maxf(0.0, value)
		_update_configuration()

@export_range(0.0, 40.0, 0.5) var side_clearance: float = 3.0:
	set(value):
		side_clearance = maxf(0.0, value)
		_update_configuration()

@export_range(1.0, 128.0, 1.0) var player_half_width: float = 28.0:
	set(value):
		player_half_width = maxf(1.0, value)
		_update_configuration()

@export_range(1.0, 160.0, 1.0) var player_half_height: float = 64.0:
	set(value):
		player_half_height = maxf(1.0, value)
		_update_configuration()


func _enter_tree() -> void:
	set_notify_transform(true)


func _ready() -> void:
	_update_configuration()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_configuration()


func get_climb_speed() -> float:
	return climb_speed


func can_player_climb_from(world_position: Vector2, area: Area2D) -> bool:
	if not climb_enabled or area == null:
		return false
	var x_scale := global_transform.x.length()
	var y_scale := global_transform.y.length()
	if is_zero_approx(x_scale) or is_zero_approx(y_scale):
		return false
	var top_margin := top_non_climbable_margin
	var bottom_margin := bottom_non_climbable_margin
	var local_position := to_local(world_position)
	var climb_top := STONE_TOP + top_margin - top_clearance / y_scale
	var climb_bottom := STONE_BOTTOM - bottom_margin
	if local_position.y < climb_top or local_position.y > climb_bottom:
		return false
	if area.name == "InteractionAreaLeft":
		return local_position.x < 0.0
	if area.name == "InteractionAreaRight":
		return local_position.x > 0.0
	return false


func get_climb_anchor_for_area(area: Area2D) -> Marker2D:
	if area != null and area.name == "InteractionAreaLeft":
		return get_node_or_null("LeftClimbAnchor") as Marker2D
	if area != null and area.name == "InteractionAreaRight":
		return get_node_or_null("RightClimbAnchor") as Marker2D
	return null


func _get_stone_outline() -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(-376.5, -1122.0),
			Vector2(376.5, -1122.0),
			Vector2(376.5, -47.0),
			Vector2(376.5, -5.0),
			Vector2(369.5, 0.0),
			Vector2(-367.5, 0.0),
			Vector2(-367.5, -5.0),
			Vector2(-374.5, -327.0),
		]
	)


func _update_configuration() -> void:
	var visual := get_node_or_null("Visual") as Sprite2D
	if visual != null:
		visual.position = Vector2(0.0, VISUAL_Y_OFFSET)

	var collision := get_node_or_null("Body/CollisionPolygon2D") as CollisionPolygon2D
	if collision != null:
		collision.polygon = _get_stone_outline()

	var left_anchor := get_node_or_null("LeftClimbAnchor") as Marker2D
	var right_anchor := get_node_or_null("RightClimbAnchor") as Marker2D
	var top_anchor := get_node_or_null("TopAnchor") as Marker2D
	var bottom_anchor := get_node_or_null("BottomAnchor") as Marker2D
	var x_scale := global_transform.x.length()
	var y_scale := global_transform.y.length()
	if is_zero_approx(x_scale) or is_zero_approx(y_scale):
		return

	var x_axis := global_transform.x / x_scale
	var y_axis := global_transform.y / y_scale
	var half_width_world := absf(x_axis.x) * player_half_width + absf(x_axis.y) * player_half_height
	var half_height_world := absf(y_axis.x) * player_half_width + absf(y_axis.y) * player_half_height
	var half_width_local := (half_width_world + side_clearance) / x_scale
	var half_height_local := half_height_world / y_scale
	var top_margin := maxf(top_non_climbable_margin, half_height_local + 2.0)
	var bottom_margin := maxf(bottom_non_climbable_margin, half_height_local + 2.0)
	var side_top := STONE_TOP + top_margin
	var side_bottom := STONE_BOTTOM - bottom_margin
	var side_height := side_bottom - side_top
	var left_area := get_node_or_null("InteractionAreaLeft") as Area2D
	var right_area := get_node_or_null("InteractionAreaRight") as Area2D
	var left_polygon := get_node_or_null("InteractionAreaLeft/CollisionPolygon2D") as CollisionPolygon2D
	var right_polygon := get_node_or_null("InteractionAreaRight/CollisionPolygon2D") as CollisionPolygon2D
	var areas_enabled := climb_enabled and side_height > 0.0
	var left_top := _left_edge_at_y(side_top)
	var left_bottom := _left_edge_at_y(side_bottom)
	var right_top := _right_edge_at_y(side_top)
	var right_bottom := _right_edge_at_y(side_bottom)
	var sensor_overlap := 8.0
	var sensor_reach := interaction_margin
	var left_origin := Vector2(STONE_LEFT + 24.0, (side_top + side_bottom) * 0.5)
	var right_origin := Vector2(STONE_RIGHT - 24.0, (side_top + side_bottom) * 0.5)
	if left_area != null:
		left_area.position = left_origin
		left_area.monitoring = areas_enabled
		left_area.monitorable = areas_enabled
	if right_area != null:
		right_area.position = right_origin
		right_area.monitoring = areas_enabled
		right_area.monitorable = areas_enabled
	if left_polygon != null:
		left_polygon.polygon = _offset_polygon(PackedVector2Array([
			Vector2(left_top + sensor_overlap, side_top),
			Vector2(left_top - sensor_reach, side_top),
			Vector2(left_bottom - sensor_reach, side_bottom),
			Vector2(left_bottom + sensor_overlap, side_bottom),
		]), left_origin)
	if right_polygon != null:
		right_polygon.polygon = _offset_polygon(PackedVector2Array([
			Vector2(right_top - sensor_overlap, side_top),
			Vector2(right_top + sensor_reach, side_top),
			Vector2(right_bottom + sensor_reach, side_bottom),
			Vector2(right_bottom - sensor_overlap, side_bottom),
		]), right_origin)

	if left_anchor != null:
		left_anchor.position = Vector2(STONE_LEFT - half_width_local, 0.0)
	if right_anchor != null:
		right_anchor.position = Vector2(STONE_RIGHT + half_width_local, 0.0)
	if top_anchor != null:
		top_anchor.position = Vector2(
			0.0,
			STONE_TOP + top_margin - half_height_local - top_clearance / y_scale
		)
	if bottom_anchor != null:
		bottom_anchor.position = Vector2(0.0, STONE_BOTTOM - bottom_margin + half_height_local)


func _left_edge_at_y(y: float) -> float:
	if y <= -327.0:
		return lerpf(STONE_LEFT, -374.5, inverse_lerp(STONE_TOP, -327.0, y))
	return lerpf(-374.5, -367.5, inverse_lerp(-327.0, -5.0, y))


func _right_edge_at_y(y: float) -> float:
	if y <= -47.0:
		return STONE_RIGHT
	return lerpf(STONE_RIGHT, 369.5, inverse_lerp(-47.0, STONE_BOTTOM, y))


func _offset_polygon(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point - offset)
	return result
