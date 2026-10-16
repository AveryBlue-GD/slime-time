extends Node

## Autoload "Language" (registered right after Progress): the only place that talks to TranslationServer
## (and, from chunk D, to the font fallbacks). docs/i18n/plan.md sections 2-7.
## - Gate off (Economy.languages_on() false, the default): loads NO translation, adds no font fallback,
##   never touches the text direction or the locale; Loc.t returns the English source text. The game
##   looks and saves exactly as before the feature.
## - Gate on (`--languages`, `--lang=xx`, tests): loads every locale/*.po, picks the locale (the player's
##   saved choice, else `--lang=xx`, else the OS locale if supported, else English), installs the fonts
##   for its script, sets the text direction, emits `language_changed`.
## Godot's own auto-translation stays off everywhere (the root's auto_translate_mode is DISABLED, and
## UIKit.setup_screen disables it on each menu root): all translation goes through Loc.
## The player's choice is saved as [settings] language (Progress.language) ONLY by `pick`; a locale from
## the OS or `--lang` is never written, and save codes never carry it.

signal language_changed(locale: String)

const SOURCE_LOCALE := "en"
## The test-only pseudo-localization locale (`--lang=pseudo`; chunk F fills in its settings).
const PSEUDO := "pseudo"
const LOCALE_DIR := "res://locale"
## Supported locales in the LANGUAGE screen's order (fixed, never sorted per locale), each with its
## own name written in its own script. These names are never translated.
const LOCALES := [
	["en", "ENGLISH"], ["es", "ESPAÑOL"], ["pt_BR", "PORTUGUÊS (BR)"], ["fr", "FRANÇAIS"],
	["de", "DEUTSCH"], ["it", "ITALIANO"], ["ru", "РУССКИЙ"], ["pl", "POLSKI"], ["tr", "TÜRKÇE"],
	["ja", "日本語"], ["ko", "한국어"], ["zh_CN", "简体中文"], ["zh_TW", "繁體中文"], ["th", "ไทย"],
	["vi", "TIẾNG VIỆT"], ["id", "INDONESIA"], ["ar", "العربية"], ["hi", "हिन्दी"],
]
const RTL_LOCALES := ["ar"]

## The locale in use ("en" while the gate is off).
var locale := SOURCE_LOCALE
## True once enable() ran (the gate was on): catalogs loaded, locale applied.
var active := false
var _loaded: Array[Translation] = []
var _locale_before := ""


func _ready() -> void:
	# Labels / Buttons translate their own text once any catalog is loaded; that would also hit seeds,
	# typed text and already translated strings. Every node inherits this from the root.
	get_tree().root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if Economy.languages_on():
		enable()


## Codes of every supported locale, in the LANGUAGE screen's order.
static func codes() -> Array[String]:
	var out: Array[String] = []
	for entry: Array in LOCALES:
		out.append(entry[0])
	return out


static func is_supported(code: String) -> bool:
	return code in codes()


## A locale's own name in its own script ("" if unsupported).
static func native_name(code: String) -> String:
	for entry: Array in LOCALES:
		if entry[0] == code:
			return entry[1]
	return ""


## The supported locale for an OS locale string ("pt_BR", "de-AT", "zh_Hant_HK"...), or "" if none.
static func match_os_locale(os_locale: String) -> String:
	var code := os_locale.replace("-", "_").strip_edges()
	if code == "":
		return ""
	if is_supported(code):
		return code
	var parts := code.split("_")
	var lang := parts[0].to_lower()
	if lang == "zh":
		var traditional := "Hant" in parts or "TW" in parts or "HK" in parts or "MO" in parts
		return "zh_TW" if traditional else "zh_CN"
	if lang == "pt":
		return "pt_BR"
	return lang if is_supported(lang) else ""


## The locale to use, in this order: the player's saved choice, `--lang=xx`, the OS locale if supported,
## English.
static func choose_locale(saved: String, forced: String, os_locale: String) -> String:
	if is_supported(saved):
		return saved
	if is_supported(forced) or forced == PSEUDO:
		return forced
	var from_os := match_os_locale(os_locale)
	return from_os if from_os != "" else SOURCE_LOCALE


## Gate on: loads the catalogs and applies the chosen locale. Does nothing with the gate off.
func enable() -> void:
	if not Economy.languages_on():
		return
	if not active:
		active = true
		_locale_before = TranslationServer.get_locale()
		_load_catalogs()
	var progress := get_node_or_null("/root/Progress")
	var saved: String = progress.language if progress else ""
	set_locale(choose_locale(saved, Economy.forced_locale, OS.get_locale()))


## Undoes enable() (tests): removes every catalog this autoload added and restores the locale.
func disable() -> void:
	for translation in _loaded:
		TranslationServer.remove_translation(translation)
	_loaded.clear()
	if active and _locale_before != "":
		TranslationServer.set_locale(_locale_before)
	active = false
	locale = SOURCE_LOCALE


## Adds one catalog file (a .po; tests use their own fixture). False if it can't be loaded.
func load_catalog(path: String) -> bool:
	var translation := load(path) as Translation
	if translation == null:
		return false
	if translation not in _loaded:
		TranslationServer.add_translation(translation)
		_loaded.append(translation)
	return true


func loaded_catalogs() -> Array[Translation]:
	return _loaded.duplicate()


## Switches to `code` for this session (not saved; see pick). Ignored with the gate off.
func set_locale(code: String) -> void:
	if not active or not (is_supported(code) or code == PSEUDO):
		return
	var changed := code != locale
	locale = code
	TranslationServer.set_locale(SOURCE_LOCALE if code == PSEUDO else code)
	_apply_pseudo(code == PSEUDO)
	_install_fonts()
	_apply_direction()
	if changed:
		language_changed.emit(locale)


## The player picked `code` in the LANGUAGE screen: the only place the choice is saved
## ([settings] language). False (and nothing saved) with the gate off or for an unknown code.
func pick(code: String) -> bool:
	if not active or not is_supported(code):
		return false
	var progress := get_node_or_null("/root/Progress")
	if progress:
		progress.language = code
		progress.save_progress()
	set_locale(code)
	return true


## True when the current language is written right to left (never with the gate off).
func is_rtl() -> bool:
	return active and locale in RTL_LOCALES


func _load_catalogs() -> void:
	if not DirAccess.dir_exists_absolute(LOCALE_DIR):
		return
	for file in DirAccess.get_files_at(LOCALE_DIR):
		if file.ends_with(".po"):
			load_catalog(LOCALE_DIR.path_join(file))


## STUB (chunk F, docs/i18n/plan.md section 8): pseudo-localization settings for `--lang=pseudo`.
func _apply_pseudo(_on: bool) -> void:
	pass


## STUB (chunk D, docs/i18n/plan.md section 7): the font fallback chain for the current locale's script
## on pixel.fnt / pixel_big.fnt / the tabular copy. Never called with the gate off.
func _install_fonts() -> void:
	pass


## STUB (chunk I, docs/i18n/plan.md section 7 "RTL" + owner answer: full mirroring): the text and
## layout direction for right-to-left locales (is_rtl). Never called with the gate off.
func _apply_direction() -> void:
	pass
