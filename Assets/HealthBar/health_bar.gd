# This script controls the main (green) health bar (TextureProgressBar).
# It is now managed by a parent node that supplies the health values.

extends TextureProgressBar

@onready var timer = $Timer
@onready var damagebar = $DamageBar

# Store the tween so we can reuse it
var damage_tween: Tween

# ----------------------------------------------------------------------
# NEW INTERFACE FOR PARENT NODE (HealthBarManager)
# ----------------------------------------------------------------------

# Initialize the health bar's maximum and current values.
# This should be called once by the parent when the boss spawns.
func init_health(health: float) -> void:
	max_value = health
	value = health
	damagebar.max_value = health
	damagebar.value = health
	visible = true

# Update the bar's value whenever the boss takes damage or heals.
# This should be called by the parent node on health change events.
func update_health(new_health: float) -> void:
	var prev_health = value
	
	# Clamp new health to ensure it stays within 0 and max_value.
	# We rely on max_value being set by init_health.
	value = clamp(new_health, 0, max_value)

	if value <= 0:
		# Hides the bar when the boss is dead (can be handled by parent too)
		hide()
	
	if value < prev_health:
		# Damage was taken. Start the timer for the damage bar (red) to catch up.
		timer.start()
		
	elif value > prev_health:
		# Healing occurred. Snap the damage bar UP immediately.
		damagebar.value = value

# ----------------------------------------------------------------------
# DAMAGE ANIMATION LOGIC (Remains the same)
# ----------------------------------------------------------------------

# This function runs when the Timer finishes.
func _on_timer_timeout() -> void:
	# If a tween is already running, kill it.
	if damage_tween and damage_tween.is_valid():
		damage_tween.kill()

	# Create a new tween to animate the damage bar
	damage_tween = create_tween()
	
	# Animate the 'damagebar's 'value' property TO the current 'value' (green bar)
	# over 0.4 seconds, using a smooth curve (ease-out).
	damage_tween.tween_property(damagebar, "value", value, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
