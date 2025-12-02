# This script is attached to the Control node that manages the BossHealthBar.
# It uses signals to react to Boss health changes, eliminating the need for _process.

extends Control

# This path assumes the HealthBarManager node is a sibling or child of the Boss.
# Adjust the path based on your scene tree structure.
# Example: If HealthBarManager is a direct child of the Boss node, use:
# @onready var boss = get_parent() 
# For this example, let's assume it's at "../Boss" relative to the manager.
const BOSS_PATH = "../im_fuckin_done"  #name of te root characer body of boss

@export var boss:Boss

@onready var health_bar: TextureProgressBar = $HealthBar

func _ready() -> void:
	# Ensure the boss and health bar are valid
	if not is_instance_valid(boss):
		push_error("HealthBarManager failed to find Boss node at path: ", BOSS_PATH)
		return
	if not is_instance_valid(health_bar):
		push_error("HealthBarManager failed to find Health Bar child ($BossHealthBar).")
		return
		
	# 1. Connect the Boss's signal to a local function.
	# The Boss emits "health_changed(new_health: float)"
	boss.health_changed.connect(_on_boss_health_changed)
	
	# The initial health update will now be handled by the signal emitted in Boss._ready()
	# This ensures the health bar initializes immediately with the correct max health.
	

# This function is called every time the Boss emits the 'health_changed' signal.
func _on_boss_health_changed(new_health: float) -> void:
	# 2. Pass the updated health value directly to the bar component.
	if is_instance_valid(health_bar):
		health_bar.update_health(new_health)
