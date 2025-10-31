extends CharacterBody3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_tree: AnimationTree = $AnimationTree

@export var SPEED: float = 3.0
@export var player: CharacterBody3D
@export var GRAVITY: float = 9.8
@export var JUMP_VELOCITY: float = 0.0 # Not used now, but you can add jumps later

enum STATE { IDLE, TAUNT, WALK, SLASH, KICK, HURT }
var state: STATE = STATE.IDLE

var attack_range: float = 5.0
var attack_cooldown: float = 2.0 # seconds between attacks
var last_attack_time: float = -999.0

func _ready() -> void:
	animation_tree.active = true
	state = STATE.IDLE

func _physics_process(delta: float) -> void:
	if not player:
		return

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# --- Movement / Target Logic ---
	var dist_to_player = global_position.distance_to(player.global_position)
	nav_agent.target_position = player.global_position

	# Face the player horizontally
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

	# --- Movement / Attack logic ---
	if dist_to_player > attack_range and state not in [STATE.KICK, STATE.SLASH]:
		# Move toward player
		if not nav_agent.is_navigation_finished():
			state = STATE.WALK
			var next_point: Vector3 = nav_agent.get_next_path_position()
			var direction: Vector3 = global_position.direction_to(next_point)
			var horizontal_velocity = direction * SPEED
			velocity.x = horizontal_velocity.x
			velocity.z = horizontal_velocity.z
		else:
			# No path; idle
			state = STATE.IDLE
			velocity.x = 0
			velocity.z = 0
	else:
		# Attack logic
		velocity.x = 0
		velocity.z = 0
		if can_attack():
			state = choose_attack()
			last_attack_time = Time.get_ticks_msec() / 1000.0
		else:
			state = STATE.IDLE

	move_and_slide()
	handle_animations()

# --- Animation Handler ---
func handle_animations() -> void:
	animation_tree.set("parameters/conditions/taunt", false)
	animation_tree.set("parameters/conditions/walk", false)
	animation_tree.set("parameters/conditions/slash", false)
	animation_tree.set("parameters/conditions/kick", false)
	animation_tree.set("parameters/conditions/injured", false)

	match state:
		STATE.IDLE:
			animation_tree.set("parameters/conditions/taunt", true)
		STATE.WALK:
			animation_tree.set("parameters/conditions/walk", true)
		STATE.SLASH:
			animation_tree.set("parameters/conditions/slash", true)
		STATE.KICK:
			animation_tree.set("parameters/conditions/kick", true)
		STATE.HURT:
			animation_tree.set("parameters/conditions/injured", true)

# --- Attack Helpers ---
func in_range() -> bool:
	return global_position.distance_to(player.global_position) < attack_range

func can_attack() -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - last_attack_time) >= attack_cooldown and state != STATE.HURT

func choose_attack() -> STATE:
	var attack_type = randi_range(0, 1)
	if attack_type == 0:
		return STATE.SLASH
	else:
		return STATE.KICK
