extends Control

const MAIN_MENU = preload("uid://ckvo4tho45fhx")
@onready var menu_camera_3d: Camera3D = $SubViewportContainer/SubViewport/Camera3D
@export var player_camera_3d: Camera3D 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# Called every frame. 'delta' is the elapsed time since the previous frame.



func _on_start_pressed() -> void:
	# 1. Do NOT set mouse to visible here if you are starting the game.
	# You likely want it captured so the player can look around immediately after the tween.
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# --- FIX: Only fade the UI elements (Buttons/Title), NOT the whole menu ---
	# Replace $VBoxContainer with whatever holds your text/buttons
	if has_node("VBoxContainer"):
		tween.tween_property($VBoxContainer, "modulate:a", 0, 1)
	
	# 2. Move the camera (The camera stays fully visible now!)
	tween.tween_property(menu_camera_3d, "global_transform", player_camera_3d.global_transform, 1)
	tween.tween_property(menu_camera_3d, "fov", player_camera_3d.fov, 1)

	# 3. Wait for animation to finish, THEN switch
	tween.chain().tween_callback(func():
		# Switch cameras now that they are in the exact same spot
		menu_camera_3d.current = false
		player_camera_3d.current = true
		
		# Now we enable game controls
		Global.start_game = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Lock mouse for gameplay
		
		queue_free() # Delete the menu
	)
	
