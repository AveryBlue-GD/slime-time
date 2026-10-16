extends "res://tests/suite_base.gd"

## The i18n gate (Economy.LANGUAGES_TEST, docs/i18n/plan.md, chunk A). Gate off (the default): no catalog
## in TranslationServer, Loc returns the English source text, auto-translation is off, a save gets no
## [settings] language and the Language autoload refuses to save one. Gate on (languages_force = 1, a test
## catalog tests/data/i18n_test.po): Loc.t translates by context, named placeholders survive reordering,
## plurals follow the catalog's Plural-Forms, the locale choice order is --lang > saved > OS > en, only a
## pick writes [settings] language, save codes never carry it and load_code keeps the device's language.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 60000 -s res://tests/test_i18n_gate.gd

const FIXTURE := "res://tests/data/i18n_test.po"
var test_save := throwaway_save()
var progress: Node
var language: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node_or_null("Language")
	progress.save_path = test_save
	progress.saving_enabled = true
	progress.dev_tools = false
	_check(language != null, "the Language autoload exists")
	_check(not ProjectSettings.has_setting("internationalization/locale/translations")
		or (ProjectSettings.get_setting("internationalization/locale/translations") as PackedStringArray).is_empty(),
		"project.godot lists no translations (Godot never loads any on its own)")
	_gate_off()
	_save_gate_off()
	_flags()
	_choice_order()
	_gate_on()
	_save_gate_on()
	_cleanup()
	_check(TranslationServer.get_loaded_locales().is_empty() and not language.active, "the gate test leaves nothing loaded")
	_result()
	quit(1 if failures else 0)


func _gate_off() -> void:
	_check(not Economy.LANGUAGES_TEST and not Economy.languages_on(), "the languages gate is off by default")
	_check(not language.active and language.loaded_catalogs().is_empty(), "gate off: Language loaded nothing")
	_check(TranslationServer.get_loaded_locales().is_empty(), "gate off: TranslationServer has no translation")
	_check(language.locale == "en" and not language.is_rtl(), "gate off: English, left to right")
	_check(TranslationServer.get_locale() == "en", "gate off: the TranslationServer locale is pinned to English")
	_check(not language.fonts_installed() and (load("res://assets/fonts/pixel.fnt") as Font).fallbacks.is_empty(),
		"gate off: no font fallback")
	_check(root.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "Godot's auto-translation is off at the root")
	var menu := Control.new()
	UIKit.setup_screen(menu, "SETTINGS")
	_check(menu.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "UIKit.setup_screen turns auto-translation off")
	menu.free()
	_check(Loc.t("test.portal.random_maze", "RANDOM MAZE") == "RANDOM MAZE", "gate off: Loc.t returns the English text")
	_check(Loc.t("test.level", "LEVEL {level}/{total}", {level = 3, total = 10}) == "LEVEL 3/10", "gate off: placeholders are filled")
	_check(Loc.t("test.plain", "100% {x}") == "100% {x}", "gate off: no args = the text untouched")
	_check(Loc.n("test.hats_left", "{count} HAT TO WIN", "{count} HATS TO WIN", 1) == "1 HAT TO WIN"
		and Loc.n("test.hats_left", "{count} HAT TO WIN", "{count} HATS TO WIN", 0) == "0 HATS TO WIN"
		and Loc.n("test.hats_left", "{count} HAT TO WIN", "{count} HATS TO WIN", 7) == "7 HATS TO WIN",
		"gate off: Loc.n picks the English singular / plural")
	_check(Loc.n("test.need", "NEED {count} FOR {name}", "NEED {count} FOR {name}", 4, {name = "CAP"}) == "NEED 4 FOR CAP",
		"Loc.n fills {count} and the other args")
	_check(Loc.lines(["A", "B C", 3]) == "A\nB C\n3" and Loc.lines([]) == "", "Loc.lines joins whole lines")
	_check(Loc.t("test.inject", "{name} HAS {count}", {name = "{count}", count = 5}) == "{count} HAS 5",
		"a placeholder value is inserted once, never filled in again")
	_check(Loc.n("test.inject", "{count} {name}", "{count} {name}", 2, {name = "{count}"}) == "2 {count}",
		"... also in Loc.n")
	_check(Loc.t("test.braces", "{a} {b {} }{a}", {a = "X"}) == "X {b {} }X", "unknown placeholders and lone braces stay")
	language.enable()
	_check(not language.active and TranslationServer.get_loaded_locales().is_empty(), "gate off: enable() does nothing")
	language.set_locale("ru")
	_check(language.locale == "en", "gate off: set_locale does nothing")


