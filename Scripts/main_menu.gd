extends Control
@onready var v_box_container: VBoxContainer = $VBoxContainer
@onready var exit: Button = $VBoxContainer/Exit
@onready var start: Button = $VBoxContainer/Start
@onready var option: OptionButton = $VBoxContainer/Option


@onready var menu_camera_3d: Camera3D = $SubViewportContainer/SubViewport/Camera3D
@export var player_camera_3d: Camera3D 
@export var plyer_animation_player:AnimationPlayer

@export var pan_amount := 2.0      # how far camera pans from center
@export var pan_speed := 5.0  

@export var boss:Boss
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	base_position = menu_camera_3d.position

# Called every frame. 'delta' is the elapsed time since the previous frame.

	 # how fast it follows the mouse

var base_position:Vector3
var target_offset:Vector3 = Vector3.ZERO

	
func _process(delta: float) -> void:
	var mouse_pos = get_local_mouse_position()
	var screen_size = get_viewport_rect().size
	# Normalize mouse position to range [-1, 1]
	var normalized_mouse = (mouse_pos / screen_size) * 2.0 - Vector2(1, 1)
	
	# Compute target offset (how far from base to pan)
	target_offset.z = -normalized_mouse.x * pan_amount
	target_offset.y= -normalized_mouse.y * pan_amount
	
	# Smoothly interpolate the camera position around its base
	var desired_position = target_offset + base_position
	menu_camera_3d.position = menu_camera_3d.position.lerp(desired_position, pan_speed*delta)

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
