extends Node

## Autoload "Language" (registered right after Progress): the only place that talks to TranslationServer
## and to the font fallbacks. docs/i18n/plan.md sections 2-7, fonts: docs/i18n/fonts.md.
## - Gate off (Economy.languages_on() false, the default): loads NO translation, adds no font fallback,
##   never touches the text direction; the locale is pinned to English (so nothing can follow the OS
##   language); Loc.t returns the English source text. The game looks and saves exactly as before.
## - Gate on (`--languages`, `--lang=xx`, tests): loads the catalogs (CATALOGS), picks the locale
##   (`--lang=xx`, else the player's saved choice, else the OS locale if supported, else English),
##   installs the font fallbacks (every script, the current one first), sets the text direction, emits
##   `language_changed`. `metrics(code)` gives later chunks each locale's line / button sizes.
## Godot's own auto-translation stays off everywhere (the root's auto_translate_mode is DISABLED, and
## UIKit.setup_screen disables it on each menu root): all translation goes through Loc.
## The player's choice is saved as [settings] language (Progress.language) ONLY by `pick`; a locale from
## the OS or `--lang` is never written, and save codes never carry it.

signal language_changed(locale: String)

const SOURCE_LOCALE := "en"
## The test-only pseudo-localization locale (`--lang=pseudo`; see _apply_pseudo / Loc.pseudolocalize).
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
## The catalog of every locale but the English source, by path (a list, not a directory listing, so
## it also works from an exported .pck where res://locale can't be listed). Missing files are skipped.
const CATALOGS := [
	"res://locale/es.po", "res://locale/pt_BR.po", "res://locale/fr.po", "res://locale/de.po",
	"res://locale/it.po", "res://locale/ru.po", "res://locale/pl.po", "res://locale/tr.po",
	"res://locale/ja.po", "res://locale/ko.po", "res://locale/zh_CN.po", "res://locale/zh_TW.po",
	"res://locale/th.po", "res://locale/vi.po", "res://locale/id.po", "res://locale/ar.po",
	"res://locale/hi.po",
]

