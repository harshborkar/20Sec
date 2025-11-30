extends Control
@onready var label: Label = $Label
@onready var timer: Timer = $Timer

var time_left:float
# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	label.text = "20"
func _process(delta: float) -> void:
	label.text = "%.1f" % timer.time_left
