class_name Moves
## Every player attack: timing, damage, feel, and the poses that sell it, in one
## row so animation and hit timing cannot drift apart.
##
##  windup   s from start until the hit lands (the lunge closes distance in it)
##  active   s the strike pose holds after the hit
##  recover  s before control returns; a buffered attack cancels it
##  damage, knock (horizontal impulse), launch (vertical impulse)
##  hitstop  s of frozen world on impact, shake = camera trauma, kick = FOV punch
##  reach    max distance from the target at the moment of impact
##  radius   > 0: also hits every enemy within this radius of the impact point
##  breaks_guard: goes through shields

const _GUARD_L := {"upper_arm_l": Vector3(60, 0, -15), "lower_arm_l": Vector3(105, 0, 0)}
const _GUARD_R := {"upper_arm_r": Vector3(60, 0, 15), "lower_arm_r": Vector3(105, 0, 0)}

const JAB_WIND := {
	"root": Vector3(0, -0.12, 0), "chest": Vector3(0, -28, 0), "abdomen": Vector3(0, -8, 0), "head": Vector3(0, 25, 0),
	"upper_arm_r": Vector3(-30, 0, 30), "lower_arm_r": Vector3(120, 0, 0),
	"upper_arm_l": Vector3(60, 0, -15), "lower_arm_l": Vector3(105, 0, 0),
	"thigh_l": Vector3(30, 0, -6), "shin_l": Vector3(-45, 0, 0), "thigh_r": Vector3(-15, 0, 6), "shin_r": Vector3(-25, 0, 0),
}
const JAB_HIT := {
	"root": Vector3(0, -0.2, 0), "chest": Vector3(-10, 38, 0), "abdomen": Vector3(-4, 12, 0), "head": Vector3(-4, -40, 0),
	"upper_arm_r": Vector3(92, -38, 0), "lower_arm_r": Vector3(4, 0, 0), "hand_r": Vector3(0, 0, 0),
	"upper_arm_l": Vector3(35, 0, -25), "lower_arm_l": Vector3(115, 0, 0),
	"thigh_l": Vector3(48, 0, -6), "shin_l": Vector3(-55, 0, 0), "foot_l": Vector3(10, 0, 0),
	"thigh_r": Vector3(-28, 0, 6), "shin_r": Vector3(-20, 0, 0), "foot_r": Vector3(20, 0, 0),
}

const KICK_WIND := {
	"root": Vector3(0, -0.08, 0), "chest": Vector3(-5, 30, 0), "head": Vector3(0, -25, 0),
	"thigh_r": Vector3(85, 0, 10), "shin_r": Vector3(-120, 0, 0), "foot_r": Vector3(30, 0, 0),
	"thigh_l": Vector3(10, 0, -5), "shin_l": Vector3(-25, 0, 0),
	"upper_arm_r": Vector3(-20, 0, 40), "lower_arm_r": Vector3(70, 0, 0),
	"upper_arm_l": Vector3(55, 0, -30), "lower_arm_l": Vector3(100, 0, 0),
}
const KICK_HIT := {
	"root": Vector3(0, -0.04, 0), "chest": Vector3(18, 35, 12), "abdomen": Vector3(5, 15, 5), "head": Vector3(-15, -40, -10),
	"thigh_r": Vector3(92, -35, 25), "shin_r": Vector3(-6, 0, 0), "foot_r": Vector3(-20, 0, 0),
	"thigh_l": Vector3(6, 0, -8), "shin_l": Vector3(-18, 0, 0), "foot_l": Vector3(10, 0, 0),
	"upper_arm_r": Vector3(-30, 0, 70), "lower_arm_r": Vector3(30, 0, 0),
	"upper_arm_l": Vector3(70, 0, -40), "lower_arm_l": Vector3(90, 0, 0),
}

const HAMMER_WIND := {
	"root": Vector3(0, 0.15, 0), "chest": Vector3(22, 0, 0), "abdomen": Vector3(10, 0, 0), "head": Vector3(-10, 0, 0),
	"upper_arm_r": Vector3(172, 0, 12), "lower_arm_r": Vector3(45, 0, 0),
	"upper_arm_l": Vector3(172, 0, -12), "lower_arm_l": Vector3(45, 0, 0),
	"thigh_r": Vector3(40, 0, 6), "shin_r": Vector3(-70, 0, 0), "thigh_l": Vector3(10, 0, -6), "shin_l": Vector3(-40, 0, 0),
}
const HAMMER_HIT := {
	"root": Vector3(0, -0.38, 0), "chest": Vector3(-42, 0, 0), "abdomen": Vector3(-18, 0, 0), "head": Vector3(30, 0, 0),
	"upper_arm_r": Vector3(70, 0, 6), "lower_arm_r": Vector3(10, 0, 0),
	"upper_arm_l": Vector3(70, 0, -6), "lower_arm_l": Vector3(10, 0, 0),
	"thigh_r": Vector3(70, 0, 12), "shin_r": Vector3(-110, 0, 0), "foot_r": Vector3(40, 0, 0),
	"thigh_l": Vector3(-10, 0, -10), "shin_l": Vector3(-70, 0, 0), "foot_l": Vector3(30, 0, 0),
}

