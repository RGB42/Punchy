class_name Poses
## Key poses for the rigid action-figure body, in Node3D.rotation_degrees per part.
##
## Conventions (figure faces -Z, Godot euler YXZ):
##  hanging limbs (arms, thighs, shins): +X swings forward, -X back
##  upright parts (chest, head):         +X tilts back (look up), -X leans forward
##  right side +Z / left side -Z moves the limb outward
## "root" is a position offset of the hips (crouch, bob).
## Poses only name the parts they move; the rest follow the base pose.

const IDLE := {
	"root": Vector3.ZERO,
	"hips": Vector3.ZERO, "abdomen": Vector3(-3, 0, 0), "chest": Vector3(2, 0, 0), "head": Vector3(-2, 0, 0),
	"upper_arm_r": Vector3(6, 0, 14), "lower_arm_r": Vector3(28, 0, 0), "hand_r": Vector3(0, 0, 0),
	"upper_arm_l": Vector3(6, 0, -14), "lower_arm_l": Vector3(28, 0, 0), "hand_l": Vector3(0, 0, 0),
	"thigh_r": Vector3(2, 0, 5), "shin_r": Vector3(-6, 0, 0), "foot_r": Vector3(4, 0, -5),
	"thigh_l": Vector3(-2, 0, -5), "shin_l": Vector3(-4, 0, 0), "foot_l": Vector3(4, 0, 5),
}

const JUMP_UP := {
	"root": Vector3.ZERO, "chest": Vector3(-6, 0, 0), "head": Vector3(8, 0, 0),
	"thigh_r": Vector3(65, 0, 4), "shin_r": Vector3(-85, 0, 0), "foot_r": Vector3(20, 0, 0),
	"thigh_l": Vector3(-12, 0, -4), "shin_l": Vector3(-35, 0, 0), "foot_l": Vector3(-10, 0, 0),
	"upper_arm_r": Vector3(-35, 0, 22), "lower_arm_r": Vector3(35, 0, 0),
	"upper_arm_l": Vector3(55, 0, -15), "lower_arm_l": Vector3(60, 0, 0),
}

const FALL := {
	"root": Vector3.ZERO, "chest": Vector3(4, 0, 0), "head": Vector3(-6, 0, 0),
	"thigh_r": Vector3(25, 0, 10), "shin_r": Vector3(-40, 0, 0), "foot_r": Vector3(10, 0, 0),
	"thigh_l": Vector3(-8, 0, -10), "shin_l": Vector3(-25, 0, 0), "foot_l": Vector3(0, 0, 0),
	"upper_arm_r": Vector3(15, 0, 65), "lower_arm_r": Vector3(30, 0, 0),
	"upper_arm_l": Vector3(15, 0, -65), "lower_arm_l": Vector3(30, 0, 0),
}

const TUCK := {
	"root": Vector3(0, 0.2, 0), "chest": Vector3(-25, 0, 0), "abdomen": Vector3(-15, 0, 0), "head": Vector3(-10, 0, 0),
	"thigh_r": Vector3(110, 0, 8), "shin_r": Vector3(-125, 0, 0), "thigh_l": Vector3(105, 0, -8), "shin_l": Vector3(-120, 0, 0),
	"upper_arm_r": Vector3(45, 0, 15), "lower_arm_r": Vector3(95, 0, 0),
	"upper_arm_l": Vector3(45, 0, -15), "lower_arm_l": Vector3(95, 0, 0),
}

## The body is pitched forward by the player while gliding; limbs trail behind.
const GLIDE := {
	"root": Vector3.ZERO, "chest": Vector3(10, 0, 0), "head": Vector3(30, 0, 0), "abdomen": Vector3(5, 0, 0),
	"upper_arm_r": Vector3(-20, 0, 75), "lower_arm_r": Vector3(15, 0, 0),
	"upper_arm_l": Vector3(-20, 0, -75), "lower_arm_l": Vector3(15, 0, 0),
	"thigh_r": Vector3(-10, 0, 6), "shin_r": Vector3(-25, 0, 0), "foot_r": Vector3(-30, 0, 0),
	"thigh_l": Vector3(-14, 0, -6), "shin_l": Vector3(-30, 0, 0), "foot_l": Vector3(-30, 0, 0),
}