func _save_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _save_gate_off() -> void:
	_check(progress.language == "", "a fresh save has no language")
	_check(not language.pick("es") and progress.language == "", "gate off: pick() refuses and saves nothing")
	progress.save_progress()
	var text := _save_text(test_save)
	_check(text != "" and not text.contains("language"), "gate off: the save has no language key")
	_check(not progress._write(true).has_section_key("settings", "language"), "gate off: a save code has no language")
	# A save written while the gate was on keeps its choice when the gate is off again.
	var cfg := ConfigFile.new()
	cfg.parse(text)
	cfg.set_value("settings", "language", "pt_BR")
	cfg.save(test_save)
	progress.load_progress()
	_check(progress.language == "pt_BR", "a saved language is read whatever the gate")
	progress.save_progress()
	_check(_save_text(test_save).contains("language=\"pt_BR\""), "gate off: a saved language is written back")
	for bad in ["../x", "ES", "e", "toolonglocale", "es_es"]:
		cfg.set_value("settings", "language", bad)
		cfg.save(test_save)
		progress.load_progress()
		_check(progress.language == "", "a bad saved language (%s) is dropped" % bad)
	cfg.set_value("settings", "language", 7)
	cfg.save(test_save)
	progress.load_progress()
	_check(progress.language == "", "a non-string saved language is dropped")
	progress.language = ""
	progress.save_progress()
	_check(not _save_text(test_save).contains("language"), "no language again after it is cleared")


func _flags() -> void:
	var progress_script: GDScript = load("res://scripts/progress.gd")
	for flag in ["--languages", "--lang=es"]:
		_check(progress_script.game_args(PackedStringArray([flag]), false).is_empty()
			and progress_script.game_args(PackedStringArray([flag]), true) == PackedStringArray([flag]),
			"%s is a debug flag (a release build ignores it)" % flag)


func _choice_order() -> void:
	_check(language.codes().size() == 18 and language.codes()[0] == "en", "18 supported locales, English first")
	_check(language.native_name("ru") == "РУССКИЙ" and language.native_name("ja") == "日本語"
		and language.native_name("xx") == "", "native names in their own script")
	_check(language.choose_locale("de", "fr", "es_MX") == "fr", "an explicit --lang wins")
	_check(language.choose_locale("de", "", "es_MX") == "de", "then the saved choice")
	_check(language.choose_locale("", "pseudo", "es_MX") == "pseudo", "--lang=pseudo is accepted")
	_check(language.choose_locale("xx", "yy", "es_MX") == "es", "then the OS locale's language")
	_check(language.choose_locale("", "", "sv_SE") == "en", "else English")
	_check(language.match_os_locale("pt_PT") == "pt_BR" and language.match_os_locale("zh_Hant_HK") == "zh_TW"
		and language.match_os_locale("zh-TW") == "zh_TW" and language.match_os_locale("zh_Hans_CN") == "zh_CN"
		and language.match_os_locale("zh") == "zh_CN" and language.match_os_locale("de-AT") == "de"
		and language.match_os_locale("") == "", "OS locales map to supported ones")
	_check(language.match_os_locale("in_ID") == "id" and language.match_os_locale("in") == "id",
		"legacy codes (Android's in_ID) are standardized first")


