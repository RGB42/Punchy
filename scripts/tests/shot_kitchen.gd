extends Node
## Windowed look-check in the kitchen: the floor fight, then the dragon on the table.
##   godot --path . --screen 1 res://scenes/tests/shot_kitchen.tscn -- --skip-intro --out=<dir>

const ROOM := preload("res://scenes/kitchen.tscn")

var out_dir := "user://shots"
var shot := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var room: Level = ROOM.instantiate()
	add_child(room)
	var p: Player = room.player
	p.scripted = true
	await wait(0.8)
	p.global_position = Vector3(17, 0.3, 4)
	room.camera.rotation.y = 0.3
	await wait(2.6)
	await snap()
	p.combat._invuln = 4.0
	for i in 4:
		p.attack_pressed = true
		await wait(0.22)
		await snap()
	# the dragon
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	var a5: Arena = room.get_node("arena_5")
	a5.waves = [{"enemies": ["dragon"]}]
	p.global_position = Vector3(-3.0, 9.2, 4.0)
	p.velocity = Vector3.ZERO  # a teleport mid-attack must not keep the lunge
	p.set_state(Player.State.AIR)
	room.camera.rotation.y = 2.4
	room.camera.pitch = -0.25
	await wait(3.2)
	await snap()
	for i in 4:
		p.combat._invuln = 3.0
		await wait(1.3)
		await snap()
	print("SHOTS ", shot, " -> ", out_dir)
	get_tree().quit()


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func snap() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/k_%02d.png" % [out_dir, shot])
	shot += 1
