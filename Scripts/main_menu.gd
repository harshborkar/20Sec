extends Control
@onready var v_box_container: VBoxContainer = $VBoxContainer
@onready var exit: Button = $VBoxContainer/Exit
@onready var start: Button = $VBoxContainer/Start
@onready var option: OptionButton = $VBoxContainer/Option

const MAIN_MENU = preload("uid://ckvo4tho45fhx")
@onready var menu_camera_3d: Camera3D = $SubViewportContainer/SubViewport/Camera3D
@export var player_camera_3d: Camera3D 
@export var plyer_animation_player:AnimationPlayer

@export var boss:Boss
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# Called every frame. 'delta' is the elapsed time since the previous frame.



func _on_start_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	$VBoxContainer/confirm.play()
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
	plyer_animation_player.playback_default_blend_time = 1
	tween.tween_property(menu_camera_3d, "global_transform", player_camera_3d.global_transform, duration)
	tween.tween_property(menu_camera_3d, "fov", player_camera_3d.fov, duration)

	# 3. Finish
	tween.chain().tween_callback(func():
		menu_camera_3d.current = false
		player_camera_3d.current = true
		
		Global.start_game = true
		Global.animblend()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED 
		
		
		queue_free()
	)


func _on_exit_pressed() -> void:
	$VBoxContainer/confirm.play()
	get_tree().quit()


func _on_start_mouse_entered() -> void:
	$VBoxContainer/hover.play()


func _on_exit_mouse_entered() -> void:
	$VBoxContainer/hover.play()


func _on_option_item_selected(index: int) -> void:
	match index:
		0:
			boss.health = 5
		1:
			boss.health = 7
		2:
			boss.health = 10