## Superhero dash: body pitched ~60 deg by the player, right fist leads.
const DASH := {
	"root": Vector3.ZERO, "head": Vector3(35, 0, 0), "chest": Vector3(5, 0, 0),
	"upper_arm_r": Vector3(150, 0, 5), "lower_arm_r": Vector3(5, 0, 0), "hand_r": Vector3(0, 0, 0),
	"upper_arm_l": Vector3(-35, 0, -20), "lower_arm_l": Vector3(20, 0, 0),
	"thigh_r": Vector3(-15, 0, 4), "shin_r": Vector3(-35, 0, 0), "foot_r": Vector3(-35, 0, 0),
	"thigh_l": Vector3(5, 0, -4), "shin_l": Vector3(-60, 0, 0), "foot_l": Vector3(-35, 0, 0),
}

const ROCKET := {
	"root": Vector3.ZERO, "head": Vector3(15, 0, 0), "chest": Vector3(6, 0, 0),
	"upper_arm_r": Vector3(170, 0, 10), "lower_arm_r": Vector3(0, 0, 0),
	"upper_arm_l": Vector3(-10, 0, -35), "lower_arm_l": Vector3(20, 0, 0),
	"thigh_r": Vector3(-5, 0, 3), "shin_r": Vector3(-15, 0, 0), "foot_r": Vector3(-40, 0, 0),
	"thigh_l": Vector3(30, 0, -3), "shin_l": Vector3(-80, 0, 0), "foot_l": Vector3(-30, 0, 0),
}

const LEDGE_HANG := {
	"root": Vector3.ZERO, "head": Vector3(18, 0, 0), "chest": Vector3(3, 0, 0),
	"upper_arm_r": Vector3(172, 0, 12), "lower_arm_r": Vector3(12, 0, 0), "hand_r": Vector3(-20, 0, 0),
	"upper_arm_l": Vector3(172, 0, -12), "lower_arm_l": Vector3(12, 0, 0), "hand_l": Vector3(-20, 0, 0),
	"thigh_r": Vector3(8, 0, 4), "shin_r": Vector3(-15, 0, 0), "foot_r": Vector3(-10, 0, 0),
	"thigh_l": Vector3(15, 0, -4), "shin_l": Vector3(-30, 0, 0), "foot_l": Vector3(-10, 0, 0),
}

const CLIMB_UP := {
	"root": Vector3(0, -0.1, 0), "chest": Vector3(-35, 0, 0), "head": Vector3(10, 0, 0),
	"upper_arm_r": Vector3(40, 0, 25), "lower_arm_r": Vector3(80, 0, 0),
	"upper_arm_l": Vector3(40, 0, -25), "lower_arm_l": Vector3(80, 0, 0),
	"thigh_r": Vector3(90, 0, 5), "shin_r": Vector3(-110, 0, 0),
	"thigh_l": Vector3(20, 0, -5), "shin_l": Vector3(-60, 0, 0),
}

const GRAPPLE := {
	"root": Vector3.ZERO, "head": Vector3(20, 0, 0), "chest": Vector3(6, 0, 0),
	"upper_arm_r": Vector3(165, 0, 8), "lower_arm_r": Vector3(5, 0, 0),
	"upper_arm_l": Vector3(20, 0, -40), "lower_arm_l": Vector3(45, 0, 0),
	"thigh_r": Vector3(10, 0, 4), "shin_r": Vector3(-30, 0, 0), "foot_r": Vector3(-30, 0, 0),
	"thigh_l": Vector3(35, 0, -4), "shin_l": Vector3(-70, 0, 0), "foot_l": Vector3(-30, 0, 0),
}

const SWING := {
	"root": Vector3.ZERO, "head": Vector3(10, 0, 0),
	"upper_arm_r": Vector3(175, 0, 2), "lower_arm_r": Vector3(0, 0, 0),
	"upper_arm_l": Vector3(168, 0, -4), "lower_arm_l": Vector3(8, 0, 0),
	"thigh_r": Vector3(15, 0, 2), "shin_r": Vector3(-20, 0, 0),
	"thigh_l": Vector3(20, 0, -2), "shin_l": Vector3(-25, 0, 0),
}

