extends "res://tests/suite_base.gd"

## i18n fonts (docs/i18n/plan.md chunk D, docs/i18n/fonts.md). Data-driven: every character of every
## msgstr in locale/*.po, every native language name and a built-in sample of each locale's letters
## resolves to a glyph in that locale's font chain (the slimy pixel.fnt / pixel_big.fnt, then the
## locale's fallback), i.e. no tofu. Also: the original 86 glyphs' atlas is untouched (English stays
## pixel-identical), lowercase letters share their capital's glyph, the atlases match what
## text_drips.gdshader looks for, the fallbacks are imported crisp (no antialiasing / hinting /
## subpixel / system fallback) with their license next to them, only the current locale's fallback is
## installed (none for English), and Lang.metrics matches the real fonts.
## When this fails after a translation update: run python3 tools/i18n_subset_fonts.py and re-import.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 60000 -s res://tests/test_i18n_glyphs.gd
## English-only mode (tests/i18n_mode.gd): a check made while a non-English locale is set is reported, not failed.
const I18N_PER_LOCALE := true

const Lang := preload("res://scripts/language.gd")
const LOCALE_DIR := "res://locale"
## pixel.png as generated before the i18n work: the 86 English glyphs must stay byte-identical.
const PIXEL_PNG_MD5 := "d757ad8f711f8c2ec0e1e65a099b736f"
const PIXEL_BIG_PNG_MD5 := "e1cc2d99b743886aace2b703b875a56f"
## Letters each locale needs even before its translation exists (fonts.md section 3.1; CJK / Thai /
## Devanagari / Arabic samples are characters the base subsets always carry).
const SAMPLES := {
	"en": "ABCXYZ abcxyz 0123456789 .,!?:;'\"-+=_/%#()[]<>*&",
	"es": "ÁÉÍÓÚÜÑ¿¡ºª«» áéíóúüñ",
	"pt_BR": "ÁÂÃÀÇÉÊÍÓÔÕÚºª áâãàçéêíóôõú",
	"fr": "ÀÂÆÇÉÈÊËÎÏÔŒÙÛÜŸ«»’ àâæçéèêëîïôœùûüÿ  ",
	"de": "ÄÖÜẞß„“ äöü",
	"it": "ÀÈÉÌÒÙÍÓÚÎ’ àèéìòù",
	"ru": "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ абвгдеёжзийклмнопрстуфхцчшщъыьэюя«»„“№—",
	"pl": "ĄĆĘŁŃÓŚŹŻ„” ąćęłńóśźż",
	"tr": "ÇĞİÖŞÜÂÎÛ çğıöşü",
	"id": "ABC",
	"vi": "ÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÝĂĐĨŨƠƯẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼẾỀỂỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪỬỮỰỲỴỶỸ àáâãđơưạảấầẩẫậắằẳẵặỹ",
	"ja": "あいうアイウ。、「」ー",
	"ko": "，！？",
	"zh_CN": "，。！？、",
	"zh_TW": "，。！？、",
	"th": "กขคงจฉชซญฐฎฏดตถทธนบปผฝพฟภมยรลวศษสหฬอฮะาำิีึืุูเแโใไ่้๊๋์​",
	"hi": "अआइईउऊएऐओऔकखगघचछजझटठडढणतथदधनपफबभमयरलवशषसहािीुूेैोौंः्।",
	"ar": "ابتثجحخدذرزسشصضطظعغفقكلمنهوي،؟",
}

var language: Node


func _initialize() -> void:
	await process_frame
	language = root.get_node("Language")
	_atlas()
	_lowercase()
	_fallback_imports()
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	_installed()
	_coverage()
	_metrics()
	_arabic_joining()
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	_check((load(Lang.FONT_PATH) as Font).fallbacks.is_empty(), "disable() takes every fallback off again")
	_result()
	quit(1 if failures else 0)


