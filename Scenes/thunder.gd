extends Node3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# Called when the node enters the scene tree for the first time.
func call_thunder():
	animation_player.play("Thunder")

func toggle_damage():
	Global.thunder_damage = !Global.thunder_damage
