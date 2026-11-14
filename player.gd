extends CharacterBody2D

enum PlayerState { IDLE, WALK, JUMP, FALL, LAND, CLIMB, CLIMB_JUMP }

@export var speed: float = 320.0
@export var jump_velocity: float = -600.0
@export var climb_speed: float = 100.0
@export var climb_jump_horizontal_impulse: float = 420.0
@export var climb_jump_vertical_impulse: float = 460.0
@export var ascent_gravity: float = 900.0
@export var descent_gravity: float = 1150.0
@export var jump_hold_duration: float = 0.1
@export_range(0.0, 1.0, 0.05) var jump_hold_gravity_scale: float = 0.55
@export var air_acceleration: float = 1800.0
@export var air_deceleration: float = 300.0
@export var air_braking: float = 2200.0
@export var max_air_horizontal_speed: float = 440.0
@export_range(0.0, 2.0, 0.05) var climb_jump_air_control: float = 1.0
@export_range(0.0, 10.0, 0.1) var respawn_delay: float = 2.0
@export_range(0.2, 2.0, 0.05) var death_effect_duration: float = 0.9
@export_range(0.0, 1.0, 0.05) var death_tint_intensity: float = 0.85
@export_range(0.0, 1.0, 0.05) var death_deformation_intensity: float = 0.75
@export_range(0.2, 2.0, 0.05) var death_particle_duration: float = 0.8
@export var death_particles_enabled: bool = true
@export_range(4, 64, 1) var death_particle_amount: int = 28
@export var death_flash_color: Color = Color(1.0, 0.42, 0.48, 1.0)

var has_been_airborne: bool = false
var can_climb: bool = false
var is_climbing: bool = false
var climb_jump_active: bool = false
var controls_enabled: bool = true
var is_dead: bool = false
var start_sequence_active: bool = false
var start_sequence_consumed: bool = false
var start_sequence_direction: Vector2 = Vector2.RIGHT
var start_sequence_remaining: float = 0.0
var current_state: PlayerState = PlayerState.IDLE
var jump_hold_elapsed: float = 0.0
var nearby_climbable_areas: Array[Area2D] = []
var active_climbable: Node2D = null
var active_climb_anchor: Marker2D = null
var death_particles: CPUParticles2D
var death_tween: Tween
var _default_visual_scale: Vector2
var _default_visual_modulate: Color
var _death_cycle_id: int = 0
var _scene_reload_started: bool = false

@onready var character_sprite: AnimatedSprite2D = $Visual
@onready var climb_prompt: Label = $ClimbPrompt
@onready var player_collision: CollisionShape2D = $CollisionShape2D
@onready var footstep_audio: AudioStreamPlayer = $FootstepSFX
@onready var climb_audio: AudioStreamPlayer = $ClimbSFX

const ANIMATIONS := {
	"idle": {"frames": 4, "fps": 8.0, "loop": true},
	"walk": {"frames": 8, "fps": 12.0, "loop": true},
	"jump": {"frames": 5, "fps": 12.0, "loop": false},
	"fall": {"frames": 2, "fps": 8.0, "loop": true},
	"land": {"frames": 3, "fps": 12.0, "loop": false},
	"climb": {"frames": 8, "fps": 12.0, "loop": true},
}


