extends CharacterBody3D

@export var mouse_sensitivity_x: float = 0.5
@export var mouse_sensitivity_y: float = 0.5
@export var SPEED: float = 3.5
@export var RUN_SPEED: float = 6.5

@onready var visuals: Node3D = $visuals
@onready var camera_mount: Node3D = $"Camera Mount"
@onready var animation_player: AnimationPlayer = $visuals/AnimationPlayer

const JUMP_VELOCITY: float = 4.5
var GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity")

enum STATE { IDLE, WALK, RUN, ATTACK, HURT, DEATH }
var state: STATE = STATE.IDLE


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Horizontal rotation (Y-axis)
		rotate_y(deg_to_rad(-event.relative.x) * mouse_sensitivity_x)
		visuals.rotate_y(deg_to_rad(event.relative.x) * mouse_sensitivity_x)

		# Vertical rotation (X-axis) with clamping
		camera_mount.rotate_x(deg_to_rad(-event.relative.y) * mouse_sensitivity_y)

		# Clamp vertical look (limit how far player can look up/down)
		var rotation_x = camera_mount.rotation_degrees.x
		rotation_x = clamp(rotation_x, -50, 50) # adjust limits as needed
		camera_mount.rotation_degrees.x = rotation_x


func _physics_process(delta: float) -> void:
	# --- GRAVITY ---
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# --- JUMP ---
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# --- MOVEMENT INPUT ---
	var input_dir: Vector2 = Input.get_vector("Left", "Right", "Fwd", "Bkwd")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# --- DETERMINE STATE ---
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
	if direction != Vector3.ZERO:
		visuals.look_at(position + direction)
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# --- ANIMATION HANDLER ---
	handle_animations()


# -------------------------------
# HELPER FUNCTIONS
# -------------------------------

func can_move() -> bool:
	return state != STATE.HURT and state != STATE.DEATH


func handle_animations() -> void:
	match state:
		STATE.IDLE:
			play_anim_if_not("mixamo_com") # idle
		STATE.WALK:
			play_anim_if_not("walk")
		STATE.RUN:
			play_anim_if_not("run")
		STATE.HURT:
			play_anim_if_not("hurt")
		STATE.DEATH:
			play_anim_if_not("death")


# Avoid restarting the same animation every frame
func play_anim_if_not(anim_name: String) -> void:
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)
