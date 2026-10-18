extends Node
## Windowed look-check: plays a combo against the gym wave and saves frames.
##   godot --path . res://scenes/tests/shot_combat.tscn -- --out=<dir>

const GYM := preload("res://scenes/gym.tscn")
const G := preload("res://scripts/level/gym.gd")

var out_dir := "user://shots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var gym := GYM.instantiate()
	add_child(gym)
	var p: Player = gym.get_node("Player")
	p.scripted = true
	var cam: PlayerCamera = gym.get_node("Camera")
	await get_tree().create_timer(0.5).timeout
	p.global_position = G.FIGHT_CENTER + Vector3(0, 0.1, 6)
	cam.rotation.y = 0.0
	await get_tree().create_timer(0.6).timeout
	var actions := ["attack", "attack", "attack", "attack", "heavy", "attack", "attack", "finisher", "power"]
	var shot := 0
	for i in actions.size():
		match actions[i]:
			"attack": p.attack_pressed = true
			"heavy": p.heavy_pressed = true
			"finisher":
				p.combat._set_combo(PlayerCombat.FINISHER_COMBO)
				p.heavy_pressed = true
				for f in 300:
					await get_tree().process_frame
					if cam._cine_t > 0.0:
						break
				for f in 4:
					await get_tree().process_frame
			"power":
				p.combat._set_energy(100.0)
				p.combat._invuln = 3.0  # nothing interrupts the showcase
				p.power_pressed = true
		for k in 3:
			await get_tree().create_timer(0.1 if actions[i] != "finisher" else 0.3, true, false, true).timeout
			if actions[i] == "power" and k == 0:
				await get_tree().create_timer(0.5, true, false, true).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [out_dir, shot])
			shot += 1
	print("SHOTS ", shot, " -> ", out_dir)
	get_tree().quit()