func _ready() -> void:
	add_to_group("player")
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")

	for animation_name in ANIMATIONS:
		var animation: Dictionary = ANIMATIONS[animation_name]
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, animation["fps"])
		sprite_frames.set_animation_loop(animation_name, animation["loop"])
		for frame_index in range(animation["frames"]):
			var frame_path := "res://assets/character/frames/%s/%02d.png" % [animation_name, frame_index]
			sprite_frames.add_frame(animation_name, load(frame_path))

	character_sprite.sprite_frames = sprite_frames
	character_sprite.play("idle")
	character_sprite.frame_changed.connect(_on_character_frame_changed)
	var audio_listener := get_node_or_null("AudioListener2D") as AudioListener2D
	if audio_listener != null:
		audio_listener.make_current()
	var climb_track := climb_audio.stream as AudioStreamMP3
	if climb_track != null:
		climb_track.loop = true
	_default_visual_scale = character_sprite.scale
	_default_visual_modulate = character_sprite.modulate
	climb_prompt.visible = false
	_create_death_particles()

	for area_node in get_tree().get_nodes_in_group("climbable_areas"):
		var area := area_node as Area2D
		if area == null:
			continue
		area.body_entered.connect(_on_climb_area_body_entered.bind(area))
		area.body_exited.connect(_on_climb_area_body_exited.bind(area))


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if start_sequence_active:
		_process_start_sequence(delta)
		return
	if not controls_enabled:
		velocity = Vector2.ZERO
		return

	if is_climbing:
		_process_climbing(delta)
		return

	var reachable_area := _get_nearest_reachable_climb_area()
	can_climb = reachable_area != null
	_update_climb_prompt()
	if can_climb and Input.is_action_just_pressed("climb_interact"):
		_begin_climbing(reachable_area)
		return

	var was_on_floor := is_on_floor()
	var grounded := was_on_floor and not climb_jump_active
	if not grounded:
		_apply_vertical_gravity(delta)

	if Input.is_action_just_pressed("jump") and grounded:
		velocity.y = jump_velocity
		jump_hold_elapsed = 0.0

	var direction := Input.get_axis("move_left", "move_right")
	if direction < 0.0:
		character_sprite.flip_h = true
	elif direction > 0.0:
		character_sprite.flip_h = false

	if grounded:
		velocity.x = direction * speed
	else:
		_apply_air_control(direction, delta)

	move_and_slide()
	_update_animation(direction)


func begin_start_sequence(
	spawn_position: Vector2,
	direction: Vector2,
	step_distance: float,
	step_count: int
) -> void:
	if start_sequence_consumed:
		return
	_stop_movement_audio()
	start_sequence_consumed = true
	global_position = spawn_position
	controls_enabled = false
	start_sequence_active = true
	start_sequence_direction = Vector2(signf(direction.x), 0.0)
	if is_zero_approx(start_sequence_direction.x):
		start_sequence_direction = Vector2.RIGHT
	start_sequence_remaining = maxf(0.0, step_distance) * float(maxi(0, step_count))
	velocity = Vector2.ZERO
	is_climbing = false
	climb_jump_active = false
	active_climbable = null
	active_climb_anchor = null
	can_climb = false
	nearby_climbable_areas.clear()
	character_sprite.flip_h = start_sequence_direction.x < 0.0
	_play_state(PlayerState.WALK, "walk")
	_update_climb_prompt()
	if is_zero_approx(start_sequence_remaining):
		_finish_start_sequence()


