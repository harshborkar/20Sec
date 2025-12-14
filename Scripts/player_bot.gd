class_name Player
extends CharacterBody3D

#region Configuration & Exports

# --- MOVEMENT SETTINGS ---
@export_group("Movement")
@export var speed_walk: float = 3.5
@export var speed_run: float = 6.5
@export var jump_velocity: float = 4.5
@export var gravity_multiplier: float = 1.0

# --- DASH SETTINGS ---
@export_group("Dash")
@export var dash_min_speed: float = 10.0
@export var dash_max_speed: float = 25.0
@export var dash_duration: float = 0.3
@export var dash_cooldown: float = 0.5
@export var dash_max_charge_time: float = 1.5
@export var dash_stamina_cost: float = 30.0

# --- COMBAT SETTINGS ---
@export_group("Combat")
@export var enemy_target: Boss # Ensure class_name Boss exists
@export var attack_damage: float = 1.0
@export var attack_speed_scale: float = 1.0

@export_subgroup("Cooldowns")
@export var attack_cooldown: float = 0.4
@export var parry_cooldown: float = 0.5

@export_subgroup("Stamina Costs")
@export var stamina_cost_p1: float = 15.0
@export var stamina_cost_combo: float = 10.0 # Cost for P2 and P3

# --- STAMINA SYSTEM ---
@export_group("Stamina System")
@export var max_stamina: float = 100.0
@export var stamina_depletion_rate: float = 20.0 
@export var stamina_regeneration_rate: float = 15.0

# --- CAMERA & INPUT ---
@export_group("Camera & Input")
@export var mouse_sensitivity: Vector2 = Vector2(0.5, 0.5)
@export var targeting_speed: float = 5.0
@export var vertical_nudge_limit: float = 20.0
@export var horizontal_nudge_limit: float = 45.0
@export var dash_charge_fov: float = 120.0

# --- VISUAL EFFECTS ---
@export_group("Visual Effects")
@export var afterimage_count: int = 5
@export var afterimage_spacing: float = 0.05
@export var afterimage_fade_time: float = 0.3
@export var afterimage_color: Color = Color(1, 1, 1, 0.5)


@export var base_ghost_material: StandardMaterial3D 


	# If not assigned in Inspector, create a generic one once at startup

const STONE_CHAIN_WALK_1 = preload("uid://bcst01eofdm1r")

const STONE_CHAIN_WALK_3 = preload("uid://cwfkfaw6hqeya")

const CHAIN_CLANK_1 = preload("uid://bghefjpmnhhe8")
const CHAIN_CLANK_2 = preload("uid://bqpvg0f6cg0o7")

#region State & Variables

# --- ENUMS ---
enum STATE { IDLE, WALK, RUN, DASH_CHARGE, DASH, ATTACK, HURT, DEATH, BLOCK }

# --- STATE VARIABLES ---
var state: STATE = STATE.IDLE
var current_stamina: float = 100.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- COMBAT STATE ---
var combo_step: int = 0
var can_queue_next_combo: bool = false
var is_attack_queued: bool = false
var last_attack_time: float = 0.0
var last_parry_time: float = -1000.0
var can_i_parry: bool = true

# --- DASH STATE ---
var dash_timer: float = 0.0
var dash_charge_time: float = 0.0
var is_charging: bool = false
var last_dash_time: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var afterimage_timer: float = 0.0

# --- CAMERA STATE ---
var base_camera_fov: float
var current_fov_tween: Tween
var is_targeting: bool = false
var original_cam_pos: Vector3
var shake_timer: float = 0.0
var shake_max_strength: float = 0.0
var shake_max_duration: float = 1.0

# --- HIT FEEDBACK STATE ---
var is_attack_connected: bool = false
var has_hit_once: bool = false
var has_shaken_once: bool = false

# --- CONSTANTS ---
const COMBO_P1_WINDOW: float = 0.8 
const COMBO_P2_WINDOW: float = 0.4 
const COMBO_P3_WINDOW: float = 0.3 

#endregion

#region Node References
@onready var footstep: AudioStreamPlayer3D = $footstep

