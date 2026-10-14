extends SceneTree

## QA proof of concept (not run by test_all.sh): Progress._decode_code calls
## PackedByteArray.decompress_dynamic(.., COMPRESSION_GZIP) on whatever base64 a player pastes.
## A gzip stream followed by ANY extra bytes (a code pasted twice without padding, a stray "AAAA"
## typed after it, a hostile code) makes decompress_dynamic loop forever at 100% CPU: the game freezes
## while the text box is only being checked (is_old_code runs on every paste / LOAD).
## DEFLATE hangs the same way; ZSTD and the fixed-size decompress(isize, GZIP) do not.
## Run (it will not finish, kill it): ./tools/godot.sh --path . --headless -s res://tests/qa_poc_gzip_hang.gd -- --extra=1
## --extra=0 shows the well-formed code reading fine.
const PROGRESS_SCRIPT := preload("res://scripts/progress.gd")

func _initialize() -> void:
	var extra := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--extra="):
			extra = int(arg.get_slice("=", 1))
	var gz := "[meta]\nepoch=1\n[progress]\nlevels_cleared=3\n".to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	for i in extra:
		gz.append(0)
	while gz.size() % 3 != 0:  # keep the base64 unpadded and a multiple of 4 characters
		gz.append(0)
	var code: String = PROGRESS_SCRIPT.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(gz)
	print("calling is_old_code on a %d char code (gzip + %d extra bytes)..." % [code.length(), gz.size() - 63])
	print("is_old_code -> ", PROGRESS_SCRIPT.is_old_code(code))
	print("RESULT: returned (no hang)")
	quit()
