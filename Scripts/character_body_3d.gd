extends CharacterBody3D

# --- Constants ---
const SPEED := 5.0
const ACCELERATION := 10.0
const DECELERATION := 12.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.002

# --- Node references ---
@onready var head: Node3D = $Head
@onready var camera_3d: Camera3D = $Head/Camera3D

# --- Variables ---
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var input_dir: Vector2
var direction: Vector3

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Rotate player horizontally
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		# Rotate camera vertically (clamped)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation_degrees.x = clamp(head.rotation_degrees.x, -75, 75)

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	handle_jump()
	handle_movement(delta)
	move_and_slide()

# --- Custom Functions ---

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0:
		velocity.y = 0  # Prevent downward velocity accumulation

func handle_jump() -> void:
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func handle_movement(delta: float) -> void:
	input_dir = Input.get_vector("Left", "Right", "Fwd", "Bkwd")
	direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_velocity = Vector3.ZERO
	if direction != Vector3.ZERO:
		target_velocity.x = direction.x * SPEED
		target_velocity.z = direction.z * SPEED

	# Smooth acceleration and deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, DECELERATION * delta)
