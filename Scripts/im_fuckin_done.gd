class_name Boss
extends CharacterBody3D
@onready var thunder_particles: GPUParticles3D = $thunder_particles

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var healthbar = $HealthBar
@onready var sprite_3d: Sprite3D = $Armature_049/Skeleton3D/BoneAttachment3D/Sprite3D
@onready var attack_cooldown_timer: Timer = $attack_cooldown
@onready var area_3d: Area3D = $Armature_049/Skeleton3D/BoneAttachment3D2/axe/Area3D

@export var attack_cooldown:float = 0.2
@export var player: Player
@export var health: float = 10.0
@export var RUN_RANGE: float = 15.0
@export var MOVE_SPEED: float = 3.0
@export var ROOT_MOTION_SCALE: float = 50.0  # Adjustable in inspector

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var debug_timer: int = 0

enum STATE { MOVE, ATTACK, DEAD }
var state: STATE = STATE.MOVE
var give_damage:bool = false

# Extra boss state variables
var max_health: float
var used_aoe_phase: bool = false  # For first AoE in phase 3

# AnimationTree parameters
# "parameters/conditions/idle"
# "parameters/conditions/aoe"
# "parameters/conditions/kick"
# "parameters/conditions/move"
# "parameters/conditions/slash_1"
# "parameters/conditions/slash_2"
func _ready() -> void:
	animation_tree.active = true
	max_health = health
	randomize()
	animation_tree.active = true
	healthbar.init_health(health)
	
	attack_cooldown_timer.wait_time = attack_cooldown  # seconds between attacks (tweak as needed)
	attack_cooldown_timer.one_shot = true
	print("=== BOSS INITIALIZED ===")


func _physics_process(delta: float) -> void:
	var state_machine = animation_tree.get("parameters/playback")
	if not player:
		return

	if state == STATE.DEAD:
		return

	debug_timer += 1
	var print_debug: bool = debug_timer % 60 == 0

	# --- NAVIGATION SETUP ---
	nav_agent.target_position = player.global_position
	var direction = Vector3.ZERO

	if not nav_agent.is_navigation_finished():
		var next_point = nav_agent.get_next_path_position()
		direction = next_point - global_position
		direction.y = 0
		if direction.length() > 0.001:
			direction = direction.normalized()

	# --- ROTATION ---
	if direction != Vector3.ZERO:
		var target_rot_y = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, delta * 5.0)

	var distance_to_player = global_position.distance_to(player.global_position)

	# --- STATE BEHAVIOR ---
	match state:
		STATE.MOVE:
			handle_movement(direction, delta, distance_to_player)
		STATE.ATTACK:
			velocity = Vector3.ZERO
		STATE.DEAD:
			velocity = Vector3.ZERO

	move_and_slide()

	# --- Target indicator sprite ---
	sprite_3d.visible = player.is_targeting


# ----------------------------
# MOVEMENT
# ----------------------------
func handle_movement(direction: Vector3, delta: float, distance_to_player: float) -> void:
	var should_move = direction.length() > 0.01 and distance_to_player > 2.0
	var root_motion = animation_tree.get_root_motion_position()

	if should_move:
		animation_tree.set("parameters/conditions/move", true)
		animation_tree.set("parameters/conditions/idle", false)
		if root_motion.length() > 0:
			root_motion *= ROOT_MOTION_SCALE
			var current_rot = transform.basis.get_rotation_quaternion()
			velocity = (current_rot.normalized() * root_motion) / delta
		else:
			velocity = direction * MOVE_SPEED
	else:
		animation_tree.set("parameters/conditions/move", false)
		animation_tree.set("parameters/conditions/idle", true)
		velocity.x = 0
		velocity.z = 0

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# --- ATTACK TRIGGER ---
	if distance_to_player <= 2.5:
		select_attack()



# ----------------------------
# DAMAGE
# ----------------------------
func take_damage(damage_received: float) -> void:
	health -= damage_received
	print("Boss HP: ", health)
	if health <= 0 and state != STATE.DEAD:
		state = STATE.DEAD
		handle_death()


func handle_death():
	print("Boss defeated!")
	animation_tree.set("parameters/conditions/idle", false)
	animation_tree.set("parameters/conditions/move", false)
	animation_tree.set("parameters/conditions/slash_1", false)
	animation_tree.set("parameters/conditions/slash_2", false)
	animation_tree.set("parameters/conditions/kick", false)
	animation_tree.set("parameters/conditions/aoe", false)
	queue_free()


# ----------------------------
# ATTACK LOGIC
# ----------------------------
func get_health_percent() -> float:
	return (health * 100.0) / max_health


func select_attack():
	var hp = get_health_percent()
	var attack

	if hp >= 70:
		attack = ["slash_1", "slash_2"].pick_random()
	elif hp >= 40:
		attack = ["slash_2", "kick"].pick_random()
	else:
		if not used_aoe_phase:
			attack = "aoe"
			used_aoe_phase = true
		else:
			attack = ["slash_1", "slash_2", "kick", "aoe"].pick_random()

	trigger_attack(attack)


func trigger_attack(attack: String):
	state = STATE.ATTACK

	# Disable movement and set correct animation condition
	animation_tree.set("parameters/conditions/idle", false)
	animation_tree.set("parameters/conditions/move", false)
	animation_tree.set("parameters/conditions/aoe", attack == "aoe")
	animation_tree.set("parameters/conditions/kick", attack == "kick")
	animation_tree.set("parameters/conditions/slash_1", attack == "slash_1")
	animation_tree.set("parameters/conditions/slash_2", attack == "slash_2")



	# --- Small rotation adjustment ONLY for slash_1 ---
	if attack == "slash_1":
		var original_rot_y = rotation.y
		var target_rot_y = original_rot_y - deg_to_rad(15)  # rotate 15° left

		var tween := create_tween()
		tween.tween_property(self, "rotation:y", target_rot_y, 0.15)  # quick tilt before swing

		# Return to original rotation smoothly after a short delay
		tween.tween_interval(0.8)
		tween.tween_property(self, "rotation:y", original_rot_y, 0.25)

	# After attack animation ends, return to move state
	await get_tree().create_timer(.6).timeout
	reset_attack_conditions()
	state = STATE.MOVE
	area_3d.monitoring = false


func reset_attack_conditions():
	animation_tree.set("parameters/conditions/slash_1", false)
	animation_tree.set("parameters/conditions/slash_2", false)
	animation_tree.set("parameters/conditions/kick", false)
	animation_tree.set("parameters/conditions/aoe", false)
	animation_tree.set("parameters/conditions/move", true)

func toggle_give_damage()->void:
	give_damage = !give_damage


func call_thunder():
	thunder_particles.global_position = player.global_position
	thunder_particles.emitting = true
func turn_off_thunder():
	thunder_particles.emitting = false
	
