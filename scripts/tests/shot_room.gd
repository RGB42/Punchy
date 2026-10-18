extends Node
## Windowed look-check in the real level: a rug fight, then the king on the desk.
##   godot --path . res://scenes/tests/shot_room.tscn -- --skip-intro --out=<dir>

const ROOM := preload("res://scenes/kids_room.tscn")

var out_dir := "user://shots"
var shot := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var room := ROOM.instantiate()
	add_child(room)
	var p: Player = room.player
	p.scripted = true
	await wait(0.8)
	p.global_position = Vector3(4, 0.3, 8)
	room.camera.rotation.y = 0.6
	await wait(2.0)
	await snap()
	for i in 6:
		p.attack_pressed = true
		await wait(0.18)
		await snap()
	p.combat._set_energy(100.0)
	p.power_pressed = true
	await wait(0.2)
	await snap()
	# the king
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	var a4: Arena = room.get_node("arena_4")
	a4.waves = [{"enemies": ["king"]}]
	p.global_position = Vector3(21, 9.2, -9.5)
	room.camera.rotation.y = 0.0
	room.camera.pitch = -0.2
	await wait(3.0)
	await snap()
	await wait(1.5)
	await snap()
	await wait(1.5)
	await snap()
	print("SHOTS ", shot, " -> ", out_dir)
	get_tree().quit()


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func snap() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/room_%02d.png" % [out_dir, shot])
	shot += 1
