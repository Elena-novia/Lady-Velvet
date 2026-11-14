extends AnimatableBody2D
## Horizontal moving platform that carries CharacterBody2D passengers.

@export_range(0.0, 2000.0, 1.0) var horizontal_travel_distance: float = 260.0
@export_range(1.0, 1000.0, 1.0) var movement_speed: float = 100.0
@export var smooth_turning: bool = true
@export_range(1.0, 5000.0, 1.0) var turning_acceleration: float = 500.0
@export_enum("Left", "Right") var initial_direction: int = 1
@export var auto_direction_from_position: bool = false
@export_range(100.0, 3000.0, 25.0) var audio_hearing_distance: float = 900.0
@export_range(0.0, 2500.0, 25.0) var audio_full_volume_distance: float = 200.0
@export_range(0.1, 20.0, 0.1) var audio_fade_speed: float = 4.0
@export_range(-40.0, 0.0, 0.5) var ambience_volume_db: float = -12.0
@export_range(-40.0, 0.0, 0.5) var wing_volume_db: float = -16.0

var _origin_x: float
var _direction: float
var _horizontal_speed: float = 0.0
var _left_limit: float
var _right_limit: float
var _current_audio_gain: float = 0.0

@onready var _ambience_audio: AudioStreamPlayer2D = $AmbienceSFX
@onready var _wing_audio: AudioStreamPlayer2D = $WingSFX


func _ready() -> void:
	_setup_spatial_loop(_ambience_audio, ambience_volume_db)
	_setup_spatial_loop(_wing_audio, wing_volume_db)
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


func _setup_spatial_loop(player: AudioStreamPlayer2D, base_volume_db: float) -> void:
	if player == null or player.stream == null:
		return
	var loop_stream := player.stream as AudioStreamMP3
	if loop_stream != null:
		loop_stream.loop = true
	player.max_distance = audio_hearing_distance
	player.attenuation = 0.0
	player.volume_db = base_volume_db - 80.0
	if not player.playing:
		player.play()


func _process(delta: float) -> void:
	var target_gain := 0.0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var distance_to_player := global_position.distance_to(player.global_position)
		var hearing_distance := maxf(audio_hearing_distance, 1.0)
		var full_volume_distance := clampf(audio_full_volume_distance, 0.0, hearing_distance)
		if distance_to_player <= full_volume_distance:
			target_gain = 1.0
		elif distance_to_player < hearing_distance:
			var fade_progress := inverse_lerp(full_volume_distance, hearing_distance, distance_to_player)
			target_gain = 1.0 - smoothstep(0.0, 1.0, fade_progress)

	_current_audio_gain = move_toward(_current_audio_gain, target_gain, audio_fade_speed * delta)
	var gain_db := linear_to_db(maxf(_current_audio_gain, 0.0001))
	_ambience_audio.volume_db = ambience_volume_db + gain_db
	_wing_audio.volume_db = wing_volume_db + gain_db


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

