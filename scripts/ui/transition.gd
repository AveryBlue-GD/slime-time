extends CanvasLayer

## Autoload `Transition`: goo-wipe screen changes. `go(scene)` drops a sheet of goo in the skin's
## color over the screen, swaps scenes underneath, then lets it slide off. `reveal()` only does
## the slide-off half (for instant reloads, so a restarted level still eases in).

const COVER_TIME := 0.22
const UNCOVER_TIME := 0.32
## A little past 1 so the longest drips clear the bottom of the screen.
const OFF_SCREEN := 1.3
const SCREEN_HEIGHT := 180.0

var busy := false
var _sheet: ColorRect
var _material: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = preload("res://assets/shaders/goo_wipe.gdshader")
	_sheet = ColorRect.new()
	_sheet.material = _material
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.visible = false
	add_child(_sheet)


## Covers the screen, changes to `scene`, then uncovers.
func go(scene: String) -> void:
	if busy:
		return
	busy = true
	_paint()
	_set_edges(0.0, 0.0)
	_sheet.visible = true
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void: _set_edges(v, 0.0), 0.0, OFF_SCREEN, COVER_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _tween.finished
	get_tree().change_scene_to_file(scene)
	await get_tree().process_frame
	busy = false
	_uncover()


## Starts fully covered and slides the goo off (no scene change).
func reveal() -> void:
	if busy:
		return
	_paint()
	_uncover()


func _uncover() -> void:
	if _tween:
		_tween.kill()
	_sheet.visible = true
	_set_edges(OFF_SCREEN, 0.0)
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void: _set_edges(OFF_SCREEN, v), 0.0, OFF_SCREEN, UNCOVER_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: _sheet.visible = false)


func _set_edges(bottom: float, top: float) -> void:
	_material.set_shader_parameter("bottom", bottom)
	_material.set_shader_parameter("top", top)
	# The sheet's texture slides with it: down with the bottom edge, then on down with the top.
	_material.set_shader_parameter("slide", (bottom + top) * SCREEN_HEIGHT)


## Goo in the equipped skin's shades; with the rainbow skin, a random rainbow color each time.
func _paint() -> void:
	var progress := get_node_or_null("/root/Progress")
	var color: Color = Skins.get_preset(Skins.DEFAULT).color
	if progress:
		color = random_rainbow_color() if progress.is_rainbow() else progress.skin_color()
	var shades := Skins.shades(color)
	_material.set_shader_parameter("goo", shades.mid)
	_material.set_shader_parameter("goo_dark", shades.dark)
	_material.set_shader_parameter("goo_light", shades.light)
	_material.set_shader_parameter("goo_deep", shades.deep)
	_material.set_shader_parameter("goo_highlight", shades.highlight)


## A random color from the rainbow (red through violet).
static func random_rainbow_color() -> Color:
	return Color.from_hsv(randf() * 0.83, 0.78, 0.95)
