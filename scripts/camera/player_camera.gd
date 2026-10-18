class_name PlayerCamera
extends Node3D
## Third-person orbit camera. Mouse / right stick orbit, lazy recentre behind the
## figure while running, collision with the level only, and trauma-based shake
## (Game.trauma) on real time so it keeps shaking through hitstop.

@export var target_path: NodePath
@export var distance := 4.6
@export var height := 1.7

const MOUSE_SENS := 0.0025
const PAD_SENS := 2.8
const PITCH_MIN := -1.25
const PITCH_MAX := 0.7
const RECENTER_DELAY := 1.4
const SHAKE_MAX_OFFSET := 0.45
const SHAKE_MAX_ROLL := 0.06

var target: Node3D
var pitch := -0.3
var arm: SpringArm3D
var cam: Camera3D
var _idle_look := 0.0
var _noise := FastNoiseLite.new()
var _follow_y := 0.0


func _ready() -> void:
	top_level = true
	target = get_node(target_path)
	if "camera" in target:
		target.camera = self
	arm = SpringArm3D.new()
	arm.collision_mask = 1
	var s := SphereShape3D.new()
	s.radius = 0.3
	arm.shape = s
	arm.spring_length = distance
	arm.margin = 0.2
	add_child(arm)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 600.0
	arm.add_child(cam)
	cam.make_current()
	global_position = target.global_position + Vector3.UP * height
	_follow_y = global_position.y
	rotation = Vector3(pitch, target.rotation.y, 0)
	_noise.frequency = 1.0
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
		_idle_look = 0.0
	elif event is InputEventMouseButton and event.pressed and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.001)
	var look := Input.get_vector("look_left", "look_right", "look_down", "look_up")
	if look.length() > 0.05:
		rotation.y -= look.x * PAD_SENS * real
		pitch = clampf(pitch + look.y * PAD_SENS * 0.7 * real, PITCH_MIN, PITCH_MAX)
		_idle_look = 0.0
	_idle_look += real

	var vel: Vector3 = target.velocity if "velocity" in target else Vector3.ZERO
	var h := Vector3(vel.x, 0, vel.z)
	if _idle_look > RECENTER_DELAY and h.length() > 3.0:
		var behind := atan2(-h.x, -h.z)
		rotation.y = lerp_angle(rotation.y, behind, 1.0 - exp(-1.2 * delta))

	var goal := target.global_position + Vector3.UP * height
	# Vertical follow is softer so jumps do not yank the view.
	_follow_y = lerpf(_follow_y, goal.y, 1.0 - exp(-7.0 * delta))
	var xz := Vector2(global_position.x, global_position.z).lerp(Vector2(goal.x, goal.z), 1.0 - exp(-16.0 * delta))
	global_position = Vector3(xz.x, _follow_y, xz.y)
	arm.spring_length = lerpf(arm.spring_length, distance, 1.0 - exp(-4.0 * delta))

	Game.fov_kick = move_toward(Game.fov_kick, 0.0, real * 30.0)
	cam.fov = 72.0 - Game.fov_kick
	Game.trauma = maxf(0.0, Game.trauma - real * 1.5)
	var s := Game.trauma * Game.trauma
	var t := Time.get_ticks_msec() * 0.001 * 45.0
	cam.h_offset = SHAKE_MAX_OFFSET * s * _noise.get_noise_2d(t, 0.0)
	cam.v_offset = SHAKE_MAX_OFFSET * s * _noise.get_noise_2d(t, 100.0)
	rotation = Vector3(pitch, rotation.y, SHAKE_MAX_ROLL * s * _noise.get_noise_2d(t, 200.0))
