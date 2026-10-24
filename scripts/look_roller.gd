class_name LookRoller
extends RefCounted

## A random complete look out of what is owned (skin + version, hat or none, dye, trail, paper): the wardrobe's dice
## and the RANDOM LOOK toggle (_p().random_look), which rolls one before each new run (Game._ready).

## One random look: {skin, jelly, pastel, hat, dye, trail, paper}. Only owned things (Progress's own checks, so the
## demo's and dev mode's rules hold).
static func roll() -> Dictionary:
	var ids: Array[String] = []
	for preset: Dictionary in Skins.PRESETS:
		ids.append(preset.id)
	ids.append_array([Skins.CUSTOM, Skins.RAINBOW, Skins.STOPWATCH])
	var versions: Array[Dictionary] = []  # (skin id first, then one of its owned versions)
	for id in ids:
		var own: Array[Dictionary] = []
		for as_jelly in [false, true]:
			for as_pastel in ([false, true] if Skins.has_pastel(id) else [false]):
				if _p().is_skin_unlocked(id, as_jelly, as_pastel):
					own.append({skin = id, jelly = as_jelly, pastel = as_pastel})
		if not own.is_empty():
			versions.append(own.pick_random())
	var look: Dictionary = versions.pick_random() if not versions.is_empty() else {skin = Skins.DEFAULT, jelly = false, pastel = false}
	var hats: Array[String] = [Hats.NONE]
	for hat in Hats.ids():
		if _p().is_hat_unlocked(hat):
			hats.append(hat)
	look.hat = hats.pick_random()
	look.dye = ""
	if look.hat != Hats.NONE:
		var dyes := hat_colors(look.hat)  # ("" = its own color, then the dyes owned)
		look.dye = dyes.pick_random()
	var trails: Array[String] = []
	for id in Cosmetics.trail_ids():
		if _p().owns_cosmetic(id) and _p().cosmetic_visible(id):
			trails.append(id)
	look.trail = trails.pick_random() if not trails.is_empty() else Cosmetics.DEFAULT_TRAIL
	var papers: Array[String] = []
	for id in Cosmetics.paper_ids():
		if _p().owns_cosmetic(id):
			papers.append(id)
	look.paper = papers.pick_random() if not papers.is_empty() else Cosmetics.DEFAULT_PAPER
	return look


## The colors of `hat` that are owned ("" = its own color, then every dye owned).
static func hat_colors(hat: String) -> Array[String]:
	var colors: Array[String] = [""]
	for dye in Hats.dyes_for(hat):
		if _p().owns_dye(hat, dye):
			colors.append(dye)
	return colors


## Puts `look` on the way the pickers do (one save at the end).
static func apply(look: Dictionary) -> void:
	_p().begin_save_batch()  # (one save for the whole look, not five)
	_p().select_skin(look.skin, look.jelly, look.pastel)
	_p().select_hat(look.hat)
	if look.hat != Hats.NONE:
		_p().wear_dye(look.hat, look.dye)
	_p().equip_cosmetic(look.trail)
	_p().equip_cosmetic(look.paper)
	_p().end_save_batch()


## A new look for a run that starts now (RANDOM LOOK on). Not for a retry of the same attempt (`keep_look_once`,
## set by Game.retry / R / pause RESTART, used up here), the demo's preview, training or Descent.
static func roll_for_run(skip := false) -> bool:
	if _p().keep_look_once:
		_p().keep_look_once = false
		return false
	if skip or not _p().random_look:
		return false
	apply(roll())
	return true


## The Progress autoload (a global-class script can't name it directly).
static func _p() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Progress")
