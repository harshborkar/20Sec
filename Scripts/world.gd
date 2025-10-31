extends Node3D
@onready var player: Node3D = $Player


func _physics_process(delta: float) -> void:
	get_tree().call_group("BOSS", "update_target_location", player.global_position)