# --- Fonts (chunk D; docs/i18n/fonts.md, plan.md section 7) ---------------------------------------
## The slimy font (8 px text) and its 2x copy (16 px titles): Latin incl. every accented letter the
## Latin locales need, Cyrillic, punctuation (tools/make_font.py).
const FONT_PATH := "res://assets/fonts/pixel.fnt"
const FONT_BIG_PATH := "res://assets/fonts/pixel_big.fnt"
## The fallback font of each locale whose script the slimy font lacks: [path, pixel size under 8 px
## text, pixel size under 16 px titles]. Subsets built by tools/i18n_subset_fonts.py (re-run it after
## translations change); imported with antialiasing / hinting / subpixel off and no system fallback.
## The size is the font's fixed_size, so it draws at that exact integer size whatever size the label
## asks for: Fusion Pixel 10 px (its native grid; 20 = exactly 2x), Noto Thai / Devanagari drawn
## 1-bit (no pixel fonts exist for them), Noto Kufi Arabic 12 (titles 16) drawn 1-bit and shaped by
## HarfBuzz (contextual forms from its GSUB; subset metrics fitted to its ink). Traditional
## Chinese uses Fusion's 12 px build (24 = 2x): its 10 px build draws dense Traditional characters on a
## 9x9 grid where 繁 / 體 read as 無 / 罶 (fonts.md section 0).
const SCRIPT_FONTS := {
	"zh_CN": ["res://assets/fonts/cjk/slime_cjk_zh_cn.woff2", 10, 20],
	"zh_TW": ["res://assets/fonts/cjk/slime_cjk_zh_tw.woff2", 12, 24],
	"ja": ["res://assets/fonts/cjk/slime_cjk_ja.woff2", 10, 20],
	"ko": ["res://assets/fonts/cjk/slime_cjk_ko.woff2", 10, 20],
	"th": ["res://assets/fonts/thai/slime_thai.woff2", 11, 16],
	"hi": ["res://assets/fonts/devanagari/slime_devanagari.woff2", 14, 18],
	"ar": ["res://assets/fonts/arabic/slime_arabic.woff2", 12, 16],
}
## Only the CURRENT locale's fallback goes on the shared slimy fonts: Godot's Font.get_ascent /
## get_height include every fallback, so a tall unused fallback (Devanagari, 19 px) would push every
## English label down and grow every button. English and the other Latin / Cyrillic locales therefore
## get no fallback at all (pixel-identical); text in another script on the same screen (the LANGUAGE
## screen's native names) uses native_font(code), a variation of the slimy font with that script's
## fallback.
const FALLBACK_ORDER := ["zh_CN", "zh_TW", "ja", "ko", "th", "hi", "ar"]
## Line metrics per script group, in px at 320x180 (fonts.md sections 3.3 and 5, measured with the
## real fonts by tests/test_i18n_glyphs.gd):
## - line_h: a line box's height (the slimy font's is its 7 px letter body; a fallback's line box is
##   its own ascent + descent, which Godot uses for any line that contains one of its glyphs);
## - ink_above / ink_below: rows drawn outside that box (accents above, drips / descending marks below);
## - line_pitch / dense_pitch: the pitch of stacked one-line labels (UIKit.LINE_PITCH / DENSE_PITCH);
## - button_h: the smallest button that holds a line with its marks (UIKit.BUTTON_H); with the slimy
##   font 13 + ink_above, so the highest mark starts under the goo's lump row (row 2), as English capitals
##   do: a 15 px accented button put acutes on that row and diaereses right under it (ZURÜCK, WRÓĆ);
## - title_line_h / title_above: the 16 px title's line box and the rows its accents draw above it
##   (UIKit.title_top / title_h make the room: docs/ui-rules.md section 10);
## - ink_nudge: rows a line's text box moves down (from centred) inside a button / pod so the
##   script's letter body sits on the box's middle: Thai and Devanagari keep more empty room under
##   the body than above it (measured on rendered BACK buttons, --write-movie: th 1 and hi 1 put the
##   body 0 px off centre; the LANGUAGE screen's INK_NUDGE centres whole names, marks included);
## - ink_drop (CJK only, else 0): rows the script's letters reach below the slimy body's last row
##   (ascent - 1): the ideographs sit 1 row lower (measured on rendered checkboxes, UIKit.align_checkbox).
## English ("latin") is exactly today's UIKit numbers; only the other groups add head room.
const METRICS := {
	"latin": {line_h = 7, ink_above = 0, ink_below = 2, line_pitch = 12, dense_pitch = 11, button_h = 13, title_line_h = 14, title_above = 0, ink_nudge = 0},
	"accented": {line_h = 7, ink_above = 3, ink_below = 2, line_pitch = 12, dense_pitch = 12, button_h = 16, title_line_h = 14, title_above = 6, ink_nudge = 0},
	"vi": {line_h = 7, ink_above = 5, ink_below = 2, line_pitch = 14, dense_pitch = 14, button_h = 18, title_line_h = 14, title_above = 10, ink_nudge = 0},
	"cjk": {line_h = 14, ink_above = 0, ink_below = 0, line_pitch = 15, dense_pitch = 14, button_h = 16, title_line_h = 28, title_above = 0, ink_nudge = 0, ink_drop = 1},
	"zh_TW": {line_h = 16, ink_above = 0, ink_below = 0, line_pitch = 17, dense_pitch = 16, button_h = 18, title_line_h = 32, title_above = 0, ink_nudge = 0, ink_drop = 1},
	"th": {line_h = 17, ink_above = 0, ink_below = 0, line_pitch = 18, dense_pitch = 17, button_h = 19, title_line_h = 25, title_above = 0, ink_nudge = 1},
	"hi": {line_h = 19, ink_above = 0, ink_below = 0, line_pitch = 20, dense_pitch = 19, button_h = 21, title_line_h = 25, title_above = 0, ink_nudge = 1},
	"ar": {line_h = 19, ink_above = 0, ink_below = 0, line_pitch = 20, dense_pitch = 19, button_h = 21, title_line_h = 25, title_above = 0, ink_nudge = 0},
}
## A smaller crisp size of a locale's script font (8 px text), for UIKit.fit_text's last step: only
## where one exists. Devanagari reads at 12 (fonts.md 2.4: "12 minimum"); Noto Kufi Arabic merges
## dots under 12, Thai has no tested smaller size, and the CJK subsets are the 10 / 12 px builds only
## (Fusion 10 px draws dense Traditional characters wrongly). The slimy font has no size under 8.
const SMALLER_FONT_PX := {"hi": 12}
## Locales whose text needs the accent head room (es, pt_BR, fr, de, it, pl, tr, ru); id uses no
## marks, so it keeps the English numbers.
const ACCENTED := ["es", "pt_BR", "fr", "de", "it", "ru", "pl", "tr"]

