class_name TestBase
extends Node
## Booted-scene test harness. Subclasses implement run() (a coroutine), call
## check(), and the process exits 0 when every check passed, 1 otherwise.
##
##   godot --headless --path . --quit-after 6000 res://scenes/tests/<test>.tscn

var failures := 0
var passes := 0


func _ready() -> void:
	await run()
	print("RESULT %d passed, %d failed" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func run() -> void:
	pass


func check(ok: bool, name: String, detail := "") -> void:
	if ok:
		passes += 1
		print("PASS %s  %s" % [name, detail])
	else:
		failures += 1
		print("FAIL %s  %s" % [name, detail])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(s: float) -> void:
	await frames(int(s * Engine.physics_ticks_per_second))