@onready var visuals: Node3D = $visuals
@onready var animation_player: AnimationPlayer = $visuals/AnimationPlayer
@onready var camera_mount: Node3D = $"Camera Mount"
@onready var camera_node: Camera3D = $"Camera Mount/Camera3D"
@onready var combo_timer: Timer = $ComboTimer

@onready var dash_audio: AudioStreamPlayer3D = $dash_audio
@onready var parry_audio: AudioStreamPlayer3D = $parry_audio

#endregion

#region Built-in Methods

func _ready() -> void:
	Global.game_started.connect(animblend)
	if not base_ghost_material:
		base_ghost_material = StandardMaterial3D.new()
		base_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		base_ghost_material.cull_mode = BaseMaterial3D.CULL_BACK
		base_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Optional: makes it look more "energy-like"
		base_ghost_material.albedo_color = afterimage_color
#endregion
	if camera_node:
		base_camera_fov = camera_node.fov
		original_cam_pos = camera_node.position
	else:
		push_warning("Camera Node not found in Player Script")
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_stamina = max_stamina
func animblend():
		animation_player.playback_default_blend_time = .06
func _input(event: InputEvent) -> void:
	if !Global.start_game:
		return
	if event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event.is_action_pressed("Target"):
		toggle_targeting()
	
	if event.is_action_pressed("Attack"):
		handle_attack_input()

func _physics_process(delta: float) -> void:
	if !Global.start_game:
		return
	handle_stamina(delta)
	handle_gravity_and_jump(delta)
	handle_parrying()
	handle_dash_logic(delta)
	handle_targeting_rotation(delta)
	handle_camera_shake(delta)

	if state != STATE.ATTACK:
		handle_movement(delta)
		handle_animations()
		
	# Afterimage logic
	if state == STATE.DASH:
		afterimage_timer -= delta
		if afterimage_timer <= 0.0:
			create_afterimage()
			afterimage_timer = afterimage_spacing

#endregion

#region Input Handling & Camera

func handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var dx = deg_to_rad(event.relative.x)
	var dy = deg_to_rad(event.relative.y)

	if is_targeting:
		camera_mount.rotate_y(-dx * mouse_sensitivity.x)
		camera_mount.rotate_x(-dy * mouse_sensitivity.y)

		var rot = camera_mount.rotation_degrees
		rot.x = clamp(rot.x, -vertical_nudge_limit, vertical_nudge_limit)
		rot.y = clamp(rot.y, -horizontal_nudge_limit, horizontal_nudge_limit)
		camera_mount.rotation_degrees = Vector3(rot.x, rot.y, 0)
	else:
		rotate_y(-dx * mouse_sensitivity.x)
		camera_mount.rotate_x(-dy * mouse_sensitivity.y)

		var x_rot = clamp(camera_mount.rotation_degrees.x, -10, 20)
		camera_mount.rotation_degrees = Vector3(x_rot, 0, 0)

func toggle_targeting() -> void:
	is_targeting = !is_targeting
	var cam_rot_rad = camera_mount.rotation
	
	if is_targeting:
		camera_mount.rotation = Vector3(cam_rot_rad.x, 0, 0)
	else:
		rotate_y(cam_rot_rad.y)
		camera_mount.rotation = Vector3(cam_rot_rad.x, 0, 0)
		visuals.transform.basis = Basis()

func handle_targeting_rotation(delta: float) -> void:
	if not is_targeting:
		return
	if not is_instance_valid(enemy_target):
		is_targeting = false
		return
		
	var target_pos = enemy_target.global_position
	var look_pos = Vector3(target_pos.x, global_position.y, target_pos.z)
	var target_basis = transform.looking_at(look_pos, Vector3.UP).basis
	transform.basis = transform.basis.slerp(target_basis, delta * targeting_speed).orthonormalized()

#endregion

#region Movement & Physics

func handle_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= (gravity * gravity_multiplier) * delta


