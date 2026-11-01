extends SceneTree
# Makes the iOS App Store icon (1024x1024, no alpha) from icon.png with a nearest-neighbor 16x upscale (M9).
# ./tools/godot.sh --path . --headless -s res://tools/make_ios_icon.gd

const BG := Color8(26, 28, 44)  # UIKit.BG


func _init() -> void:
	var src := Image.load_from_file("res://icon.png")
	src.convert(Image.FORMAT_RGBA8)
	var out := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGB8)
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			out.set_pixel(x, y, BG.lerp(Color(c.r, c.g, c.b), c.a))
	out.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
	out.save_png("res://assets/ios/icon_1024.png")
	print("wrote assets/ios/icon_1024.png")
	quit()
