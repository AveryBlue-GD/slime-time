extends Node2D

## The RAINBOW hat dye's two looks side by side (a watchable comparison, not a test): every dyeable
## hat on lime slimes at 2x, the top row as the dye flows now (the dyed part turns
## through the colors as one), the bottom row with Hats.flow_material(true) (a rainbow gradient
## flowing across it, like the rainbow jelly skin). Record it with --write-movie.
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
		var head := UIKit.make_label(["NOW: TURNS AS ONE", "GRADIENT: FLOWS LIKE THE JELLY SKIN"][row], UIKit.FONT, UIKit.TEXT)  # i18n: ignore (dev comparison scene)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.size = Vector2(320, 10)
		head.position = Vector2(0, 8 + row * 88)
		add_child(head)
		for i in hats.size():
			var slime := UIKit.make_slime_preview(Skins.get_preset("lime").color, 2)
			slime.position = Vector2(16 + i * 32, 58 + row * 88)
			add_child(slime)
			var hat := Hat.new()
			hat.scale = slime.scale
			add_child(hat)
			hat.setup(hats[i], slime, null, "rainbow")
			hat.material = Hats.flow_material(row == 1 and not Hats.get_hat(hats[i]).get("flows", false))