func handle_movement(delta: float) -> void:
	if state == STATE.DASH:
		if velocity.length_squared() > 0:
			visuals.look_at(position + velocity.normalized())
		return

	var input_dir = Input.get_vector("Left", "Right", "Fwd", "Bkwd")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var moving = direction != Vector3.ZERO
	var running = Input.is_action_pressed("Sprint") and current_stamina > 0
	
	if can_move():
		state = (
			STATE.RUN if moving and running else
			STATE.WALK if moving else
			STATE.IDLE
		)

	# Rotation
	if moving:
		visuals.look_at(position + direction)
	elif is_targeting and state != STATE.DASH_CHARGE:
		visuals.transform.basis = visuals.transform.basis.slerp(Basis(), delta * targeting_speed)

	# Velocity application
	if moving and can_move():
		var current_speed = speed_run if running else speed_walk
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed_walk)
		velocity.z = move_toward(velocity.z, 0, speed_walk)

	move_and_slide()

func can_move() -> bool:
	return not (state in [STATE.ATTACK, STATE.HURT, STATE.DEATH, STATE.DASH_CHARGE, STATE.BLOCK])

#endregion

#region Stamina & Dash Logic

func handle_stamina(delta: float) -> void:
	var running = Input.is_action_pressed("Sprint") and state in [STATE.WALK, STATE.RUN]
	var moving = velocity.length() > 0.1
	
	if running and moving and current_stamina > 0:
		current_stamina = max(0, current_stamina - stamina_depletion_rate * delta)
	elif not running and current_stamina < max_stamina:
		current_stamina = min(max_stamina, current_stamina + stamina_regeneration_rate * delta)
	
	if current_stamina <= 0 and state == STATE.RUN:
		state = STATE.WALK

	# --- CHARGING START ---
	if Input.is_action_just_pressed("Dash") and can_move() and can_dash() and current_stamina >= dash_stamina_cost:
		state = STATE.DASH_CHARGE
		is_charging = true
		dash_charge_time = 0.0
		tween_fov(dash_charge_fov, 3.0, Tween.TRANS_EXPO)

	# --- CHARGING HOLD ---
	if is_charging:
		if current_stamina < dash_stamina_cost:
			cancel_charge()
			return

		if Input.is_action_pressed("Dash"):
			dash_charge_time = clamp(dash_charge_time + delta, 0, dash_max_charge_time)
		elif Input.is_action_just_released("Dash"):
			is_charging = false
			execute_dash()
		return

	# --- FOV RESET ---
	if state == STATE.IDLE and camera_node.fov != base_camera_fov and not is_charging:
		tween_fov(base_camera_fov, 0.4, Tween.TRANS_SINE)

func cancel_charge():
	is_charging = false
	state = STATE.IDLE
	tween_fov(base_camera_fov, 0.4, Tween.TRANS_SINE)

func can_dash() -> bool:
	return Time.get_ticks_msec() - last_dash_time >= dash_cooldown * 1000

func handle_dash_logic(delta: float) -> void:
	if state != STATE.DASH: return
	
	dash_timer -= delta
	
	# Audio fade out logic
	if dash_timer <= 0.3 and dash_audio.playing and dash_audio.volume_db == 0.0:
		var fade_out := create_tween()
		fade_out.tween_property(dash_audio, "volume_db", -40.0, 0.3)
		fade_out.finished.connect(func(): if dash_audio.playing: dash_audio.stop(); dash_audio.volume_db = 0.0)

	if dash_timer <= 0.0:
		state = STATE.IDLE
		velocity = Vector3.ZERO
	else:
		move_and_slide()

func execute_dash() -> void:
	if current_stamina < dash_stamina_cost: return
	
	current_stamina -= dash_stamina_cost
	state = STATE.DASH
	last_dash_time = Time.get_ticks_msec()
	
	dash_audio.pitch_scale = randf_range(0.87, 1.17)
	dash_audio.play()

	var charge_ratio = dash_charge_time / dash_max_charge_time
	var final_speed = lerp(dash_min_speed, dash_max_speed, charge_ratio)

	var input_dir = Input.get_vector("Left", "Right", "Fwd", "Bkwd")
	dash_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if dash_direction == Vector3.ZERO:
		dash_direction = -visuals.global_transform.basis.z.normalized()

	velocity = dash_direction * final_speed
	dash_timer = dash_duration
	start_camera_shake(0.6, dash_duration)
	handle_animations()

	# FOV Kick
	if current_fov_tween: current_fov_tween.kill()
	current_fov_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	current_fov_tween.tween_property(camera_node, "fov", dash_charge_fov + 10.0, 0.08)
	current_fov_tween.tween_property(camera_node, "fov", base_camera_fov, 0.4)

