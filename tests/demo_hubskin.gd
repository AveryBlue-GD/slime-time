extends Node

## Screenshot scenario: the hub in the first skin, then the real trip hub -> Skins screen -> pick
## `--pick=ID` (default stopwatch) -> hub. The last frame is the hub after the trip.
## ./tools/screenshot.sh --frames 400 --scene res://tests/demo_hubskin.tscn --unlock-all --skin=ember -- --pick=stopwatch

func _ready() -> void:
	var pick := "stopwatch"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pick="):
			pick = arg.trim_prefix("--pick=")
	var t := get_tree()
	var keep := self
	get_parent().remove_child.call_deferred(self)
	t.root.add_child.call_deferred(self)  # survive the scene changes
	t.change_scene_to_file.call_deferred(UIKit.HUB_SCENE)
	await t.create_timer(0.5).timeout
	await _go(t, "res://scenes/skins.tscn")
	t.current_scene._on_tile(pick)
	await t.create_timer(0.3).timeout
	print("PICKED ", Progress.selected_skin, " ", Progress.skin_color())
	await _go(t, UIKit.HUB_SCENE)


func _go(t: SceneTree, scene: String) -> void:
	t.root.get_node("Transition").go(scene)
	await t.create_timer(1.0).timeout
	print("HUB ", t.current_scene.name, " ", Progress.selected_skin)
