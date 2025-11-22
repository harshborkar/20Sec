extends Node3D

# Your existing references
@onready var light: OmniLight3D = $TearModel/Sparks/Light
@onready var light1: OmniLight3D = $TearModel2/Sparks/Light
@onready var light2: OmniLight3D = $TearModel3/Sparks/Light
@onready var light3: OmniLight3D = $TearModel4/Sparks/Light
@onready var light4: OmniLight3D = $TearModel5/Sparks/Light
@onready var light5: OmniLight3D = $TearModel6/Sparks/Light
@onready var light6: OmniLight3D = $TearModel7/Sparks/Light
@onready var light7: OmniLight3D = $TearModel8/Sparks/Light
@onready var light8: OmniLight3D = $TearModel9/Sparks/Light
@onready var light9: OmniLight3D = $TearModel10/Sparks/Light
@onready var light10: OmniLight3D = $TearModel11/Sparks/Light
@onready var light11: OmniLight3D = $TearModel12/Sparks/Light
@onready var light12: OmniLight3D = $TearModel13/Sparks/Light
@onready var light13: OmniLight3D = $TearModel14/Sparks/Light

# Settings for the fire effect
var min_energy: float = 0.0
var max_energy: float = .5
var flicker_speed: float = 20.0 # Higher number = faster jitter

# An array to hold all lights so we can loop through them
var all_lights: Array[OmniLight3D] = []

func _ready() -> void:
	# Add all your lights to the list
	all_lights = [
		light, light1, light2, light3, light4, light5, 
		light6, light7, light8, light9, light10, 
		light11, light12, light13
	]

func _process(delta: float) -> void:
	# Loop through every light in the list
	for fire_light in all_lights:
		if fire_light: # Check if the light exists
			# 1. Pick a random target energy
			var target_energy = randf_range(min_energy, max_energy)
			
			# 2. Smoothly move current energy to target energy (Linear Interpolation)
			# This prevents it from looking like a strobe light and makes it look organic
			fire_light.light_energy = lerp(fire_light.light_energy, target_energy, flicker_speed * delta)