## The locale in use ("en" while the gate is off).
var locale := SOURCE_LOCALE
## True once enable() ran (the gate was on): catalogs loaded, locale applied.
var active := false
var _loaded: Array[Translation] = []
var _locale_before := ""
## Fixed-size copies of the fallback fonts: code -> [8 px text copy, 16 px title copy].
var _fallbacks := {}
var _native := {}
var _fonts_installed := false
## Held so the fonts stay loaded with their fallbacks: a resource nobody references is freed and the
## next load() would bring it back without them (pixel_big.fnt is only held while a title is shown).
var _held_fonts: Array[Font] = []


func _ready() -> void:
	# Labels / Buttons translate their own text once any catalog is loaded; that would also hit seeds,
	# typed text and already translated strings. Every node inherits this from the root.
	get_tree().root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if Economy.languages_on():
		enable()
	else:
		# Gate off: English, explicitly (Godot starts from the OS locale; with no catalog loaded that
		# changes no text, but it must not leak into tr() or locale-aware formatting either).
		TranslationServer.set_locale(SOURCE_LOCALE)


## Codes of every supported locale, in the LANGUAGE screen's order.
static func codes() -> Array[String]:
	var out: Array[String] = []
	for entry: Array in LOCALES:
		out.append(entry[0])
	return out


static func is_supported(code: String) -> bool:
	return code in codes()


## A locale's own name in its own script ("" if unsupported; the test-only pseudo locale shows itself
## pseudo-localized).
static func native_name(code: String) -> String:
	if code == PSEUDO:
		return Loc.pseudolocalize("PSEUDO")
	for entry: Array in LOCALES:
		if entry[0] == code:
			return entry[1]
	return ""


## The supported locale for an OS locale string ("pt_BR", "de-AT", "zh_Hant_HK"...), or "" if none.
static func match_os_locale(os_locale: String) -> String:
	if os_locale.strip_edges() == "":
		return ""
	# Legacy / platform spellings first (Android's in_ID / iw_IL, "de-AT" -> de_AT...).
	var code := TranslationServer.standardize_locale(os_locale.strip_edges().replace("-", "_"))
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


## The locale to use, in this order: an explicit `--lang=xx` (a debug preview, so it beats the save),
## the player's saved choice, the OS locale if supported, English.
static func choose_locale(saved: String, forced: String, os_locale: String) -> String:
	if is_supported(forced) or forced == PSEUDO:
		return forced
	if is_supported(saved):
		return saved
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
	_uninstall_fonts()
	_apply_pseudo(false)
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
	for path: String in CATALOGS:
		if ResourceLoader.exists(path):
			load_catalog(path)


## Pseudo-localization for `--lang=pseudo` (docs/i18n/plan.md section 8): English through
## Loc.pseudolocalize (accented, ~40 % longer, bracketed, placeholders kept). The flag lives in Loc
## because Loc does every lookup; only this autoload sets it.
func _apply_pseudo(on: bool) -> void:
	Loc.pseudo = on


## The metrics group of a locale: "latin" (en, id: today's numbers), "accented", "vi", "cjk" (zh_CN, ja,
## ko: Fusion 10 px), "zh_TW" (Fusion 12 px), "th", "hi", "ar".
static func metrics_group(code: String) -> String:
	if code in ACCENTED or code == PSEUDO:
		return "accented"
	if code in ["zh_CN", "ja", "ko"]:
		return "cjk"
	if code in ["vi", "th", "hi", "ar", "zh_TW"]:
		return code
	return "latin"


## Line / button sizes for `code` (see METRICS), plus `font_px` (the script's pixel size under 8 px
## text) and `font_big_px` (under 16 px titles). English and unknown codes get today's UIKit numbers.
static func metrics(code: String) -> Dictionary:
	var out: Dictionary = METRICS[metrics_group(code)].duplicate()
	var script: Array = SCRIPT_FONTS.get(code, [])
	out["font_px"] = script[1] if script else 8
	out["font_big_px"] = script[2] if script else 16
	return out