func _atlas() -> void:
	_check(FileAccess.get_md5("res://assets/fonts/pixel.png") == PIXEL_PNG_MD5
		and FileAccess.get_md5("res://assets/fonts/pixel_big.png") == PIXEL_BIG_PNG_MD5,
		"the original 86-glyph atlases are byte-identical (English renders as before)")
	var font: FontFile = load(Lang.FONT_PATH)
	var big: FontFile = load(Lang.FONT_BIG_PATH)
	_check(font.get_ascent(8) == 7.0 and font.get_height(8) == 7.0 and big.get_height(16) == 14.0,
		"line metrics unchanged (7 px body, 14 at 2x)")
	# One-row atlases the drip shader recognizes: 9 / 18 px tall (page 0) and 14 / 28 (the i18n page).
	var sizes := {"pixel.png": Vector2i(0, 9), "pixel_big.png": Vector2i(0, 18), "pixel_ext.png": Vector2i(0, 14),
		"pixel_big_ext.png": Vector2i(0, 28)}
	for file: String in sizes:
		var image := Image.load_from_file("res://assets/fonts/" + file)
		var min_w := 400 if "big" in file else 200
		_check(image != null and image.get_height() == sizes[file].y and image.get_width() > min_w,
			"%s is one row, %d px tall, wider than %d (text_drips.gdshader's check)" % [file, sizes[file].y, min_w])
	var shader := FileAccess.get_file_as_string("res://assets/shaders/text_drips.gdshader")
	_check(shader.contains("atlas.y - 9.0") and shader.contains("atlas.y - 18.0") and shader.contains("atlas.y - 14.0")
		and shader.contains("atlas.y - 28.0"), "the drip shader checks all four atlas heights")
	var size := Vector2i(8, 0)
	var a := "A".unicode_at(0)
	_check(font.get_glyph_uv_rect(0, size, a) == Rect2(0, 0, 5, 9) and font.get_glyph_texture_idx(0, size, a) == 0,
		"A is still the first glyph of page 0")
	var e_acute := "É".unicode_at(0)
	_check(font.get_glyph_texture_idx(0, size, e_acute) == 1 and font.get_glyph_offset(0, size, e_acute).y
		< font.get_glyph_offset(0, size, a).y, "accented letters live on page 1, drawn above the line box")


func _lowercase() -> void:
	var font: FontFile = load(Lang.FONT_PATH)
	var bad := PackedStringArray()
	for pair: String in ["Éé", "Żż", "Жж", "Ёё", "Ữữ", "Đđ", "Ơơ", "Ææ", "Œœ", "Łł", "ẞß", "Йй", "Аа", "Ii", "Iı"]:
		var upper := pair.unicode_at(0)
		var lower := pair.unicode_at(1)
		if not font.has_char(lower) or font.get_glyph_uv_rect(0, Vector2i(8, 0), upper) != font.get_glyph_uv_rect(0, Vector2i(8, 0), lower):
			bad.append(pair)
	_check(bad.is_empty(), "lowercase letters draw their capital's glyph %s" % [bad])
	var a := "A".unicode_at(0)
	var cyr_a := "А".unicode_at(0)
	_check(font.get_glyph_uv_rect(0, Vector2i(8, 0), cyr_a) == font.get_glyph_uv_rect(0, Vector2i(8, 0), a),
		"Cyrillic letters shaped like Latin ones reuse the Latin glyph")


func _fallback_imports() -> void:
	for code: String in Lang.SCRIPT_FONTS:
		var spec: Array = Lang.SCRIPT_FONTS[code]
		var path: String = spec[0]
		var source := load(path) as FontFile
		_check(source != null, "%s loads" % path)
		if source == null:
			continue
		_check(source.antialiasing == TextServer.FONT_ANTIALIASING_NONE and source.hinting == TextServer.HINTING_NONE
			and source.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_DISABLED and not source.allow_system_fallback
			and not source.generate_mipmaps and not source.multichannel_signed_distance_field,
			"%s is imported crisp: no antialiasing, hinting, subpixel, mipmaps, MSDF or system fallback" % path.get_file())
		_check(FileAccess.file_exists(path.get_base_dir().path_join("OFL.txt")), "%s has its license next to it" % path.get_file())
		var copy: FontFile = language.fallback_font(code)
		var big: FontFile = language.fallback_font(code, true)
		_check(copy.fixed_size == spec[1] and big.fixed_size == spec[2]
			and copy.fixed_size_scale_mode == TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY, "%s draws at %d / %d px" % [code, spec[1], spec[2]])