#endregion

#region Combat & Combo System

func handle_attack_input():
	if current_stamina < stamina_cost_p1: return
	
	if state == STATE.ATTACK:
		if can_queue_next_combo:
			is_attack_queued = true
			can_queue_next_combo = false 
	
	elif can_start_new_attack():
		current_stamina -= stamina_cost_p1
		state = STATE.ATTACK
		combo_step = 1
		is_attack_queued = false
		can_queue_next_combo = false
		set_anim("sword_combo_p1")

func can_start_new_attack() -> bool:
	var is_cooldown_ready = Time.get_ticks_msec() - last_attack_time >= attack_cooldown * 1000
	var is_in_valid_state = state in [STATE.IDLE, STATE.WALK, STATE.RUN]
	return is_cooldown_ready and is_in_valid_state

func handle_parrying():
	var now: float = Time.get_ticks_msec()
	if now - last_parry_time < parry_cooldown * 1000: return

	if Input.is_action_just_pressed("Parry") and can_i_parry:
		play_block_animation()
		can_i_parry = false
		
		if is_instance_valid(enemy_target) and global_position.distance_to(enemy_target.global_position) <= 3.0:
			if enemy_target.can_be_parried:
				enemy_target.parried()
				Global.frame_freeze(0, 0.2)
				start_camera_shake()
				parry_audio.play()
				enemy_target.give_damage = false
				last_parry_time = now
		
		await get_tree().create_timer(parry_cooldown).timeout
		can_i_parry = true

func play_block_animation():
	if state in [STATE.IDLE, STATE.WALK, STATE.RUN]:
		state = STATE.BLOCK
		set_anim("block")
		await get_tree().create_timer(0.25).timeout
		if state == STATE.BLOCK:
			state = STATE.IDLE

func take_damage(damage: float, knockback_dir: Vector3 = Vector3.ZERO, knockback_force: float = 8.0) -> void:
	if state == STATE.DEATH: return
	
	# Cancel States
	if state == STATE.DASH or state == STATE.DASH_CHARGE:
		cancel_charge()
		dash_timer = 0.0
		velocity = Vector3.ZERO
		dash_audio.stop()
	if state == STATE.ATTACK:
		is_attack_queued = false
		can_queue_next_combo = false

	state = STATE.HURT
	velocity = Vector3.ZERO

	if knockback_dir != Vector3.ZERO:
		velocity = knockback_dir.normalized() * knockback_force
		velocity.y = 2.0 

	start_camera_shake(0.1, 0.25)
	set_anim("hurt")
	await animation_player.animation_finished
	get_parent_node_3d().end_game()
	
	await get_tree().create_timer(0.5).timeout
	if state == STATE.HURT:
		state = STATE.IDLE

func give_damage():
	if enemy_target:
		enemy_target.take_damage(attack_damage)

func _on_area_3d_area_entered(area: Area3D) -> void:
	if enemy_target and (enemy_target.give_damage or Global.thunder_damage):
		take_damage(1, Vector3(10, 0, 90), 15)

#endregion

#region Animation Handling

func handle_animations() -> void:
	match state:
		STATE.IDLE:      set_anim("mixamo_com")
		STATE.WALK:      set_anim("walk")
		STATE.RUN:       set_anim("run")
		STATE.HURT:      set_anim("hurt")
		STATE.DEATH:     set_anim("death")
		STATE.DASH_CHARGE: set_anim("dash_charge")
		STATE.BLOCK:     set_anim("block")
		STATE.DASH:
			set_anim("dash_mid_end")
			return
	if state != STATE.ATTACK:
		pass
