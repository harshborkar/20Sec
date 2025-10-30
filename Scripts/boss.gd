extends CharacterBody3D

const SPEED = 4.0

@export var player_path: NodePath

var player: Node3D
var nav_agent: NavigationAgent3D

func _ready():
	player = get_node(player_path)
	nav_agent = $NavigationAgent3D

	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5

func _physics_process(delta):

	
	nav_agent.set_target_position(player.global_position)
	var destination = nav_agent.get_next_path_position()
	var local_destination = destination- global_position
	var direction = local_destination.normalized()
	velocity = direction * SPEED
	move_and_slide()
