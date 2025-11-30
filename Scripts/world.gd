extends Node3D
@onready var player: Node3D = $Player



@onready var _20_sec_timer: Timer = $Control/Timer

var first_time:bool = true

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player and first_time:
		first_time =false
		_20_sec_timer.start()