const UPPER_WIND := {
	"root": Vector3(0, -0.35, 0), "chest": Vector3(-30, -30, 0), "abdomen": Vector3(-10, -10, 0), "head": Vector3(25, 30, 0),
	"upper_arm_r": Vector3(-25, 0, 20), "lower_arm_r": Vector3(100, 0, 0),
	"upper_arm_l": Vector3(60, 0, -15), "lower_arm_l": Vector3(105, 0, 0),
	"thigh_r": Vector3(65, 0, 15), "shin_r": Vector3(-110, 0, 0), "foot_r": Vector3(45, 0, 0),
	"thigh_l": Vector3(40, 0, -15), "shin_l": Vector3(-90, 0, 0), "foot_l": Vector3(45, 0, 0),
}
const UPPER_HIT := {
	"root": Vector3(0, 0.12, 0), "chest": Vector3(15, 30, 0), "abdomen": Vector3(8, 10, 0), "head": Vector3(15, -30, 0),
	"upper_arm_r": Vector3(165, -20, 5), "lower_arm_r": Vector3(25, 0, 0),
	"upper_arm_l": Vector3(-20, 0, -45), "lower_arm_l": Vector3(60, 0, 0),
	"thigh_r": Vector3(-5, 0, 6), "shin_r": Vector3(-10, 0, 0), "foot_r": Vector3(-30, 0, 0),
	"thigh_l": Vector3(60, 0, -6), "shin_l": Vector3(-80, 0, 0),
}

const PALMS_WIND := {
	"root": Vector3(0, -0.15, 0), "chest": Vector3(10, 0, 0), "head": Vector3(-5, 0, 0),
	"upper_arm_r": Vector3(20, 0, 25), "lower_arm_r": Vector3(130, 0, 0), "hand_r": Vector3(-40, 0, 0),
	"upper_arm_l": Vector3(20, 0, -25), "lower_arm_l": Vector3(130, 0, 0), "hand_l": Vector3(-40, 0, 0),
	"thigh_r": Vector3(25, 0, 18), "shin_r": Vector3(-50, 0, 0), "thigh_l": Vector3(-10, 0, -18), "shin_l": Vector3(-30, 0, 0),
}
const PALMS_HIT := {
	"root": Vector3(0, -0.25, 0), "chest": Vector3(-14, 0, 0), "head": Vector3(10, 0, 0),
	"upper_arm_r": Vector3(88, 0, 10), "lower_arm_r": Vector3(5, 0, 0), "hand_r": Vector3(-70, 0, 0),
	"upper_arm_l": Vector3(88, 0, -10), "lower_arm_l": Vector3(5, 0, 0), "hand_l": Vector3(-70, 0, 0),
	"thigh_r": Vector3(45, 0, 18), "shin_r": Vector3(-60, 0, 0), "thigh_l": Vector3(-25, 0, -18), "shin_l": Vector3(-20, 0, 0),
}

const SLAM_HIT := {
	"root": Vector3(0, -0.5, 0), "chest": Vector3(-35, 0, 0), "head": Vector3(25, 0, 0),
	"upper_arm_r": Vector3(55, 0, 35), "lower_arm_r": Vector3(5, 0, 0),
	"upper_arm_l": Vector3(55, 0, -35), "lower_arm_l": Vector3(5, 0, 0),
	"thigh_r": Vector3(85, 0, 20), "shin_r": Vector3(-125, 0, 0), "foot_r": Vector3(45, 0, 0),
	"thigh_l": Vector3(5, 0, -25), "shin_l": Vector3(-95, 0, 0), "foot_l": Vector3(70, 0, 0),
}

