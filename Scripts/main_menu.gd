extends Control

const MAIN_MENU = preload("uid://ckvo4tho45fhx")
@onready var menu_camera_3d: Camera3D = $SubViewportContainer/SubViewport/Camera3D
@export var player_camera_3d: Camera3D 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# Called every frame. 'delta' is the elapsed time since the previous frame.



func _on_start_pressed() -> void:
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	

	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUINT)
	
	# I increased the time from 1 to 2.5 for a slower, drift-like effect
	var duration = 2.5 
	
	# 1. Fade out UI
	if has_node("VBoxContainer"):
		tween.tween_property($VBoxContainer, "modulate:a", 0, duration)
	
	# 2. Move Camera Smoothly
	tween.tween_property(menu_camera_3d, "global_transform", player_camera_3d.global_transform, duration)
	tween.tween_property(menu_camera_3d, "fov", player_camera_3d.fov, duration)

	# 3. Finish
	tween.chain().tween_callback(func():
		menu_camera_3d.current = false
		player_camera_3d.current = true
		
		Global.start_game = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED 
		
		queue_free()
	)