func _process_start_sequence(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		_apply_vertical_gravity(delta)
	var requested_distance := minf(start_sequence_remaining, speed * delta)
	if requested_distance <= 0.0:
		_finish_start_sequence()
		return
	velocity.x = start_sequence_direction.x * requested_distance / maxf(delta, 0.0001)
	var previous_position := global_position
	move_and_slide()
	var travelled := (global_position.x - previous_position.x) * start_sequence_direction.x
	start_sequence_remaining = maxf(0.0, start_sequence_remaining - travelled)
	if travelled < requested_distance - 0.5 and start_sequence_remaining > 0.5:
		_finish_start_sequence()
	elif start_sequence_remaining <= 0.5:
		_finish_start_sequence()


func _finish_start_sequence() -> void:
	start_sequence_active = false
	controls_enabled = true
	start_sequence_remaining = 0.0
	velocity.x = 0.0
	_update_animation(0.0)


func lock_controls() -> void:
	_stop_movement_audio()
	controls_enabled = false
	start_sequence_active = false
	start_sequence_remaining = 0.0
	velocity = Vector2.ZERO
	is_climbing = false
	climb_jump_active = false
	active_climbable = null
	active_climb_anchor = null
	can_climb = false
	nearby_climbable_areas.clear()
	_update_climb_prompt()


func die() -> bool:
	if is_dead or _scene_reload_started:
		return false
	_stop_movement_audio()
	_death_cycle_id += 1
	var this_death_cycle := _death_cycle_id
	var death_started_usec := Time.get_ticks_usec()
	is_dead = true
	controls_enabled = false
	start_sequence_active = false
	start_sequence_remaining = 0.0
	velocity = Vector2.ZERO
	is_climbing = false
	climb_jump_active = false
	active_climbable = null
	active_climb_anchor = null
	can_climb = false
	nearby_climbable_areas.clear()
	climb_prompt.visible = false
	player_collision.set_deferred("disabled", true)
	set_physics_process(false)
	_run_death_and_respawn(death_started_usec, this_death_cycle)
	return true


func _run_death_and_respawn(death_started_usec: int, death_cycle_id: int) -> void:
	if death_tween != null and death_tween.is_running():
		death_tween.kill()
	if death_particles_enabled:
		death_particles.amount = death_particle_amount
		death_particles.lifetime = death_particle_duration
		death_particles.restart()
		death_particles.emitting = true

	var duration := maxf(0.2, death_effect_duration)
	var tint := _default_visual_modulate.lerp(death_flash_color, death_tint_intensity)
	var squash := Vector2(
		_default_visual_scale.x * (1.0 + death_deformation_intensity * 0.55),
		_default_visual_scale.y * (1.0 - death_deformation_intensity * 0.6)
	)
	var collapsed := Vector2(
		_default_visual_scale.x * 0.04,
		_default_visual_scale.y * 0.08
	)
	var transparent_tint := tint
	transparent_tint.a = 0.0
	death_tween = create_tween()
	death_tween.tween_property(character_sprite, "modulate", tint, duration * 0.22)
	death_tween.parallel().tween_property(character_sprite, "scale", squash, duration * 0.22)
	death_tween.tween_property(character_sprite, "modulate", transparent_tint, duration * 0.78)
	death_tween.parallel().tween_property(character_sprite, "scale", collapsed, duration * 0.78)
	await death_tween.finished
	if death_cycle_id != _death_cycle_id or not is_dead:
		return
	character_sprite.visible = false
	var elapsed_since_death := float(Time.get_ticks_usec() - death_started_usec) / 1000000.0
	var remaining_delay := maxf(0.0, respawn_delay - elapsed_since_death)
	if remaining_delay > 0.0:
		await get_tree().create_timer(remaining_delay).timeout
	if (
		not is_instance_valid(self)
		or not is_inside_tree()
		or death_cycle_id != _death_cycle_id
		or not is_dead
		or _scene_reload_started
	):
		return
	var scene_tree := get_tree()
	var current_scene := scene_tree.current_scene
	if current_scene == null or not current_scene.is_ancestor_of(self):
		return
	_scene_reload_started = true
	scene_tree.reload_current_scene()


func _create_death_particles() -> void:
	death_particles = CPUParticles2D.new()
	death_particles.name = "DeathParticles"
	death_particles.position = character_sprite.position
	death_particles.amount = death_particle_amount
	death_particles.lifetime = death_particle_duration
	death_particles.one_shot = true
	death_particles.explosiveness = 0.9
	death_particles.direction = Vector2.UP
	death_particles.spread = 180.0
	death_particles.gravity = Vector2(0.0, 120.0)
	death_particles.initial_velocity_min = 80.0
	death_particles.initial_velocity_max = 190.0
	death_particles.scale_amount_min = 1.5
	death_particles.scale_amount_max = 3.5
	death_particles.color = death_flash_color
	var fade_gradient := Gradient.new()
	fade_gradient.set_color(0, death_flash_color)
	var faded_color := death_flash_color
	faded_color.a = 0.0
	fade_gradient.set_color(1, faded_color)
	death_particles.color_ramp = fade_gradient
	death_particles.emitting = false
	add_child(death_particles)


func _update_animation(direction: float) -> void:
	if is_dead:
		_stop_footstep_audio()
		return
	if (
		is_climbing
		or start_sequence_active
		or not controls_enabled
		or current_state != PlayerState.WALK
		or not is_on_floor()
		or is_zero_approx(direction)
	):
		_stop_footstep_audio()
	if is_on_floor():
		if has_been_airborne:
			has_been_airborne = false
			climb_jump_active = false
			_play_state(PlayerState.LAND, "land")
		elif current_state == PlayerState.LAND and character_sprite.is_playing():
			return
		elif absf(direction) > 0.0:
			_play_state(PlayerState.WALK, "walk")
		else:
			_play_state(PlayerState.IDLE, "idle")
	else:
		has_been_airborne = true
		if velocity.y < 0.0:
			if climb_jump_active:
				_play_state(PlayerState.CLIMB_JUMP, "jump")
			else:
				_play_state(PlayerState.JUMP, "jump")
		else:
			_play_state(PlayerState.FALL, "fall")


func _play_state(new_state: PlayerState, animation_name: StringName) -> void:
	if is_dead:
		return
	if current_state == new_state:
		return
	current_state = new_state
	if character_sprite.animation != animation_name:
		character_sprite.play(animation_name)


func _apply_vertical_gravity(delta: float) -> void:
	var current_gravity := ascent_gravity if velocity.y < 0.0 else descent_gravity
	if velocity.y < 0.0 and jump_hold_elapsed < jump_hold_duration and Input.is_action_pressed("jump"):
		current_gravity *= jump_hold_gravity_scale
	jump_hold_elapsed += delta
	velocity.y += current_gravity * delta


func _apply_air_control(direction: float, delta: float) -> void:
	var control_scale := climb_jump_air_control if climb_jump_active else 1.0
	if is_zero_approx(direction):
		velocity.x = move_toward(velocity.x, 0.0, air_deceleration * control_scale * delta)
		return

	var acceleration := air_acceleration
	if not is_zero_approx(velocity.x) and signf(velocity.x) != signf(direction):
		acceleration = air_braking
	velocity.x = move_toward(
		velocity.x,
		direction * max_air_horizontal_speed,
		acceleration * control_scale * delta
	)


func _process_climbing(delta: float) -> void:
	if Input.is_action_just_pressed("climb_interact"):
		_end_climbing()
		return
	if Input.is_action_just_pressed("jump"):
		_jump_from_climb()
		return
	if not is_instance_valid(active_climbable):
		_end_climbing()
		return

	var vertical_direction := Input.get_axis("climb_up", "climb_down")
	velocity.x = 0.0
	var surface_speed := climb_speed
	if active_climbable.has_method("get_climb_speed"):
		surface_speed = active_climbable.get_climb_speed()
	var y_scale := active_climbable.global_transform.y.length()
	if is_zero_approx(y_scale):
		_end_climbing()
		return
	var local_half_height := _get_player_half_extent(active_climbable.global_transform.y.normalized()) / y_scale
	var top_limit := _get_climb_marker("TopAnchor").position.y + local_half_height
	var bottom_limit := _get_climb_marker("BottomAnchor").position.y - local_half_height
	var local_position := active_climbable.to_local(global_position)
	var target_y := clampf(local_position.y + vertical_direction * surface_speed * delta / y_scale, top_limit, bottom_limit)
	var desired_position := active_climbable.to_global(Vector2(active_climb_anchor.position.x, target_y))
	var starting_position := global_position
	velocity = (desired_position - starting_position) / maxf(delta, 0.0001)
	if is_zero_approx(vertical_direction):
		if character_sprite.is_playing():
			character_sprite.pause()
	else:
		if current_state != PlayerState.CLIMB:
			_play_state(PlayerState.CLIMB, "climb")
		elif not character_sprite.is_playing():
			character_sprite.play("climb")

	var motion := desired_position - global_position
	if not motion.is_zero_approx():
		move_and_collide(motion)
	velocity = (global_position - starting_position) / maxf(delta, 0.0001)
	local_position = active_climbable.to_local(global_position)
	if local_position.y <= top_limit + 0.5:
		_set_climb_audio_active(false)
		local_position = Vector2(active_climb_anchor.position.x, top_limit)
		global_position = active_climbable.to_global(local_position)
		if _try_step_onto_climbable_top():
			return
		velocity = Vector2.ZERO
		if character_sprite.is_playing():
			character_sprite.pause()
	elif vertical_direction > 0.0 and local_position.y >= bottom_limit - 0.5:
		local_position = Vector2(active_climb_anchor.position.x, bottom_limit)
		global_position = active_climbable.to_global(local_position)
		_end_climbing()
	else:
		_set_climb_audio_active(not is_zero_approx(vertical_direction) and velocity.length() > 0.5)


func _begin_climbing(area: Area2D) -> void:
	_stop_footstep_audio()
	active_climbable = area.get_parent() as Node2D
	if active_climbable == null:
		return

	is_climbing = true
	climb_jump_active = false
	has_been_airborne = false
	jump_hold_elapsed = jump_hold_duration
	velocity = Vector2.ZERO
	var left_anchor := _get_climb_marker("LeftClimbAnchor")
	var right_anchor := _get_climb_marker("RightClimbAnchor")
	if active_climbable.has_method("get_climb_anchor_for_area"):
		active_climb_anchor = active_climbable.get_climb_anchor_for_area(area)
	if active_climb_anchor == null:
		if global_position.distance_squared_to(left_anchor.global_position) <= global_position.distance_squared_to(right_anchor.global_position):
			active_climb_anchor = left_anchor
		else:
			active_climb_anchor = right_anchor
	character_sprite.flip_h = active_climb_anchor == right_anchor
	var local_position := active_climbable.to_local(global_position)
	local_position.x = active_climb_anchor.position.x
	global_position = active_climbable.to_global(local_position)
	_play_state(PlayerState.CLIMB, "climb")
	_update_climb_prompt()


func _jump_from_climb() -> void:
	_set_climb_audio_active(false)
	_stop_footstep_audio()
	var jump_direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("climb_up", "climb_down")
	)
	if jump_direction.is_zero_approx():
		var away_direction := _get_surface_outward_direction()
		jump_direction = away_direction + Vector2(0.0, -0.35)

	jump_direction = jump_direction.normalized()
	var weighted_direction := Vector2(
		jump_direction.x * maxf(0.0, climb_jump_horizontal_impulse),
		jump_direction.y * maxf(0.0, climb_jump_vertical_impulse)
	)
	if not weighted_direction.is_zero_approx():
		var impulse_limit: float
		if not is_zero_approx(jump_direction.x) and not is_zero_approx(jump_direction.y):
			impulse_limit = minf(climb_jump_horizontal_impulse, climb_jump_vertical_impulse)
		elif not is_zero_approx(jump_direction.x):
			impulse_limit = climb_jump_horizontal_impulse
		else:
			impulse_limit = climb_jump_vertical_impulse
		velocity = weighted_direction.normalized() * maxf(0.0, impulse_limit)
	else:
		velocity = Vector2.ZERO

	is_climbing = false
	active_climbable = null
	active_climb_anchor = null
	climb_jump_active = true
	has_been_airborne = true
	jump_hold_elapsed = 0.0
	if not is_zero_approx(velocity.x):
		character_sprite.flip_h = velocity.x < 0.0
	_play_state(PlayerState.CLIMB_JUMP, "jump")
	_update_climb_prompt()


