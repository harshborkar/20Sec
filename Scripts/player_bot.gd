extends CharacterBody3D

@export var mouse_sensitivity_x: float = 0.5
@export var mouse_sensitivity_y: float = 0.5
@export_range(0, 90, 1) var target_vertical_nudge_limit: float = 20.0
@export_range(0, 90, 1) var target_horizontal_nudge_limit: float = 45.0
@export var SPEED: float = 3.5
@export var RUN_SPEED: float = 6.5
@onready var gpu_trail_3d: GPUTrail3D = $visuals/Skeleton3D/GPUTrail3D

@onready var visuals: Node3D = $visuals
@onready var camera_mount: Node3D = $"Camera Mount"
@onready var animation_player: AnimationPlayer = $visuals/AnimationPlayer

const JUMP_VELOCITY: float = 4.5

enum STATE { IDLE, WALK, RUN,DASH_CHARGE, DASH, ATTACK, HURT, DEATH }

var state: STATE = STATE.IDLE
var GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var dash_charge_time:float= 0.0
var is_targeting: bool = false#targeting

@export var targeting_speed: float = 5.0#targeting
@export var DASH_MAX_CHARGE_TIME: float = 1.5
@export var DASH_MIN_SPEED: float = 10.0
@export var DASH_MAX_SPEED: float = 25.0
@export var DASH_DURATION: float = 0.3
@export var ENEMY:CharacterBody3D
var dash_direction: Vector3 = Vector3.ZERO
var dash_timer: float = 0.0
var is_charging: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide_trails()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		
		if is_targeting:
			# --- TARGETING MOUSE LOGIC ---
			# The mouse ONLY rotates the camera_mount for a "nudge"
			
			# Horizontal rotation (Y-axis)
			camera_mount.rotate_y(deg_to_rad(-event.relative.x) * mouse_sensitivity_x)
			
			# Vertical rotation (X-axis)
			camera_mount.rotate_x(deg_to_rad(-event.relative.y) * mouse_sensitivity_y)

			# Clamp rotations
			var new_rotation = camera_mount.rotation_degrees
			new_rotation.x = clamp(new_rotation.x, -target_vertical_nudge_limit, target_vertical_nudge_limit)
			new_rotation.y= clamp(new_rotation.y, -target_horizontal_nudge_limit, target_horizontal_nudge_limit)
			new_rotation.z =0
			camera_mount.rotation_degrees = new_rotation
			

		else:
			# --- FREE-LOOK MOUSE LOGIC (Your original code) ---
			
			# Horizontal rotation (Y-axis) on the player body
			rotate_y(deg_to_rad(-event.relative.x) * mouse_sensitivity_x)
			visuals.rotate_y(deg_to_rad(event.relative.x) * mouse_sensitivity_x)

			# Vertical rotation (X-axis) on the camera mount
			camera_mount.rotate_x(deg_to_rad(-event.relative.y) * mouse_sensitivity_y)

			# Clamp vertical look (limit how far player can look up/down)
			var rotation_x = camera_mount.rotation_degrees.x
			rotation_x = clamp(rotation_x, -10, 20) # (Your original free-look limits)
			
			# Ensure horizontal and roll are zero when not targeting
			camera_mount.rotation_degrees = Vector3(rotation_x, 0, 0)

	
	if event.is_action_pressed("Target"):
		is_targeting = !is_targeting
		
		if is_targeting:
			# <--- JUST STARTED TARGETING ---
			# Reset camera mount's rotation, but keep its vertical (X) angle
			# This snaps the camera back to center when you lock on.
			var current_cam_rot = camera_mount.rotation_degrees
			camera_mount.rotation_degrees = Vector3(current_cam_rot.x, 0, 0)
		else:
			# <--- JUST STOPPED TARGETING ---
			# Reset visuals
			visuals.transform.basis = Basis()
			
			# Reset camera mount's rotation, but keep its vertical (X) angle
			var current_cam_rot = camera_mount.rotation_degrees
			camera_mount.rotation_degrees = Vector3(current_cam_rot.x, 0, 0)

func show_trails() -> void:
	if gpu_trail_3d:
		gpu_trail_3d.visible = true
		gpu_trail_3d.emitting = true


func hide_trails() -> void:
	if gpu_trail_3d:
		gpu_trail_3d.emitting = false
		gpu_trail_3d.visible = false
	
