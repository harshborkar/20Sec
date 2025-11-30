# This script controls the main (green) stamina bar.
extends ProgressBar

# --- ASSIGN THIS IN INSPECTOR ---
# Drag your Player node here in the editor!
@export var player: CharacterBody3D 

@onready var timer = $DepleteBar/Timer
@onready var deplete_bar = $DepleteBar

# Store the tween so we can reuse it
var depletion_tween: Tween

func _ready() -> void:
	# Fallback: If you forgot to assign player in inspector, try to find parent
	if not player and get_parent() is CharacterBody3D:
		player = get_parent()
		
	if player and player.has_method("get_max_stamina"):
		init_stamina(player.get_max_stamina())
	
	# Ensure the timer is set to One Shot so it doesn't loop weirdly
	timer.one_shot = true

func _process(_delta: float) -> void:
	if not player:
		return
		
	# Constantly update the bar's value to match the player's stamina
	if player.has_method("get_stamina"):
		_set_stamina(player.get_stamina())

func _set_stamina(new_stamina: float) -> void:
	var prev_stamina = value
	
	# Update the Green Bar immediately
	value = clamp(new_stamina, 0, max_value)
	
	if value < prev_stamina:
		# --- STAMINA LOST ---
		# If a depletion animation is currently running, kill it so the red bar stays high
		if depletion_tween and depletion_tween.is_running():
			depletion_tween.kill()
			
		# Reset the timer. This creates the "linger" effect. 
		# The red bar won't move until the player STOPS losing stamina.
		timer.start()
		
	elif value > prev_stamina:
		# --- STAMINA REGENERATED ---
		# Kill the tween so it doesn't force the bar down while we want it up
		if depletion_tween:
			depletion_tween.kill()
		
		# Stop the timer, we don't need the catch-up animation anymore
		timer.stop()
		
		# Snap the Red bar to the Green bar immediately to hide the "damage"
		deplete_bar.value = value

func init_stamina(max_stamina: float) -> void:
	max_value = max_stamina
	value = max_stamina
	deplete_bar.max_value = max_stamina
	deplete_bar.value = max_stamina

func _on_timer_timeout() -> void:
	# Kill previous tween if it exists
	if depletion_tween and depletion_tween.is_running():
		depletion_tween.kill()

	# ALWAYS create tween on this node (more stable)
	depletion_tween = create_tween()

	# Animate red bar smoothly down to green bar
	depletion_tween.tween_property(
		deplete_bar, 
		"value", 
		value,     # target == green bar's value
		0.4        # duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