func _end_climbing() -> void:
	_set_climb_audio_active(false)
	is_climbing = false
	active_climbable = null
	active_climb_anchor = null
	velocity = Vector2.ZERO
	climb_jump_active = false
	has_been_airborne = not is_on_floor()
	if is_on_floor():
		_play_state(PlayerState.IDLE, "idle")
	else:
		_play_state(PlayerState.FALL, "fall")
	_update_climb_prompt()


func _get_nearest_reachable_climb_area() -> Area2D:
	var nearest_area: Area2D = null
	var nearest_distance_squared := INF
	for area in nearby_climbable_areas:
		if not is_instance_valid(area) or not _has_clear_line_of_sight(area):
			continue
		var surface_root := area.get_parent() as Node2D
		if surface_root != null and surface_root.has_method("can_player_climb_from"):
			if not surface_root.can_player_climb_from(global_position, area):
				continue
		var distance_squared := global_position.distance_squared_to(area.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_area = area
	return nearest_area


func _has_clear_line_of_sight(area: Area2D) -> bool:
	var surface_root := area.get_parent() as Node2D
	if surface_root == null:
		return false
	var surface_body := surface_root.get_node_or_null("Body") as CollisionObject2D
	if surface_body == null:
		return false

	var query := PhysicsRayQueryParameters2D.create(global_position, area.global_position)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.get("collider") == surface_body


func _get_climb_marker(marker_name: String) -> Marker2D:
	return active_climbable.get_node(NodePath(marker_name)) as Marker2D


func _get_player_half_extent(world_axis: Vector2) -> float:
	var player_shape := $CollisionShape2D.shape as RectangleShape2D
	return absf(world_axis.x) * player_shape.size.x * 0.5 + absf(world_axis.y) * player_shape.size.y * 0.5


func _get_surface_outward_direction() -> Vector2:
	if active_climbable == null or active_climb_anchor == null:
		return Vector2.LEFT
	var local_direction := -1.0 if active_climb_anchor.position.x < 0.0 else 1.0
	return active_climbable.global_transform.x.normalized() * local_direction


func _try_step_onto_climbable_top() -> bool:
	var horizontal_direction := Input.get_axis("move_left", "move_right")
	if is_zero_approx(horizontal_direction):
		return false
	var inward_direction := -_get_surface_outward_direction()
	if horizontal_direction * inward_direction.x <= 0.0:
		return false

	_set_climb_audio_active(false)
	is_climbing = false
	active_climbable = null
	active_climb_anchor = null
	climb_jump_active = false
	has_been_airborne = true
	velocity = Vector2(horizontal_direction * speed, 0.0)
	character_sprite.flip_h = horizontal_direction < 0.0
	_play_state(PlayerState.FALL, "fall")
	_update_climb_prompt()
	return true


func _update_climb_prompt() -> void:
	climb_prompt.visible = can_climb and not is_climbing


func _on_climb_area_body_entered(body: Node2D, area: Area2D) -> void:
	if body == self and not nearby_climbable_areas.has(area):
		nearby_climbable_areas.append(area)


func _on_climb_area_body_exited(body: Node2D, area: Area2D) -> void:
	if body == self:
		nearby_climbable_areas.erase(area)
		if not is_climbing:
			can_climb = _get_nearest_reachable_climb_area() != null
			_update_climb_prompt()


func _on_character_frame_changed() -> void:
	if (
		character_sprite.animation != "walk"
		or current_state != PlayerState.WALK
		or character_sprite.frame not in [1, 5]
		or is_dead
		or is_climbing
		or start_sequence_active
		or not controls_enabled
		or not is_on_floor()
		or absf(velocity.x) < 1.0
	):
		return
	footstep_audio.play()


func _stop_footstep_audio() -> void:
	if footstep_audio != null and footstep_audio.playing:
		footstep_audio.stop()


func _set_climb_audio_active(active: bool) -> void:
	if climb_audio == null:
		return
	if active and not climb_audio.playing:
		climb_audio.play()
	elif not active and climb_audio.playing:
		climb_audio.stop()


func _stop_movement_audio() -> void:
	_stop_footstep_audio()
	_set_climb_audio_active(false)
