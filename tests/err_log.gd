extends Logger

## Collects engine / script errors while a test runs (OS.add_logger). Warnings and the headless clipboard
## complaint (the COPY / PASTE buttons) are ignored. `count` is the number of errors, `lines` the first few.
## Usage: `const ErrLog := preload("res://tests/err_log.gd")`, `var errlog := ErrLog.new()`, `OS.add_logger(errlog)`.

var count := 0
var lines: Array[String] = []
var max_lines := 10


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array) -> void:
	if error_type == 1 or "Clipboard" in rationale:  # 1 = a warning
		return
	count += 1
	if lines.size() < max_lines:
		lines.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
