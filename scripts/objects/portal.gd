extends Area2D

enum PortalType { START, EXIT }

@export var portal_type: PortalType = PortalType.START
@export var spawn_position_offset: Vector2 = Vector2.ZERO
@export var intro_direction: Vector2 = Vector2.RIGHT
@export_range(0.0, 300.0, 1.0) var intro_step_distance: float = 106.0
@export_range(0, 4, 1) var intro_step_count: int = 2

var has_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if portal_type == PortalType.START:
		monitoring = false
		call_deferred("_begin_player_intro")
	else:
		monitoring = true


func _begin_player_intro() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var spawn_point := get_node_or_null("SpawnPoint") as Marker2D
	if player == null or spawn_point == null or not player.has_method("begin_start_sequence"):
		return
	player.begin_start_sequence(
		spawn_point.to_global(spawn_position_offset),
		intro_direction,
		intro_step_distance,
		intro_step_count
	)


func _on_body_entered(body: Node2D) -> void:
	if portal_type != PortalType.EXIT or has_triggered or not body.is_in_group("player"):
		return
	has_triggered = true
	var end_screen := get_tree().get_first_node_in_group("end_screen")
	if end_screen != null and end_screen.has_method("finish_game"):
		end_screen.finish_game(body)
	elif body.has_method("lock_controls"):
		body.lock_controls()
