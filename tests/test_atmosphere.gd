extends SceneTree

## Skin-matched atmosphere: fog and ambient motes lean toward the worn skin's hue without getting
## brighter, the rainbow/stopwatch use a neutral gold, Reduce Motion still removes the motes.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_atmosphere.gd

var failures := 0


func _initialize() -> void:
	await process_frame
	var plain := Themes.fog_colors("sewers")
	var grape := Themes.fog_colors("sewers", Skins.atmosphere_color("grape", Skins.get_preset("grape").color))
	var ember := Themes.fog_colors("sewers", Skins.atmosphere_color("ember", Skins.get_preset("ember").color))
	_check(grape[1] != plain[1] and grape[1] != ember[1], "fog tint differs by skin")
	_check(absf(grape[1].v - plain[1].v) < 0.02 and absf(grape[0].v - plain[0].v) < 0.02, "...at the same brightness (stays dark)")
	_check(_hue_gap(grape[1], Skins.get_preset("grape").color) < _hue_gap(plain[1], Skins.get_preset("grape").color), "...and nearer the skin's hue")
	_check(Themes.fog_colors("dungeon").is_empty() and Themes.fog_colors("dungeon", Color.RED).size() == 2, "dungeon (default fog) can be tinted too")
	_check(Themes.fog_colors("mossy", Color(0, 0, 0, 0)) == Themes.fog_colors("mossy"), "no tint = the theme's own fog")
	for grey: Color in [Color.WHITE, Color.BLACK, Color(0.5, 0.5, 0.5), Color(0.05, 0.05, 0.05, 1.0)]:
		_check(Skins.atmosphere_color(Skins.CUSTOM, grey) == Skins.ATMOSPHERE_NEUTRAL, "a grey/white/black custom skin gets the neutral atmosphere")
	_check(Skins.tinted(Color(0.2, 0.1, 0.1), Color.WHITE, 0.5) == Color(0.2, 0.1, 0.1), "a colorless tint leaves the fog alone")
	var neutral := Skins.atmosphere_color(Skins.RAINBOW, Skins.RAINBOW_BASE)
	_check(neutral == Skins.ATMOSPHERE_NEUTRAL and Skins.atmosphere_color(Skins.STOPWATCH, Skins.STOPWATCH_BASE) == neutral, "rainbow and stopwatch use neutral gold")
	var a: Ambient = Ambient.create("volcanic", false, Color.BLUE)
	_check(a != null and a.particles.amount <= Ambient.MAX_AMOUNT, "tinted motes are made, capped")
	var c: Color = a.particles.color_ramp.colors[1]
	_check(c.b > Ambient.look("volcanic").color.b, "...and lean toward the skin (blue)")
	a.free()
	_check(Ambient.create("volcanic", true, Color.BLUE) == null, "Reduce Motion: no motes, tint or not")
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print("%s: %s" % ["ok" if ok else "FAIL", what])


func _hue_gap(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h)
	return minf(d, 1.0 - d)