func _installed() -> void:
	var font: Font = load(Lang.FONT_PATH)
	_check(language.active and font.fallbacks.is_empty() and not language.fonts_installed(),
		"gate on, English: no fallback on the slimy font (Font.get_height counts every fallback)")
	language.set_locale("fr")
	_check(font.fallbacks.is_empty(), "French: the slimy font alone")
	language.set_locale("ja")
	_check(_only(font.fallbacks, language.fallback_font("ja"))
		and _only((load(Lang.FONT_BIG_PATH) as Font).fallbacks, language.fallback_font("ja", true))
		and _only(UIKit.tabular_font().fallbacks, language.fallback_font("ja")),
		"Japanese: its own fallback on the 8 px, 16 px and tabular fonts")
	language.set_locale("en")
	_check(font.fallbacks.is_empty(), "back to English: the fallback is gone")
	_check(language.native_font("en") == font and _only(language.native_font("th").fallbacks, language.fallback_font("th")),
		"native_font: the slimy font, or a variation with that script's fallback")


static func _only(fonts: Array[Font], font: Font) -> bool:
	return fonts.size() == 1 and fonts[0] == font


## Every character of `text` the chain (slimy font, then `code`'s fallback) can't draw.
func _missing(code: String, text: String, big := false) -> String:
	var chain: Array[Font] = [load(Lang.FONT_BIG_PATH if big else Lang.FONT_PATH)]
	chain.append_array(language.font_chain(code, big))
	var out := ""
	for i in text.length():
		var c := text.unicode_at(i)
		if c == 10 or c == 13 or text[i] in out:
			continue
		var found := false
		for font in chain:
			if font.has_char(c):
				found = true
				break
		if not found:
			out += text[i]
	return out


func _coverage() -> void:
	for code: String in SAMPLES:
		var missing := _missing(code, SAMPLES[code])
		_check(missing == "", "%s: the sample letters have glyphs %s" % [code, missing])
		_check(_missing(code, SAMPLES[code], true) == "", "%s: ... also in the 16 px font" % code)
	for code: String in Lang.codes():
		var name: String = Lang.native_name(code)
		_check(_missing(code, name) == "" and _missing(code, name, true) == "", "%s: its native name %s has glyphs" % [code, name])
	var catalogs := 0
	if DirAccess.dir_exists_absolute(LOCALE_DIR):
		for file in DirAccess.get_files_at(LOCALE_DIR):
			if not file.ends_with(".po"):
				continue
			var code := file.get_basename()
			if not Lang.is_supported(code):
				continue
			catalogs += 1
			# Placeholders ({count}, {name}...) are filled in at run time and never drawn as written:
			# their braces and names are not checked, the literal text around them is.
			# Entries marked "mixed case" (the web shell's, drawn by the browser) are left out.
			var text := _strip_placeholders(po_text(LOCALE_DIR.path_join(file), true))
			var missing := _missing(code, text)
			_check(missing == "", "%s.po: every translated character has a glyph %s" % [code, missing])
			if code == "tr":
				# Mixed-case entries (browser dialogs, drawn by the browser) may use ı / i; the brand stays English.
				var bare := _strip_placeholders(po_text(LOCALE_DIR.path_join(file), true)).replace("Slime Time", "")
				_check(not bare.contains("i") and not bare.contains("ı"),
					"tr.po writes capitals (İ / I): a lowercase i would draw as I")
	print("  (%d catalogs checked)" % catalogs)