func set_anim(anim: String) -> void:
	if animation_player.current_animation != anim:
		animation_player.play(anim)

	# Handle Speed Scaling
	if anim in ["sword_combo_p1", "sword_combo_p2", "sword_combo_p3"]:
		animation_player.speed_scale = attack_speed_scale
	else:
		animation_player.speed_scale = 1.0

	combo_timer.stop()
	can_queue_next_combo = false

	# Setup Combo Windows
	if anim in ["sword_combo_p1", "sword_combo_p2", "sword_combo_p3"]:
		has_hit_once = false
		has_shaken_once = false 
		
		var current_scale = attack_speed_scale
		if anim == "sword_combo_p1":
			combo_timer.start(COMBO_P1_WINDOW / current_scale)
		elif anim == "sword_combo_p2":
			combo_timer.start(COMBO_P2_WINDOW / current_scale)
		elif anim == "sword_combo_p3":
			combo_timer.start(COMBO_P3_WINDOW / current_scale)

func _on_animation_player_animation_finished(anim_name):
	if (anim_name in ["sword_combo_p1", "sword_combo_p2", "sword_combo_p3"]):
		combo_timer.stop()
		can_queue_next_combo = false

		# --- STAMINA & COMBO CHAINING LOGIC ---
		if is_attack_queued:
			var has_stamina = current_stamina >= stamina_cost_combo
			
			if anim_name == "sword_combo_p1" and has_stamina:
				current_stamina -= stamina_cost_combo
				is_attack_queued = false
				combo_step = 2
				set_anim("sword_combo_p2")
				
			elif anim_name == "sword_combo_p2" and has_stamina:
				current_stamina -= stamina_cost_combo
				is_attack_queued = false
				combo_step = 3
				set_anim("sword_combo_p3")
				
			elif anim_name == "sword_combo_p3" and current_stamina >= stamina_cost_p1:
				current_stamina -= stamina_cost_p1
				is_attack_queued = false
				combo_step = 1
				set_anim("sword_combo_p1")
			else:
				reset_combo()
		else:
			reset_combo()

	elif anim_name == "block" and state == STATE.BLOCK:
		state = STATE.IDLE

func reset_combo():
	combo_step = 0
	is_attack_queued = false
	if state != STATE.DEATH and state != STATE.HURT:
		state = STATE.IDLE
	last_attack_time = Time.get_ticks_msec()

func _on_combo_timer_timeout():
	can_queue_next_combo = true

#endregion

#region Visual Effects & Juice

func tween_fov(target_fov: float, duration: float, transition_type: int):
	if current_fov_tween and current_fov_tween.is_running():
		current_fov_tween.kill()
	current_fov_tween = create_tween().set_trans(transition_type).set_ease(Tween.EASE_OUT)
	current_fov_tween.tween_property(camera_node, "fov", target_fov, duration)

func start_camera_shake(strength: float = 0.2, duration: float = 0.3):
	if strength > shake_max_strength:
		shake_max_strength = strength
	shake_max_duration = duration
	shake_timer = duration

func handle_camera_shake(delta: float):
	if not camera_node: return 
	
	if shake_timer > 0:
		shake_timer -= delta
		if shake_timer <= 0:
			shake_timer = 0.0
			camera_node.position = original_cam_pos
			shake_max_strength = 0.0 
		else:
			var decay_ratio = shake_timer / shake_max_duration
			var current_strength = shake_max_strength * (decay_ratio * decay_ratio)
			var offset = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * current_strength
			camera_node.position = original_cam_pos + offset
	elif camera_node.position != original_cam_pos:
		camera_node.position = original_cam_pos

func attack_connected():
	Global.frame_freeze(0.1, 0.2)
	start_camera_shake(0.15, 0.2)

func hit_or_miss_camera_shake():
	if is_attack_connected and not has_hit_once:
		Global.frame_freeze(0.1, 0.2)
		start_camera_shake(0.1, 0.1)
		give_damage()
		has_hit_once = true 
	elif not is_attack_connected and not has_shaken_once:
		start_camera_shake(0.01, 0.4)




