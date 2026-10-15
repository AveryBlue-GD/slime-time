extends "res://tests/suite_base.gd"

## Every skin in the hub: for each skin (all ten presets, the CHAMELEON color wheel and the
## rainbow), in both jelly and solid versions, the skin is picked on the real skins screen and the
## hub is opened again. Then the room's floor tiles and rim (hub_room.gdshader's six shade
## uniforms, and its rainbow bands for the rainbow skin), every station, the wheel in the middle and the slime itself must all use that
## skin's shades (rainbow on only for the rainbow skin; jelly see-through only when jelly is on).
## The order hops between very different skins (including rainbow -> a plain skin) so stale
## colors from the skin before would show up. Everything unlocked (dev); never touches a save.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_hub_skins.gd

var progress: Node
var skins_scene: PackedScene
var hub_scene: PackedScene


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.dev_tools = true  # every skin, jelly and solid
	skins_scene = load("res://scenes/skins.tscn")
	hub_scene = load("res://scenes/hub.tscn")

	var ids: Array[String] = []
	for preset: Dictionary in Skins.PRESETS:
		ids.append(preset.id)
	# Hop around: neighbors in the list differ a lot, and the rainbow is followed by plain skins.
	var order: Array[String] = [Skins.RAINBOW]
	order.append_array(ids)
	order.append_array([Skins.CUSTOM, Skins.RAINBOW, "lime", Skins.CUSTOM, "ember"])
	var checked := 0
	for jelly in [true, false]:
		for id in order:
			var expected := await _pick(id, jelly)
			if await _check_hub(id, jelly, expected):
				checked += 1
	_check(checked == order.size() * 2, "%d of %d skin swaps show the right colors everywhere in the hub" % [checked, order.size() * 2])

	_result()
	quit(1 if failures else 0)


## Picks skin `id` (jelly or solid) on the skins screen; returns the base color it should show.
func _pick(id: String, jelly: bool) -> Color:
	var screen: Control = skins_scene.instantiate()
	root.add_child(screen)
	await process_frame
	if screen.view_jelly != jelly:
		screen._toggle_jelly()
	screen._on_tile(id)
	await process_frame
	screen.free()
	if progress.selected_skin != id or progress.jelly != jelly:
		_check(false, "picking %s (%s) on the skins screen wears it" % [id, "jelly" if jelly else "solid"])
	if id == Skins.RAINBOW:
		return Skins.RAINBOW_BASE
	if id == Skins.CUSTOM:
		return progress.custom_color  # the wheel's random color for this visit
	return Skins.get_preset(id).color


## Opens the hub and checks every skin-colored part of it; true when all of them are right.
func _check_hub(id: String, jelly: bool, base: Color) -> bool:
	var hub: Node2D = hub_scene.instantiate()
	root.add_child(hub)
	await physics_frame
	var shades := Skins.shades(base)
	var rainbow := id == Skins.RAINBOW
	var wrong: Array[String] = []
	var room := hub.room.material as ShaderMaterial
	for shade: String in shades:
		if not Color(room.get_shader_parameter(shade)).is_equal_approx(shades[shade]):
			wrong.append("floor/rim %s" % shade)
	if bool(room.get_shader_parameter("rainbow")) != rainbow:
		wrong.append("floor/rim rainbow")
	var parts := {"wheel": hub.rotor, "slime": hub.slime.sprite}
	for station: Dictionary in hub.stations:
		parts[station.id] = station.sprite
	for part: String in parts:
		var material := (parts[part] as CanvasItem).material as ShaderMaterial
		if not Color(material.get_shader_parameter("mid")).is_equal_approx(shades.mid):
			wrong.append("%s color" % part)
		if bool(material.get_shader_parameter("rainbow")) != rainbow:
			wrong.append("%s rainbow" % part)
	var see_through: float = (hub.slime.sprite.material as ShaderMaterial).get_shader_parameter("translucency")
	if see_through != (1.0 if jelly else 0.0):
		wrong.append("slime jelly")
	hub.free()
	var label := "%s (%s)" % [Skins.display_name(id), "jelly" if jelly else "solid"]
	if not wrong.is_empty():
		_check(false, "%s: wrong %s" % [label, ", ".join(wrong)])
		return false
	print("  ok   %s: floor tiles, rim, stations, wheel and slime all match" % label)
	return true