## The fallback font for `code`'s script at its fixed size (`big` = the copy used under 16 px titles),
## or null for the locales the slimy font covers.
func fallback_font(code: String, big := false) -> FontFile:
	if not SCRIPT_FONTS.has(code):
		return null
	if not _fallbacks.has(code):
		var spec: Array = SCRIPT_FONTS[code]
		var source: FontFile = load(spec[0])
		var copies: Array[FontFile] = []
		for size: int in [spec[1], spec[2]]:
			var copy: FontFile = source.duplicate()
			copy.fixed_size = size
			copy.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
			copy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			copy.hinting = TextServer.HINTING_NONE
			copy.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			copy.allow_system_fallback = false
			copy.generate_mipmaps = false
			copy.multichannel_signed_distance_field = false
			copies.append(copy)
		_fallbacks[code] = copies
	return _fallbacks[code][1 if big else 0]


## The fonts that must cover `code`'s text: its fallback (if any). With the slimy font in front, this
## is the chain the glyph test checks for each locale.
func font_chain(code: String, big := false) -> Array[Font]:
	var chain: Array[Font] = []
	var own := fallback_font(code, big)
	if own:
		chain.append(own)
	return chain


## The slimy font with `code`'s script fallback (a FontVariation sharing the slimy font's glyphs), for
## text written in another language than the current one: each name on the LANGUAGE screen. The
## slimy font itself for the Latin / Cyrillic locales.
func native_font(code: String, big := false) -> Font:
	var base: Font = load(FONT_BIG_PATH if big else FONT_PATH)
	var own := fallback_font(code, big)
	if own == null:
		return base
	var key := "%s:%s" % [code, big]
	if not _native.has(key):
		var variation := FontVariation.new()
		variation.base_font = base
		var chain: Array[Font] = [own]
		variation.fallbacks = chain
		_native[key] = variation
	return _native[key]


## The slimy 8 px font with `code`'s script at its smaller crisp size (SMALLER_FONT_PX), for text
## that does not fit at the normal size (UIKit.fit_text); null where no smaller size exists. A
## FontVariation: the slimy glyphs (Latin, digits) stay exactly as they are.
func small_font(code: String) -> Font:
	if not SMALLER_FONT_PX.has(code) or not SCRIPT_FONTS.has(code):
		return null
	var key := "%s:small" % code
	if not _native.has(key):
		var copy: FontFile = fallback_font(code).duplicate()
		copy.fixed_size = SMALLER_FONT_PX[code]
		var variation := FontVariation.new()
		variation.base_font = load(FONT_PATH)
		var chain: Array[Font] = [copy]
		variation.fallbacks = chain
		_native[key] = variation
	return _native[key]


## True while the fallbacks are on the slimy fonts (never with the gate off).
func fonts_installed() -> bool:
	return _fonts_installed


## Puts the current locale's fallback (font_chain) on pixel.fnt, pixel_big.fnt and UIKit's tabular
## copy. They are the shared resources behind the Theme default font and every override, so no screen
## needs its own wiring. Latin / Cyrillic locales (English too) get none: their text renders exactly
## as with the gate off. Never called with the gate off.
func _install_fonts() -> void:
	if not active:
		return
	var small: Array[Font] = font_chain(locale, false)
	_held_fonts = [load(FONT_PATH), load(FONT_BIG_PATH), UIKit.tabular_font()]
	_held_fonts[0].fallbacks = small
	_held_fonts[1].fallbacks = font_chain(locale, true)
	_held_fonts[2].fallbacks = small
	_fonts_installed = not small.is_empty()


## Takes the fallbacks off again (disable(), tests).
func _uninstall_fonts() -> void:
	var none: Array[Font] = []
	(load(FONT_PATH) as Font).fallbacks = none
	(load(FONT_BIG_PATH) as Font).fallbacks = none
	UIKit.tabular_font().fallbacks = none
	_held_fonts.clear()
	_fonts_installed = false


## STUB (chunk I, docs/i18n/plan.md section 7 "RTL" + owner answer: full mirroring): the text and
## layout direction for right-to-left locales (is_rtl). Never called with the gate off.
func _apply_direction() -> void:
	pass
