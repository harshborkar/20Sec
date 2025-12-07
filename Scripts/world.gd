extends Node3D

@onready var player: Node3D = $Player
@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer
@onready var _20_sec_timer: Timer = $Control/Timer
@onready var timer_text: Control = $Control
@onready var timer: Timer = $Control/Timer

@onready var end_screen: Control = $"EndScreen"

var first_time: bool = true

func _on_area_3d_body_entered(body: Node3D) -> void:
	# Make sure 'body' is actually the player class/node you expect
	if body.name == "Player" and first_time:  # Or keep 'if body is Player' if you have a class_name
		timer_text.visible=true
		# CHANGE: Call the  truelocal function 'switch_to_boss_theme()'
		# (You had 'Global.switch_to_boss_theme()' but the function is defined right here!)
		switch_to_boss_theme()
		
		first_time = false
		_20_sec_timer.start()
		Global.start_boss = true

func switch_to_boss_theme():
	const BOSS_BATTLE_MUSIC = preload("uid://cj54uiski7a45")
	
	var tween = create_tween()
	
	# 1. Fade OUT to silence
	tween.tween_property(audio_stream_player, "volume_db", -80.0, 1.0).set_trans(Tween.TRANS_SINE)
	
	# 2. Swap track
	tween.tween_callback(func():
		audio_stream_player.stop()
		audio_stream_player.stream = BOSS_BATTLE_MUSIC
		audio_stream_player.play()
	)
	
	# 3. CRITICAL MISSING STEP: Fade IN to normal volume
	tween.tween_property(audio_stream_player, "volume_db", 0.0, 1.0).set_trans(Tween.TRANS_SINE)


func _on_timer_timeout() -> void:
	get_tree().paused= true
	end_screen.animate_text()


func end_game():
	get_tree().paused= true
	
	end_screen.animate_text()