func _physics_process(delta: float) -> void:
	
	# --- GRAVITY ---
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# --- JUMP ---
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# --- DASH CHARGE START ---
	# ... (No changes to dash logic) ...
	if Input.is_action_just_pressed("Dash") and can_move():
		state = STATE.DASH_CHARGE
		is_charging = true
		dash_charge_time = 0.0

	# --- DASH CHARGE HOLD ---
	if is_charging and Input.is_action_pressed("Dash"):
		dash_charge_time = clamp(dash_charge_time + delta, 0, DASH_MAX_CHARGE_TIME)

	# --- DASH CHARGE RELEASE (Trigger Dash) ---
	if is_charging and Input.is_action_just_released("Dash"):
		is_charging = false
		start_dash()

	# --- DASH ACTIVE ---
	if state == STATE.DASH:
		dash_timer -= delta
		if dash_timer <= 0:
			state = STATE.IDLE
			velocity = Vector3.ZERO
		else:
			# continue moving in dash direction
			move_and_slide()
			return  # skip normal movement during dash

	# --- TARGETING LOGIC (ROTATION) ---
	# <--- NEW BLOCK START ---
	if is_targeting:
		if is_instance_valid(ENEMY):
			# 1. Rotate the main CharacterBody (and thus the camera)
			var target_pos = ENEMY.global_position
			var current_pos = global_position
			
			# We only care about horizontal rotation, so we use the player's Y level
			var look_at_pos = Vector3(target_pos.x, current_pos.y, target_pos.z)
			
			# Get the desired rotation basis
			var target_basis = transform.looking_at(look_at_pos, Vector3.UP).basis
			
			# Smoothly interpolate the player's root rotation
			transform.basis = transform.basis.slerp(target_basis, delta * targeting_speed)
			
			# 2. Rotate the 'visuals' node
			# We slerp its basis back to identity (Basis())
			# This makes it face the same direction as its parent (the root node),
			# which is now facing the enemy.
			visuals.transform.basis = visuals.transform.basis.slerp(Basis(), delta * targeting_speed)

		else:
			# If the ENEMY is invalid (e.g., null or freed), stop targeting
			is_targeting = false
	# <--- NEW BLOCK END ---

	# --- NORMAL MOVEMENT ---
	var input_dir: Vector2 = Input.get_vector("Left", "Right", "Fwd", "Bkwd")
	# This line works for both modes:
	# - Free: uses camera direction (from mouse)
	# - Target: uses camera direction (from looking at enemy)
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_running := Input.is_action_pressed("Sprint")
	var current_speed := SPEED

	if can_move():
		if direction != Vector3.ZERO:
			if is_running:
				state = STATE.RUN
				current_speed = RUN_SPEED
			else:
				state = STATE.WALK
		else:
			state = STATE.IDLE

	# --- APPLY MOVEMENT ---
	if direction != Vector3.ZERO and can_move():
		
		# <--- MODIFIED LINE ---
		# Only let visuals face movement direction if NOT targeting
		if not is_targeting:
			visuals.look_at(position + direction)
		# <--- END MODIFIED LINE ---
			
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# --- ANIMATION HANDLER ---
	handle_animations()



# ---  HELPER FUNCTIONS ---
func can_move() -> bool:
	return state != STATE.HURT and state != STATE.DEATH and state != STATE.DASH_CHARGE


func start_dash():
	state = STATE.DASH
	var charge_ratio = dash_charge_time / DASH_MAX_CHARGE_TIME
	var dash_speed = lerp(DASH_MIN_SPEED, DASH_MAX_SPEED, charge_ratio)

	# Forward direction based on where player is facing
	dash_direction = -visuals.global_transform.basis.z.normalized()

	velocity = dash_direction * dash_speed
	dash_timer = DASH_DURATION

	
	handle_animations()
	#get time when action is pressed and released max time is 1.5  secs after that the speed or distencc e of the dash wont increase

func handle_animations() -> void:
	match state:
		STATE.IDLE:
			play_anim_if_not("mixamo_com") # idle
			hide_trails()
		STATE.WALK:
			play_anim_if_not("walk")
			hide_trails()
		STATE.RUN:
			play_anim_if_not("run")
			hide_trails()
		STATE.HURT:
			play_anim_if_not("hurt")
			hide_trails()
		STATE.DEATH:
			play_anim_if_not("death")
			hide_trails()
		STATE.DASH_CHARGE:
			play_anim_if_not("dash_charge")
			hide_trails()
		STATE.DASH:
			play_anim_if_not("dash_mid_end")
			show_trails()


# Avoid restarting the same animation every frame
func play_anim_if_not(anim_name: String) -> void:
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)
