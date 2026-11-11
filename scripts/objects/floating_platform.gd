extends AnimatableBody2D
## Horizontal moving platform that carries CharacterBody2D passengers.

@export_range(0.0, 2000.0, 1.0) var horizontal_travel_distance: float = 260.0
@export_range(1.0, 1000.0, 1.0) var movement_speed: float = 100.0
@export var smooth_turning: bool = true
@export_range(1.0, 5000.0, 1.0) var turning_acceleration: float = 500.0
@export_enum("Left", "Right") var initial_direction: int = 1

var _origin_x: float
var _direction: float
var _horizontal_speed: float = 0.0


func _ready() -> void:
	_origin_x = global_position.x
	_direction = 1.0 if initial_direction == 1 else -1.0


func _physics_process(delta: float) -> void:
	if horizontal_travel_distance <= 0.0:
		return

	var left_limit := _origin_x - horizontal_travel_distance * 0.5
	var right_limit := _origin_x + horizontal_travel_distance * 0.5
	var remaining := right_limit - global_position.x if _direction > 0.0 else global_position.x - left_limit
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
		global_position.x = right_limit if _direction > 0.0 else left_limit
		_direction *= -1.0