const KNEEL_WIND := {
	"root": Vector3(0, -0.3, 0), "chest": Vector3(-25, -15, 0), "head": Vector3(10, 10, 0),
	"upper_arm_r": Vector3(160, 0, 25), "lower_arm_r": Vector3(70, 0, 0),
	"upper_arm_l": Vector3(40, 0, -30), "lower_arm_l": Vector3(60, 0, 0),
	"thigh_l": Vector3(80, 0, -8), "shin_l": Vector3(-100, 0, 0), "foot_l": Vector3(25, 0, 0),
	"thigh_r": Vector3(-5, 0, 8), "shin_r": Vector3(-95, 0, 0), "foot_r": Vector3(-10, 0, 0),
}
const KNEEL_HIT := {
	"root": Vector3(0, -0.6, 0), "chest": Vector3(-55, 15, 0), "abdomen": Vector3(-15, 0, 0), "head": Vector3(35, -10, 0),
	"upper_arm_r": Vector3(40, -10, 8), "lower_arm_r": Vector3(0, 0, 0),
	"upper_arm_l": Vector3(-20, 0, -45), "lower_arm_l": Vector3(40, 0, 0),
	"thigh_l": Vector3(95, 0, -8), "shin_l": Vector3(-120, 0, 0), "foot_l": Vector3(30, 0, 0),
	"thigh_r": Vector3(-15, 0, 8), "shin_r": Vector3(-100, 0, 0), "foot_r": Vector3(-20, 0, 0),
}

const HURT := {
	"root": Vector3(0, -0.1, 0), "chest": Vector3(25, 15, 0), "abdomen": Vector3(10, 0, 0), "head": Vector3(30, 10, 0),
	"upper_arm_r": Vector3(-30, 0, 45), "lower_arm_r": Vector3(40, 0, 0),
	"upper_arm_l": Vector3(-20, 0, -55), "lower_arm_l": Vector3(30, 0, 0),
	"thigh_r": Vector3(-10, 0, 8), "shin_r": Vector3(-30, 0, 0), "thigh_l": Vector3(25, 0, -8), "shin_l": Vector3(-40, 0, 0),
}

static var COMBO := [
	{"name": "jab", "wind": JAB_WIND, "hit": JAB_HIT, "windup": 0.1, "active": 0.08, "recover": 0.26,
		"damage": 10, "knock": 5.0, "launch": 0.0, "hitstop": 0.055, "shake": 0.16, "kick": 2.0, "reach": 1.7},
	{"name": "cross", "wind": Poses.mirror(JAB_WIND), "hit": Poses.mirror(JAB_HIT), "windup": 0.1, "active": 0.08, "recover": 0.26,
		"damage": 10, "knock": 5.0, "launch": 0.0, "hitstop": 0.055, "shake": 0.16, "kick": 2.0, "reach": 1.7},
	{"name": "kick", "wind": KICK_WIND, "hit": KICK_HIT, "windup": 0.13, "active": 0.1, "recover": 0.3,
		"damage": 13, "knock": 8.0, "launch": 0.0, "hitstop": 0.07, "shake": 0.24, "kick": 3.0, "reach": 2.0},
	{"name": "hammer", "wind": HAMMER_WIND, "hit": HAMMER_HIT, "windup": 0.17, "active": 0.14, "recover": 0.38,
		"damage": 22, "knock": 15.0, "launch": 5.0, "hitstop": 0.11, "shake": 0.45, "kick": 6.0, "reach": 1.9,
		"radius": 2.2, "finisher": true},
]

const HEAVY := {"name": "uppercut", "wind": UPPER_WIND, "hit": UPPER_HIT, "windup": 0.3, "active": 0.16, "recover": 0.42,
	"damage": 24, "knock": 7.0, "launch": 13.0, "hitstop": 0.12, "shake": 0.5, "kick": 7.0, "reach": 1.9,
	"breaks_guard": true, "finisher": true}

static var COUNTER := {"name": "counter", "wind": Poses.mirror(JAB_WIND), "hit": JAB_HIT, "windup": 0.06, "active": 0.12, "recover": 0.22,
	"damage": 14, "knock": 12.0, "launch": 2.0, "hitstop": 0.1, "shake": 0.35, "kick": 5.0, "reach": 1.9,
	"breaks_guard": true}

const FLAME := {"name": "flame", "wind": PALMS_WIND, "hit": PALMS_HIT, "windup": 0.16, "active": 0.3, "recover": 0.3,
	"damage": 18, "knock": 13.0, "launch": 3.0, "hitstop": 0.09, "shake": 0.5, "kick": 6.0, "reach": 6.5,
	"cone": 40.0, "breaks_guard": true, "energy": 35}

