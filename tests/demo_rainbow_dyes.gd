extends Node2D

## The flowing hat dyes (a watchable check, not a test): every dyeable hat at 2x, in PRISM on lime
## slimes (top row) and in RAINBOW on the rainbow skin (bottom row), where the hat's gradient must line up with
## the body's rainbow and flow at its pace. Record it with --write-movie.
## ./tools/godot.sh --path . res://tests/demo_rainbow_dyes.tscn

const BG := Color8(34, 40, 58)


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(320, 180)
	add_child(bg)
	var hats: Array[String] = []
	for id in Hats.ids():
		if "rainbow" in Hats.dyes_for(id):
			hats.append(id)
	for row in 2:
		var head := UIKit.make_label(["PRISM DYE (50) ON LIME", "RAINBOW DYE (99) ON THE RAINBOW SKIN"][row], UIKit.FONT, UIKit.TEXT)  # i18n: ignore (dev comparison scene)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.size = Vector2(320, 10)
		head.position = Vector2(0, 8 + row * 88)
		add_child(head)
		for i in hats.size():
			var slime := UIKit.make_slime_preview(Skins.get_preset("lime").color, 2, row == 1)
			slime.position = Vector2(14 + i * 26, 58 + row * 88)  # (12 hats: 26 apart)
			add_child(slime)
			var hat := Hat.new()
			hat.scale = slime.scale
			add_child(hat)
			hat.setup(hats[i], slime, null, ["prism", "rainbow"][row])