## Every msgstr of a .po file (all plural forms, not the header), escapes resolved. `skip_mixed_case`:
## leave out the entries whose notes say "mixed case" (browser dialogs, not drawn with our fonts).
static func po_text(path: String, skip_mixed_case := false) -> String:
	var out := PackedStringArray()
	var part := ""  # "msgid", "msgstr" or "" (comments, msgctxt...)
	var msgid := ""
	var mixed := false
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		var value := line.substr(line.find("\"") + 1).trim_suffix("\"") if line.contains("\"") else ""
		if line == "":
			mixed = false
		elif line.begins_with("#.") and line.contains("mixed case"):
			mixed = skip_mixed_case
		if mixed:
			part = ""
			continue
		if line.begins_with("msgid "):
			part = "msgid"
			msgid = value
		elif line.begins_with("msgid_plural"):
			part = "plural"
		elif line.begins_with("msgstr"):
			part = "msgstr"
			if msgid != "":
				out.append(value)
		elif line.begins_with("\""):
			if part == "msgid":
				msgid += value
			elif part == "msgstr" and msgid != "":
				out.append(value)
		else:
			part = ""
	return "".join(out).replace("\\n", "\n").replace("\\\"", "\"").replace("\\t", " ").replace("\\\\", "\\")


static func _strip_placeholders(text: String) -> String:
	var regex := RegEx.create_from_string("\\{[A-Za-z_][A-Za-z0-9_]*\\}")
	return regex.sub(text, "", true)


func _metrics() -> void:
	var en: Dictionary = Lang.metrics("en")
	_check(en.line_pitch == UIKit.LINE_PITCH and en.dense_pitch == UIKit.DENSE_PITCH and en.button_h == UIKit.BUTTON_H
		and en.font_px == UIKit.FONT and en.font_big_px == UIKit.FONT_BIG and en.ink_above == 0,
		"English metrics are today's UIKit numbers (no head room)")
	_check(Lang.metrics("id") == en and Lang.metrics("xx") == en, "Indonesian / unknown: the English numbers")
	_check(Lang.metrics("fr").ink_above == 3 and Lang.metrics("vi").ink_above == 5 and Lang.metrics("vi").line_pitch == 14,
		"accent head room only for the accented locales (3 rows, Vietnamese 5)")
	for code: String in Lang.SCRIPT_FONTS:
		var m: Dictionary = Lang.metrics(code)
		var font: FontFile = language.line_font(code)  # (the installed 8 px fallback: Devanagari's trimmed line box)
		var big: FontFile = language.fallback_font(code, true)
		var line := int(maxf(7.0, font.get_ascent(8)) + font.get_descent(8))
		var title := int(maxf(14.0, big.get_ascent(16)) + big.get_descent(16))
		_check(m.line_h == line and m.title_line_h == title and m.line_pitch > m.line_h and m.button_h >= m.line_h + 2,
			"%s metrics match the font: line %d (table %d), title %d (table %d)" % [code, line, m.line_h, title, m.title_line_h])


## Arabic letters must join (fonts.md: the Unifont stand-in drew them isolated). Shapes each word with
## the Arabic fallback through the primary (Advanced) text server and compares it with each of its
## letters shaped alone: a joined word uses contextual glyphs (initial / medial / final forms from the
## font's GSUB) that no isolated letter uses.
func _arabic_joining() -> void:
	var ts := TextServerManager.get_primary_interface()
	_check(ts.has_feature(TextServer.FEATURE_SHAPING) and ts.has_feature(TextServer.FEATURE_BIDI_LAYOUT),
		"the text server shapes text and lays out bidi (Advanced)")
	var font: Font = language.native_font("ar")
	var size := int(Lang.metrics("ar").font_px)
	for word: String in ["العربية", "رجوع", "اللغة"]:
		var isolated := {}
		for i in word.length():
			for index in _glyph_indices(ts, word[i], font, size):
				isolated[index] = true
		var contextual := 0
		var glyphs := _glyph_indices(ts, word, font, size)
		for index in glyphs:
			if not isolated.has(index):
				contextual += 1
		var letters := word.length()
		_check(contextual >= letters - 2,
			"Arabic joins: %s uses %d contextual glyphs for %d letters (%d glyphs)" % [word, contextual, letters, glyphs.size()])


static func _glyph_indices(ts: TextServer, text: String, font: Font, size: int) -> Array[int]:
	var rid := ts.create_shaped_text(TextServer.DIRECTION_RTL)
	ts.shaped_text_add_string(rid, text, font.get_rids(), size, {}, "ar")
	var out: Array[int] = []
	for glyph: Dictionary in ts.shaped_text_get_glyphs(rid):
		if glyph.get("index", 0) != 0:
			out.append(glyph.index)
	ts.free_rid(rid)
	return out