const LAND := {
	"root": Vector3(0, -0.3, 0), "abdomen": Vector3(-12, 0, 0), "chest": Vector3(-15, 0, 0), "head": Vector3(15, 0, 0),
	"thigh_r": Vector3(60, 0, 10), "shin_r": Vector3(-100, 0, 0), "foot_r": Vector3(40, 0, 0),
	"thigh_l": Vector3(25, 0, -10), "shin_l": Vector3(-85, 0, 0), "foot_l": Vector3(55, 0, 0),
	"upper_arm_r": Vector3(25, 0, 30), "lower_arm_r": Vector3(40, 0, 0),
	"upper_arm_l": Vector3(15, 0, -40), "lower_arm_l": Vector3(30, 0, 0),
}


static func run(phase: float, amount: float) -> Dictionary:
	var s := sin(phase)
	var c := cos(phase)
	var a := amount
	var p := {
		"root": Vector3(0, (-0.07 * absf(s) + 0.03) * a, 0),
		"hips": Vector3(0, -7 * s * a, 0),
		"abdomen": Vector3(-6 * a, 0, 0),
		"chest": Vector3(-8 * a, 12 * s * a, 0),
		"head": Vector3(10 * a, -10 * s * a, 0),
		"thigh_r": Vector3((50 * s + 8) * a, 0, 4),
		"shin_r": Vector3(-(18 + 75 * maxf(0.0, c)) * a, 0, 0),
		"foot_r": Vector3(15 * a * maxf(0.0, c), 0, 0),
		"thigh_l": Vector3((-50 * s + 8) * a, 0, -4),
		"shin_l": Vector3(-(18 + 75 * maxf(0.0, -c)) * a, 0, 0),
		"foot_l": Vector3(15 * a * maxf(0.0, -c), 0, 0),
		"upper_arm_r": Vector3(-55 * s * a + 6, 0, 14 - 4 * a),
		"lower_arm_r": Vector3(28 + 55 * a, 0, 0),
		"upper_arm_l": Vector3(55 * s * a + 6, 0, -14 + 4 * a),
		"lower_arm_l": Vector3(28 + 55 * a, 0, 0),
	}
	return p


static func climb(phase: float) -> Dictionary:
	var s := sin(phase)
	return {
		"root": Vector3.ZERO, "head": Vector3(20, 0, 0), "chest": Vector3(-5, 0, 0),
		"upper_arm_r": Vector3(140 + 30 * s, 0, 18), "lower_arm_r": Vector3(45 - 30 * s, 0, 0),
		"upper_arm_l": Vector3(140 - 30 * s, 0, -18), "lower_arm_l": Vector3(45 + 30 * s, 0, 0),
		"thigh_r": Vector3(45 - 30 * s, 0, 12), "shin_r": Vector3(-70 + 20 * s, 0, 0),
		"thigh_l": Vector3(45 + 30 * s, 0, -12), "shin_l": Vector3(-70 - 20 * s, 0, 0),
	}


static func breathe(t: float) -> Dictionary:
	var p := IDLE.duplicate()
	var b := sin(t * 2.2)
	p["chest"] = IDLE["chest"] + Vector3(2.5 * b, 0, 0)
	p["upper_arm_r"] = IDLE["upper_arm_r"] + Vector3(0, 0, 2 * b)
	p["upper_arm_l"] = IDLE["upper_arm_l"] - Vector3(0, 0, 2 * b)
	p["root"] = Vector3(0, -0.01 * (b + 1.0), 0)
	return p


## Left/right swapped and mirrored: authoring a right-handed punch gives the left one.
static func mirror(pose: Dictionary) -> Dictionary:
	var out := {}
	for k in pose:
		var v: Vector3 = pose[k]
		var name: String = k
		if name.ends_with("_r"):
			name = name.trim_suffix("_r") + "_l"
		elif name.ends_with("_l"):
			name = name.trim_suffix("_l") + "_r"
		out[name] = Vector3(-v.x, v.y, v.z) if k == "root" else Vector3(v.x, -v.y, -v.z)
	return out
