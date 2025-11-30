# This script controls the main (green) stamina bar.
# It assumes it has two children:
# 1. A Timer node named "Timer" (as a child of DepleteBar)
# 2. A ProgressBar node named "DepleteBar" (the red bar that shows stamina depletion)

extends ProgressBar

@onready var timer = $DepleteBar/Timer
@onready var deplete_bar = $DepleteBar

# Store the tween so we can reuse it
var depletion_tween: Tween


func _ready() -> void:
	# Initialize stamina values when the player is ready
	# We'll connect to the player's stamina updates
	var player = get_parent()
	if player and player.has_method("get_max_stamina"):
		init_stamina(player.get_max_stamina())


func _process(_delta: float) -> void:
	# Constantly update the bar's value to match the player's stamina
	var player = get_parent()
	if player and player.has_method("get_stamina"):
		_set_stamina(player.get_stamina())


# Sets the stamina of the green bar and decides what to do
# with the red (depletion) bar.
func _set_stamina(new_stamina: float) -> void:
	var prev_stamina = value
	value = clamp(new_stamina, 0, max_value)
	
	if value < prev_stamina:
		# Stamina was depleted. Start the timer for the depletion bar to catch up.
		timer.start()
		
	elif value > prev_stamina:
		# Stamina was regenerated.
		# Snap the depletion bar UP immediately to match the new stamina.
		deplete_bar.value = value


# Initialize all values at the start.
func init_stamina(max_stamina: float) -> void:
	max_value = max_stamina
	value = max_stamina
	deplete_bar.max_value = max_stamina
	deplete_bar.value = max_stamina


# This function runs when the Timer finishes.
func _on_timer_timeout() -> void:
	# Create a smooth animation for the depletion bar
	
	# If a tween is already running, kill it.
	if depletion_tween:
		depletion_tween.kill()

	# Create a new tween to animate the depletion bar
	depletion_tween = get_tree().create_tween()
	
	# Animate the 'deplete_bar's 'value' property TO the current 'value' (green bar)
	# over 0.4 seconds, using a smooth curve (ease-out).
	depletion_tween.tween_property(deplete_bar, "value", value, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
