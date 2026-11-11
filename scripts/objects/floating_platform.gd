extends AnimatableBody2D
## Horizontal moving platform that carries CharacterBody2D passengers.

@export_range(0.0, 2000.0, 1.0) var horizontal_travel_distance: float = 260.0
@export_range(1.0, 1000.0, 1.0) var movement_speed: float = 100.0
@export var smooth_turning: bool = true
@export_range(1.0, 5000.0, 1.0) var turning_acceleration: float = 500.0
@export_enum("Left", "Right") var initial_direction: int = 1
@export var auto_direction_from_position: bool = false

var _origin_x: float
var _direction: float
var _horizontal_speed: float = 0.0
var _left_limit: float
var _right_limit: float


func _ready() -> void:
	_origin_x = global_position.x
	if auto_direction_from_position:
		var midpoint_x := _get_level_route_midpoint_x()
		if _origin_x > midpoint_x:
			_direction = -1.0
			_left_limit = _origin_x - horizontal_travel_distance
			_right_limit = _origin_x
		else:
			_direction = 1.0
			_left_limit = _origin_x
			_right_limit = _origin_x + horizontal_travel_distance
	else:
		_direction = 1.0 if initial_direction == 1 else -1.0
		_left_limit = _origin_x - horizontal_travel_distance * 0.5
		_right_limit = _origin_x + horizontal_travel_distance * 0.5


func _get_level_route_midpoint_x() -> float:
	var level := get_tree().current_scene
	if level != null:
		var start_portal := level.get_node_or_null("StartPortal") as Node2D
		var exit_portal := level.get_node_or_null("ExitPortal") as Node2D
		if start_portal != null and exit_portal != null:
			return (start_portal.global_position.x + exit_portal.global_position.x) * 0.5
	return 0.0


func _physics_process(delta: float) -> void:
	if horizontal_travel_distance <= 0.0:
		return

	var remaining := _right_limit - global_position.x if _direction > 0.0 else global_position.x - _left_limit
	if remaining <= 0.5:
		_direction *= -1.0
		remaining = horizontal_travel_distance

	var target_speed := movement_speed
	if smooth_turning:
		# Brake toward each endpoint so direction changes do not snap.
		target_speed = minf(movement_speed, sqrt(2.0 * turning_acceleration * maxf(remaining, 0.0)))
	_horizontal_speed = move_toward(_horizontal_speed, target_speed, turning_acceleration * delta)
	var step := minf(_horizontal_speed * delta, remaining)
	global_position.x += _direction * step
	if step >= remaining - 0.001:
		global_position.x = _right_limit if _direction > 0.0 else _left_limit
		_direction *= -1.0