func _gate_on() -> void:
	Economy.languages_force = 1
	Economy.forced_locale = "ru"
	progress.language = ""
	language.enable()
	_check(language.active and language.locale == "ru", "gate on: --lang=xx picks the locale")
	_check(TranslationServer.get_locale() == "ru", "gate on: TranslationServer follows")
	_check(language.load_catalog(FIXTURE), "the test catalog loads")
	_check("ru" in TranslationServer.get_loaded_locales(), "gate on: the catalog is in TranslationServer")
	_check(Loc.t("test.portal.random_maze", "RANDOM MAZE") == "СЛУЧАЙНЫЙ ЛАБИРИНТ", "gate on: Loc.t translates")
	_check(Loc.t("test.other", "RANDOM MAZE") == "ДРУГОЙ ЛАБИРИНТ", "the context picks the entry")
	_check(Loc.t("test.missing", "NOT IN THE CATALOG {n}", {n = 2}) == "NOT IN THE CATALOG 2", "a missing entry falls back to English")
	_check(Loc.t("test.level", "LEVEL {level}/{total}", {level = 3, total = 10}) == "10:3 УРОВЕНЬ", "named placeholders survive a new word order")
	var forms := {1: "1 ШЛЯПА", 2: "2 ШЛЯПЫ", 4: "4 ШЛЯПЫ", 5: "5 ШЛЯП", 11: "11 ШЛЯП", 21: "21 ШЛЯПА", 22: "22 ШЛЯПЫ", 0: "0 ШЛЯП"}
	for count: int in forms:
		_check(Loc.n("test.hats_left", "{count} HAT TO WIN", "{count} HATS TO WIN", count) == forms[count],
			"plural form for %d: %s" % [count, forms[count]])
	var seen: Array[String] = []
	var on_change := func(code: String) -> void: seen.append(code)
	language.language_changed.connect(on_change)
	language.set_locale("ar")
	_check(seen == ["ar"] and language.is_rtl(), "language_changed fires; Arabic is right to left")
	_check(Loc.t("test.portal.random_maze", "RANDOM MAZE") == "RANDOM MAZE", "a locale without a catalog shows English")
	language.set_locale("ar")
	_check(seen.size() == 1, "no signal when the locale stays the same")
	language.set_locale("xx")
	_check(language.locale == "ar", "an unknown locale is ignored")
	language.language_changed.disconnect(on_change)
	language.set_locale("ru")
	_check(progress.language == "", "gate on: a locale from --lang / set_locale is not saved")


func _save_gate_on() -> void:
	progress.save_progress()
	_check(not _save_text(test_save).contains("language"), "gate on: no language key until the player picks one")
	_check(language.pick("de") and progress.language == "de" and language.locale == "de", "pick() switches and remembers")
	_check(_save_text(test_save).contains("language=\"de\""), "pick() writes [settings] language")
	_check(not language.pick("pseudo") and not language.pick("xx") and progress.language == "de", "pick() refuses pseudo / unknown codes")
	var code: String = progress.save_code()
	var decoded: ConfigFile = progress.read_code(code)
	_check(decoded != null and not decoded.has_section_key("settings", "language"), "a save code never carries the language")
	progress.language = "fr"
	_check(progress.load_code(code) and progress.language == "fr", "load_code keeps the device's language")
	_check(_save_text(test_save).contains("language=\"fr\""), "... and the save written after it keeps it too")
	progress.load_progress()
	_check(progress.language == "fr", "the saved choice reads back")
	Economy.forced_locale = "es"
	language.enable()
	_check(language.locale == "es" and progress.language == "fr", "gate on: an explicit --lang beats the saved choice (not saved)")
	Economy.forced_locale = ""
	language.enable()
	_check(language.locale == "fr", "gate on: without --lang the saved choice is used")


func _cleanup() -> void:
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	progress.language = ""
	_check(not Economy.languages_on() and Loc.t("test.portal.random_maze", "RANDOM MAZE") == "RANDOM MAZE",
		"gate back off: English again")
