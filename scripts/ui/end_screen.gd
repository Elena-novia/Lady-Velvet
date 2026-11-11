extends CanvasLayer

var has_finished: bool = false

@onready var overlay: Control = $Overlay
@onready var panel_container: PanelContainer = $Overlay/CenterContainer/PanelContainer
@onready var margin_container: MarginContainer = $Overlay/CenterContainer/PanelContainer/MarginContainer
@onready var restart_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RestartButton


func _ready() -> void:
	add_to_group("end_screen")
	overlay.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func _fit_to_viewport() -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var panel_width := minf(540.0, maxf(280.0, viewport_width - 32.0))
	panel_container.custom_minimum_size.x = panel_width
	var content_margin := int(clampf(panel_width * 0.09, 16.0, 48.0))
	margin_container.add_theme_constant_override("margin_left", content_margin)
	margin_container.add_theme_constant_override("margin_right", content_margin)


func finish_game(player: Node) -> void:
	if has_finished:
		return
	has_finished = true
	if player.has_method("lock_controls"):
		player.lock_controls()
	overlay.visible = true
	overlay.modulate.a = 0.0
	restart_button.grab_focus()
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(
		overlay,
		"modulate:a",
		1.0,
		0.4
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
