extends Control

# Called when the node enters the scene tree for the first time.
@onready var label: Label = $Label
@onready var button: Button = $Button

func _ready() -> void:
	# Keep them invisible initially
	label.modulate.a = 0
	button.modulate.a = 0

	
	# Start the animation immediately (or call this whenever you want)


func animate_text():
	self.visible = true
	var tween: Tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# --- Setup Positions ---
	# We store where they SHOULD be, then move them down 10px instantly
	var label_final_y = label.position.y
	var button_final_y = button.position.y
	
	label.position.y += 10
	button.position.y += 10

	# --- ANIMATION CONFIGURATION ---
	# Cubic Out makes the movement fast at start and slow at end (smooth UI feel)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# --- ANIMATE LABEL ---
	tween.set_parallel(true) # Allow position and fade to happen at the same time
	tween.tween_property(label, "position:y", label_final_y, 0.8)
	tween.tween_property(label, "modulate:a", 1.0, 0.8)
	
	# --- ANIMATE BUTTON ---
	tween.set_parallel(false) # Pause parallel mode to insert a delay
	tween.tween_interval(0.2) # Wait 0.2s before showing the button
	
	tween.set_parallel(true) # Re-enable parallel for the button animation
	tween.tween_property(button, "position:y", button_final_y, 0.8)
	tween.tween_property(button, "modulate:a", 1.0, 0.8)


func _on_button_pressed() -> void:
	get_tree().reload_current_scene()
