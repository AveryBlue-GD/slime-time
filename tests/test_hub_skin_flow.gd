extends "res://tests/suite_base.gd"

## The real screen-change flow: hub -> Skins screen (Transition goo wipe + scene change) -> pick a
## skin -> back to the hub. The new hub (floor, rim, goo wipe, goo boxes, slime) must wear the NEW
## skin at once, not the one from before the visit (including STOPWATCH, RAINBOW and CHAMELEON).
## Everything unlocked (dev); never touches a save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_hub_skin_flow.gd

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.dev_tools = true
	progress.selected_skin = "lime"
	progress.skin_notices_seen.append(1)  # level 1 must not re-equip its first-run skin under us
	for id: String in ["ember", Skins.STOPWATCH, Skins.RAINBOW, "lime", Skins.CUSTOM, Skins.STOPWATCH, "frost"]:
		await _visit(id)
	_result()
	quit(1 if failures else 0)


func _go(scene: String) -> void:
	root.get_node("Transition").go(scene)
	while root.get_node("Transition").busy:
		await process_frame
	for i in 5:
		await process_frame


func _visit(id: String) -> void:
	await _go(UIKit.HUB_SCENE)
	await _go("res://scenes/skins.tscn")
	var screen := current_scene
	screen._on_tile(id)
	await process_frame
	await _go(UIKit.HUB_SCENE)
	var hub := current_scene
	var base: Color = progress.skin_color()
	var shades := Skins.shades(base)
	var wrong: Array[String] = []
	var room := hub.room.material as ShaderMaterial
	for shade: String in shades:
		if not Color(room.get_shader_parameter(shade)).is_equal_approx(shades[shade]):
			wrong.append("floor %s" % shade)
	if bool(room.get_shader_parameter("rainbow")) != (id == Skins.RAINBOW):
		wrong.append("floor rainbow")
	if progress.selected_skin != id:
		wrong.append("not selected")
	if not GooBox.goo_color.is_equal_approx(base) and id != Skins.RAINBOW:
		wrong.append("goo boxes")
	var slime_mid := Color((hub.slime.sprite.material as ShaderMaterial).get_shader_parameter("mid"))
	var want_mid: Color = Skins.STOPWATCH_SHADES.mid if id == Skins.STOPWATCH else base
	if not slime_mid.is_equal_approx(want_mid):
		wrong.append("slime")
	_check(wrong.is_empty(), "%s: hub after the Skins screen%s" % [id, "" if wrong.is_empty() else " wrong: " + ", ".join(wrong)])
	# The other screens that follow the skin, and the hub again after loading and leaving a level.
	for scene: String in ["res://scenes/title.tscn", "res://scenes/level_select.tscn", UIKit.GAME_SCENE, UIKit.HUB_SCENE]:
		await _go(scene)
		var bad := _screen_colors(id)
		_check(bad == "", "%s: %s%s" % [id, scene.get_file(), "" if bad == "" else " wrong: " + bad])
		if scene == UIKit.HUB_SCENE:
			var room2 := current_scene.room.material as ShaderMaterial
			_check(Color(room2.get_shader_parameter("mid")).is_equal_approx(shades.mid), "%s: hub floor after a level" % id)


## "" when the open screen's goo frames and skin-text labels use the worn skin's color.
func _screen_colors(id: String) -> String:
	if id == Skins.RAINBOW:
		return ""  # cycles every frame
	var base: Color = progress.skin_color()
	var wrong: Array[String] = []
	if not GooBox.goo_color.is_equal_approx(base):
		wrong.append("goo boxes")
	for node in get_nodes_in_group(SkinText.GROUP):
		var label := node as Label
		if label and label.is_visible_in_tree() and label.has_theme_color_override("font_color"):
			var want := SkinText.color_for(label.get_meta("role", SkinText.ROLE_TEXT), base)
			if not label.get_theme_color("font_color").is_equal_approx(want):
				wrong.append("label '%s'" % label.text.left(12))
				break
	return ", ".join(wrong)


