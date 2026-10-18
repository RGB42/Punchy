class_name FigureAnimator
extends RefCounted
## Drives a rigid action figure (one Node3D per joint, see build_figure.py).
##
## Two layers: a continuously smoothed *base* pose the owner sets every frame
## (locomotion, hanging, gliding) and an optional *clip* on top (attacks, landing,
## flips) that blends in, runs its keys, and fades back to the base.
## A clip is an Array of keys: {"pose": Dictionary, "time": float, "ease": float}.
## "time" is how long it takes to reach that pose from the previous key; "ease"
## is passed to ease() (0.3 = snappy start, 2.0 = slow start). A key with
## "hold": true keeps the clip on its last pose until stop() is called.

const PARTS := [
	"hips", "abdomen", "chest", "head",
	"upper_arm_l", "lower_arm_l", "hand_l", "upper_arm_r", "lower_arm_r", "hand_r",
	"thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r",
]

var joints := {}  # part -> Node3D
var base_rate := 16.0  # how fast the base pose follows its target, 1/s

var _hips_rest := Vector3.ZERO
var _base := {}  # part -> Quaternion (smoothed)
var _base_root := Vector3.ZERO
var _target := {}  # part -> Quaternion
var _target_root := Vector3.ZERO

var _clip: Array = []
var _clip_t := 0.0
var _clip_len := 0.0
var _clip_start := {}  # part -> Quaternion, the pose when the clip began
var _clip_start_root := Vector3.ZERO
var _weight := 0.0
var _fade_out := 0.15
var _fading := false
var _final := {}  # part -> Quaternion, last applied
var _final_root := Vector3.ZERO


func _init(figure: Node3D) -> void:
	for p in PARTS:
		var n := figure.find_child(p, true, false) as Node3D
		assert(n != null, "figure has no part %s" % p)
		joints[p] = n
		_base[p] = Quaternion.IDENTITY
		_target[p] = Quaternion.IDENTITY
		_final[p] = Quaternion.IDENTITY
	_hips_rest = joints["hips"].position


static func q(deg: Vector3) -> Quaternion:
	return Quaternion.from_euler(deg * (PI / 180.0))


## Target for the base layer. Parts the pose leaves out keep their last target.
func set_base(pose: Dictionary, rate := 16.0) -> void:
	base_rate = rate
	for k in pose:
		if k == "root":
			_target_root = pose[k]
		elif _target.has(k):
			_target[k] = q(pose[k])


## Jump the base straight to a pose (no smoothing), e.g. when spawning.
func snap_base(pose: Dictionary) -> void:
	set_base(pose)
	for p in PARTS:
		_base[p] = _target[p]
	_base_root = _target_root


func play(keys: Array, fade_out := 0.15) -> void:
	_clip = keys
	_clip_t = 0.0
	_clip_len = 0.0
	for k in keys:
		_clip_len += float(k["time"])
	_clip_start = _final.duplicate()
	_clip_start_root = _final_root
	_weight = 1.0
	_fade_out = fade_out
	_fading = false


func stop(fade := 0.15) -> void:
	if _clip.is_empty():
		return
	_fade_out = max(fade, 0.001)
	_fading = true


func is_playing() -> bool:
	return not _clip.is_empty() and not _fading


func update(delta: float) -> void:
	var k := 1.0 - exp(-base_rate * delta)
	for p in PARTS:
		_base[p] = (_base[p] as Quaternion).slerp(_target[p], k)
	_base_root = _base_root.lerp(_target_root, k)

	var clip_pose := {}
	var clip_root := _base_root
	if not _clip.is_empty():
		_clip_t += delta
		var held: bool = _clip.back().get("hold", false)
		if _clip_t >= _clip_len and not held:
			_fading = true
		if _fading:
			_weight -= delta / _fade_out
			if _weight <= 0.0:
				_clip = []
				_weight = 0.0
		if not _clip.is_empty():
			clip_root = _sample_clip(clip_pose)

	for p in PARTS:
		var r: Quaternion = _base[p]
		if clip_pose.has(p):
			r = r.slerp(clip_pose[p], _weight)
		_final[p] = r
		(joints[p] as Node3D).quaternion = r
	_final_root = _base_root.lerp(clip_root, _weight)
	(joints["hips"] as Node3D).position = _hips_rest + _final_root


## Walks the keys up to the current time. Parts a key leaves out carry over from
## the previous key, or follow the base if no key has named them yet.
func _sample_clip(out: Dictionary) -> Vector3:
	var prev := {}
	var prev_root := _clip_start_root
	for p in PARTS:
		prev[p] = _clip_start[p]
	var t := minf(_clip_t, _clip_len)
	var named := {}
	var root_named := false
	for key in _clip:
		var dur: float = key["time"]
		var pose: Dictionary = key["pose"]
		var f := 1.0 if dur <= 0.0 else clampf(t / dur, 0.0, 1.0)
		f = ease(f, key.get("ease", 1.0))
		var nxt := prev.duplicate()
		for part in pose:
			if part == "root":
				root_named = true
				continue
			named[part] = true
			nxt[part] = (prev[part] as Quaternion).slerp(q(pose[part]), f)
		var nroot: Vector3 = prev_root.lerp(pose.get("root", prev_root), f)
		prev = nxt
		prev_root = nroot
		t -= dur
		if t <= 0.0:
			break
	for part in named:
		out[part] = prev[part]
	return prev_root if root_named else _base_root