## Frost's power: an icy cone that freezes; frozen enemies take double damage.
const FROST_BLAST := {"name": "frost", "wind": PALMS_WIND, "hit": PALMS_HIT, "windup": 0.16, "active": 0.3, "recover": 0.3,
	"damage": 10, "knock": 3.0, "launch": 0.0, "hitstop": 0.07, "shake": 0.35, "kick": 4.0, "reach": 7.0,
	"cone": 45.0, "breaks_guard": true, "energy": 35, "freeze": 2.6}

## Volt's power: lightning that hops from enemy to enemy and paralyses them.
const CHAIN := {"name": "chain", "wind": PALMS_WIND, "hit": PALMS_HIT, "windup": 0.14, "active": 0.25, "recover": 0.3,
	"damage": 14, "knock": 3.0, "launch": 0.0, "hitstop": 0.08, "shake": 0.4, "kick": 5.0, "reach": 9.0,
	"chain": 5, "hop": 6.5, "breaks_guard": true, "energy": 35, "stun": 1.5}

## Stone's power: both fists into the ground, a quake that throws everyone
## around you into the air (follow up with a jump for an air combo).
const QUAKE := {"name": "quake", "wind": HAMMER_WIND, "hit": SLAM_HIT, "windup": 0.28, "active": 0.3, "recover": 0.4,
	"damage": 15, "knock": 6.0, "launch": 11.0, "hitstop": 0.1, "shake": 0.8, "kick": 7.0, "reach": 6.5,
	"radius": 6.5, "around": true, "breaks_guard": true, "energy": 35}

## Venom's power: a poison cloud where you aim. Poisoned enemies lose health,
## move at half speed and cannot attack.
const POISON := {"name": "poison", "wind": PALMS_WIND, "hit": PALMS_HIT, "windup": 0.16, "active": 0.25, "recover": 0.3,
	"damage": 4, "knock": 2.0, "launch": 0.0, "hitstop": 0.04, "shake": 0.2, "kick": 2.0, "reach": 8.0,
	"cloud": 4.5, "cloud_secs": 5.0, "poison": 5.0, "breaks_guard": true, "energy": 35}

## Gale's power: a tornado that pulls everyone in and spins them up.
const TORNADO := {"name": "tornado", "wind": UPPER_WIND, "hit": UPPER_HIT, "windup": 0.2, "active": 0.35, "recover": 0.35,
	"damage": 10, "knock": -6.0, "launch": 12.0, "hitstop": 0.08, "shake": 0.5, "kick": 5.0, "reach": 7.0,
	"radius": 7.0, "around": true, "breaks_guard": true, "energy": 35}

## Shade's power: step out of the shadow behind up to three enemies in turn,
## striking each from behind. Shields do not help them.
const SHADOW := {"name": "shadow", "wind": JAB_WIND, "hit": JAB_HIT, "windup": 0.12, "active": 0.45, "recover": 0.3,
	"damage": 30, "knock": 8.0, "launch": 3.0, "hitstop": 0.06, "shake": 0.45, "kick": 6.0, "reach": 10.0,
	"shadow": 3, "breaks_guard": true, "energy": 35}

## Special combo takedown: a leaping double-fist hammer wrapped in fire. Kills a
## grunt outright; the boss takes BOSS_TAKEDOWN_DAMAGE and staggers.
const TAKEDOWN := {"name": "takedown", "wind": HAMMER_WIND, "hit": HAMMER_HIT, "windup": 0.24, "active": 0.28, "recover": 0.4,
	"damage": 999.0, "knock": 18.0, "launch": 6.0, "hitstop": 0.13, "shake": 0.8, "kick": 10.0, "reach": 2.0,
	"breaks_guard": true, "takedown": true, "finisher": true}
const BOSS_TAKEDOWN_DAMAGE := 60.0

## Ground takedown on an enemy lying down: slow, so it costs you in a crowd.
const GROUND_FINISH := {"name": "ground", "wind": KNEEL_WIND, "hit": KNEEL_HIT, "windup": 0.26, "active": 0.22, "recover": 0.45,
	"damage": 999.0, "knock": 0.0, "launch": 0.0, "hitstop": 0.1, "shake": 0.5, "kick": 5.0, "reach": 1.8,
	"breaks_guard": true}

const SLAM := {"name": "slam", "hit": SLAM_HIT, "active": 0.2, "recover": 0.35,
	"damage": 20, "knock": 12.0, "launch": 7.0, "hitstop": 0.12, "shake": 0.7, "kick": 8.0, "radius": 4.5,
	"breaks_guard": true}