func create_afterimage() -> void:
	if not visuals: return
	
	# 1. Duplicate only what's necessary
	var ghost: Node3D = visuals.duplicate(Node.DUPLICATE_USE_INSTANTIATION)
	ghost.global_transform = visuals.global_transform
	get_tree().current_scene.add_child(ghost)

	# 2. Optimization: Remove scripts/physics/logic from the ghost
	# We only want the visuals. This prevents the ghost from running code.
	_clean_ghost_logic(ghost)

	# 3. Handle Skeleton (Snapshot the pose)
	if visuals.has_node("Skeleton3D") and ghost.has_node("Skeleton3D"):
		var orig_skel: Skeleton3D = visuals.get_node("Skeleton3D")
		var ghost_skel: Skeleton3D = ghost.get_node("Skeleton3D")
		
		# Reset the ghost skeleton to prevent T-pose flicker before override takes effect
		for i in range(orig_skel.get_bone_count()):
			ghost_skel.set_bone_pose_position(i, orig_skel.get_bone_pose_position(i))
			ghost_skel.set_bone_pose_rotation(i, orig_skel.get_bone_pose_rotation(i))
			ghost_skel.set_bone_pose_scale(i, orig_skel.get_bone_pose_scale(i))
			
			# Force the global pose override
			ghost_skel.set_bone_global_pose_override(i, orig_skel.get_bone_global_pose(i), 1.0, true)

	if ghost.has_node("AnimationPlayer"):
		ghost.get_node("AnimationPlayer").stop()

	# 4. Apply Material Override (Much faster than per-surface iteration)
	var mesh_list: Array[MeshInstance3D] = []
	_find_meshes_recursively(ghost, mesh_list)

	if mesh_list.is_empty():
		ghost.queue_free()
		return

	# Create ONE unique material instance for this specific ghost event
	# Since base_ghost_material is ALREADY transparent, no shader compile stutter!
	var instance_mat = base_ghost_material.duplicate()
	instance_mat.albedo_color = afterimage_color
	
	# Optional: Copy the texture from the original player if you want the details
	# (Assumes the first mesh has the main texture)
	if not mesh_list.is_empty():
		var original_surface = mesh_list[0].get_active_material(0)
		if original_surface and original_surface is StandardMaterial3D:
			instance_mat.albedo_texture = original_surface.albedo_texture

	var ghost_tween: Tween = create_tween()
	
	for mesh: MeshInstance3D in mesh_list:
		# Use material_override! It overrides all surfaces at once.
		# This is much cheaper than looping through every surface.
		mesh.material_override = instance_mat
	
	# Tween the alpha of the SINGLE material instance
	var end_color: Color = afterimage_color
	end_color.a = 0.0
	
	ghost_tween.tween_property(instance_mat, "albedo_color", end_color, afterimage_fade_time)
	ghost_tween.finished.connect(func(): if is_instance_valid(ghost): ghost.queue_free())

func _find_meshes_recursively(node: Node, mesh_list: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			mesh_list.append(child)
		_find_meshes_recursively(child, mesh_list)

func _clean_ghost_logic(node: Node):
	# Strip scripts from the duplicate so it doesn't try to run physics or input
	node.set_script(null)
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	for child in node.get_children():
		_clean_ghost_logic(child)

#endregion

#region Getters

func get_state(): return state
func get_stamina() -> float: return current_stamina
func get_max_stamina() -> float: return max_stamina

#endregion

func play_footstep():
	var sfx_array:=[STONE_CHAIN_WALK_1,STONE_CHAIN_WALK_3]
	footstep.stream = sfx_array.pick_random()
	footstep.pitch_scale = randf_range(0.8, 1.2)
	footstep.play()
	var chain_clanks:=[CHAIN_CLANK_1, CHAIN_CLANK_2]
	$footstep2.stream = chain_clanks.pick_random()
	$footstep2.pitch_scale = randf_range(0.8, 1.2)
	$footstep2.play()
