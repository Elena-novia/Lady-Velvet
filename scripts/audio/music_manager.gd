extends AudioStreamPlayer


func _ready() -> void:
	var music_track := stream as AudioStreamMP3
	if music_track != null:
		music_track.loop = true

	if not playing:
		play()
