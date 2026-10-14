extends RefCounted

## Untrusted save text (a save.cfg on disk or the inside of a pasted save code) is checked here BEFORE
## Godot's ConfigFile ever sees it. ConfigFile.parse/load understand the whole Variant text syntax,
## including `Object(Node, "script": Object(GDScript, "script/source": "..."))`, which instantiates
## objects and RUNS embedded GDScript while parsing, and they recurse without a depth limit (200,000
## nested '[' crash the process). So nothing untrusted is ever handed to ConfigFile unless it passes
## this ALLOW-LIST (docs/qa-release-report.md S1, S10, S11):
##   - size <= MAX_BYTES, every line <= MAX_LINE bytes, valid UTF-8, no control bytes but tab/CR/LF,
##   - statements: `[section]` headers, `key=value` lines, `;` comment lines (no quotes/brackets/=),
##   - values: numbers, "strings" (escapes are skipped exactly like Godot's parser does), true, false,
##     null, nan, inf, inf_neg, [arrays], {dictionaries} with string/int keys, and ONLY the constructors
##     Progress._write actually writes: Color(4 numbers), Array[int]([ints]), Array[String](["strings"]),
##   - nesting depth <= MAX_DEPTH, one value per line (nothing may follow it but spaces).
## Any other identifier (Object, Resource, Callable, Signal, RID, Script, ExtResource, preload, lookalike
## letters, other case...) or any syntax error rejects the WHOLE text: the caller treats it as a corrupt
## save / a code that doesn't work. Words like "Object(" inside a quoted string are just string data.
## After parsing, every value's type is checked again (defense in depth).
## Used through Progress (load_progress, read_code); tests: test_save_robust.gd (_injection, _validator).

## The largest save text accepted (real saves are about 2-15 KB; a full one with every map ~20 KB).
const MAX_BYTES := 256 * 1024
## The longest line accepted (real lines are under 1 KB).
const MAX_LINE := 64 * 1024
## Deepest nesting of [ { ( accepted (real saves nest 2: Array[int]([..])).
const MAX_DEPTH := 8
## Longest section / key name.
const MAX_NAME := 64

const _T_FAIL := -1
const _T_INT := 0
const _T_FLOAT := 1
const _T_STRING := 2
const _T_OTHER := 3

const _KEYWORDS := ["true", "false", "null", "nan", "inf", "inf_neg"]


## The ConfigFile for `bytes`, or null when they are not a safe, well-formed save text.
## A leading UTF-8 byte order mark is ignored.
static func parse(bytes: PackedByteArray) -> ConfigFile:
	var b := strip_bom(bytes)
	if not is_safe(b):
		return null
	var file := ConfigFile.new()
	if file.parse(b.get_string_from_utf8()) != OK or not values_ok(file):
		return null
	return file


## True if `bytes` pass the allow-list (see the header). Never calls into Godot's Variant parser.
static func is_safe(bytes: PackedByteArray) -> bool:
	if bytes.size() > MAX_BYTES or not _lines_ok(bytes) or not utf8_ok(bytes):
		return false
	var scanner := _Scanner.new(bytes)
	return scanner.run()


## True if a file's contents are empty or only whitespace (nothing worth keeping as a backup).
static func is_blank(bytes: PackedByteArray) -> bool:
	for c in bytes:
		if not (c == 32 or c == 9 or c == 10 or c == 13):
			return false
	return true


static func strip_bom(bytes: PackedByteArray) -> PackedByteArray:
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		return bytes.slice(3)
	return bytes


## Decompresses a save code's gzip stream without ever looping: the stream's own ISIZE trailer (the
## last 4 bytes) says how big the text is; it must be 1..MAX_BYTES, the bytes are inflated ONCE into a
## buffer of exactly that size (PackedByteArray.decompress, a single bounded inflate call) and the result
## must have exactly that size. decompress_dynamic is never used: it spins forever on a gzip stream
## followed by extra bytes (S10). Returns an empty array for anything that isn't such a stream.
static func gunzip(packed: PackedByteArray) -> PackedByteArray:
	if packed.size() < 18 or packed[0] != 0x1F or packed[1] != 0x8B or packed[2] != 8:
		return PackedByteArray()
	var isize := packed.decode_u32(packed.size() - 4)
	if isize < 1 or isize > MAX_BYTES:
		return PackedByteArray()
	var out := packed.decompress(isize, FileAccess.COMPRESSION_GZIP)
	if out.size() != isize:
		return PackedByteArray()
	return out


## Every value in a parsed file is plain data (defense in depth: the allow-list already guarantees it).
static func values_ok(file: ConfigFile) -> bool:
	for section in file.get_sections():
		for key in file.get_section_keys(section):
			if not _plain(file.get_value(section, key), 0):
				return false
	return true


static func _plain(v: Variant, depth: int) -> bool:
	if depth > MAX_DEPTH:
		return false
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_COLOR:
			return true
		TYPE_ARRAY:
			for item: Variant in v:
				if not _plain(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for k: Variant in v:
				if not _plain(k, depth + 1) or not _plain(v[k], depth + 1):
					return false
			return true
	return false


static func _lines_ok(bytes: PackedByteArray) -> bool:
	var start := 0
	var at := bytes.find(10)
	while at != -1:
		if at - start > MAX_LINE:
			return false
		start = at + 1
		at = bytes.find(10, start)
	return bytes.size() - start <= MAX_LINE


## Strict UTF-8 (no overlongs, no surrogates, <= U+10FFFF), so decoding it never logs errors.
static func utf8_ok(bytes: PackedByteArray) -> bool:
	var i := 0
	var n := bytes.size()
	while i < n:
		var c := bytes[i]
		if c < 0x80:
			i += 1
			continue
		var extra := 0
		var lo := 0x80
		var hi := 0xBF
		if c >= 0xC2 and c <= 0xDF:
			extra = 1
		elif c >= 0xE0 and c <= 0xEF:
			extra = 2
			if c == 0xE0:
				lo = 0xA0
			elif c == 0xED:
				hi = 0x9F
		elif c >= 0xF0 and c <= 0xF4:
			extra = 3
			if c == 0xF0:
				lo = 0x90
			elif c == 0xF4:
				hi = 0x8F
		else:
			return false
		if i + extra >= n:
			return false
		for k in extra:
			var d := bytes[i + 1 + k]
			if k == 0:
				if d < lo or d > hi:
					return false
			elif d < 0x80 or d > 0xBF:
				return false
		i += extra + 1
	return true


## A one-pass recursive-descent checker over the bytes (depth-limited, so it can't overflow either).
class _Scanner:
	var b: PackedByteArray
	var i := 0
	var n := 0

	func _init(bytes: PackedByteArray) -> void:
		b = bytes
		n = bytes.size()

	func run() -> bool:
		while i < n:
			var c := b[i]
			if c == 32 or c == 9 or c == 13 or c == 10:
				i += 1
			elif c == 91:  # [
				if not _section():
					return false
			elif c == 59:  # ; comment line
				if not _comment():
					return false
			elif not _assign():
				return false
		return true

	func _section() -> bool:
		i += 1
		if _name() == "" or not _eat(93):  # ]
			return false
		return _eol()

	## A `;` comment line. Godot only skips ';' comments; whatever it does with the line, it can't
	## start a string, a value, a tag or an assignment there because none of = " [ ] { } ( ) \ may appear.
	func _comment() -> bool:
		while i < n and b[i] != 10:
			var c := b[i]
			if c < 32 and c != 9 and c != 13:
				return false
			if c in [61, 34, 91, 93, 123, 125, 40, 41, 92]:
				return false
			i += 1
		return true

	func _assign() -> bool:
		if _name() == "":
			return false
		_spaces()
		if not _eat(61):  # =
			return false
		_spaces()
		if _value(0, false) == _T_FAIL:
			return false
		return _eol()

	## Only spaces/tabs/CR, then a newline or the end.
	func _eol() -> bool:
		_spaces()
		if i >= n:
			return true
		if b[i] == 10:
			i += 1
			return true
		return false

	func _spaces() -> void:
		while i < n and (b[i] == 32 or b[i] == 9 or b[i] == 13):
			i += 1

	## Whitespace inside brackets may include newlines (Godot's tokenizer skips them there too).
	func _ws() -> void:
		while i < n and (b[i] == 32 or b[i] == 9 or b[i] == 13 or b[i] == 10):
			i += 1

	func _eat(c: int) -> bool:
		if i < n and b[i] == c:
			i += 1
			return true
		return false

	## [A-Za-z0-9_]+ (at most MAX_NAME), or "" if there is none / it is too long.
	func _name() -> String:
		var start := i
		while i < n and _word_char(b[i]):
			i += 1
		if i == start or i - start > MAX_NAME:
			return ""
		return b.slice(start, i).get_string_from_ascii()

	static func _word_char(c: int) -> bool:
		return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95

	## Checks one value and returns its kind (T_INT, T_FLOAT, T_STRING, T_OTHER) or T_FAIL.
	func _value(depth: int, nested: bool) -> int:
		if depth > MAX_DEPTH:
			return _T_FAIL
		if nested:
			_ws()
		if i >= n:
			return _T_FAIL
		var c := b[i]
		if c == 34:  # "
			return _string()
		if c == 45 or (c >= 48 and c <= 57):  # - or digit
			return _number()
		if c == 91:  # [
			return _array(depth + 1, -1)
		if c == 123:  # {
			return _dict(depth + 1)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			var word := _name()
			if word in _KEYWORDS:
				return _T_FLOAT if word.begins_with("nan") or word.begins_with("inf") else _T_OTHER
			if word == "Color":
				return _color(depth + 1)
			if word == "Array":
				return _typed_array(depth + 1)
		return _T_FAIL  # any other identifier, & or ^ strings, symbols...

	## A "..." string; a backslash always skips the next byte (Godot's parser treats every escape as
	## one escaped character, \uXXXX's digits are plain characters after that).
	func _string() -> int:
		i += 1
		while i < n:
			var c := b[i]
			if c == 34:
				i += 1
				return _T_STRING
			if c == 92:  # backslash
				if i + 1 >= n or b[i + 1] < 32:
					return _T_FAIL
				i += 2
				continue
			if c < 32 and c != 9 and c != 10 and c != 13:
				return _T_FAIL
			i += 1
		return _T_FAIL  # unterminated

	## -?digits(.digits)?(e[+-]?digits)? ; integers must fit in 64 bits.
	func _number() -> int:
		var neg := _eat(45)
		var start := i
		while i < n and b[i] >= 48 and b[i] <= 57:
			i += 1
		var digits := i - start
		if digits == 0 or digits > 308:
			return _T_FAIL
		var kind := _T_INT
		if i < n and b[i] == 46:  # .
			i += 1
			var frac := i
			while i < n and b[i] >= 48 and b[i] <= 57:
				i += 1
			if i == frac:
				return _T_FAIL
			kind = _T_FLOAT
		if i < n and (b[i] == 101 or b[i] == 69):  # e E
			i += 1
			if i < n and (b[i] == 43 or b[i] == 45):
				i += 1
			var exp_start := i
			while i < n and b[i] >= 48 and b[i] <= 57:
				i += 1
			# Godot writes d.ddde+XXX; anything that could overflow a double is refused (no strtod warnings)
			if i == exp_start or i - exp_start > 3 or digits > 1 or b.slice(exp_start, i).get_string_from_ascii().to_int() > 308:
				return _T_FAIL
			kind = _T_FLOAT
		if i < n and (_word_char(b[i]) or b[i] == 46):
			return _T_FAIL  # e.g. 0x10, 1.2.3, 5abc
		if kind == _T_INT:
			var text := b.slice(start, i).get_string_from_ascii().lstrip("0")
			var limit := "9223372036854775808" if neg else "9223372036854775807"
			if text.length() > limit.length() or (text.length() == limit.length() and text > limit):
				return _T_FAIL  # (Godot would log "cannot represent" and clamp)
		return kind

	## [v, v, ...]; `want` >= 0 requires every element to be that kind (typed arrays).
	func _array(depth: int, want: int) -> int:
		if depth > MAX_DEPTH or not _eat(91):
			return _T_FAIL
		_ws()
		if _eat(93):
			return _T_OTHER
		while true:
			var kind := _value(depth, true)
			if kind == _T_FAIL or (want >= 0 and kind != want):
				return _T_FAIL
			_ws()
			if _eat(93):
				return _T_OTHER
			if not _eat(44):  # ,
				return _T_FAIL
		return _T_FAIL

	## {key: value, ...} with string or int keys.
	func _dict(depth: int) -> int:
		if depth > MAX_DEPTH or not _eat(123):
			return _T_FAIL
		_ws()
		if _eat(125):
			return _T_OTHER
		while true:
			var key := _value(depth, true)
			if key != _T_STRING and key != _T_INT:
				return _T_FAIL
			_ws()
			if not _eat(58):  # :
				return _T_FAIL
			if _value(depth, true) == _T_FAIL:
				return _T_FAIL
			_ws()
			if _eat(125):
				return _T_OTHER
			if not _eat(44):
				return _T_FAIL
		return _T_FAIL

	## Color(r, g, b, a): four numbers (what Godot writes; its parser wants exactly four).
	func _color(depth: int) -> int:
		if depth > MAX_DEPTH:
			return _T_FAIL
		_spaces()
		if not _eat(40):  # (
			return _T_FAIL
		var count := 0
		while true:
			var kind := _value(depth, true)
			if kind != _T_INT and kind != _T_FLOAT:
				return _T_FAIL
			count += 1
			_ws()
			if _eat(41):  # )
				return _T_OTHER if count == 4 else _T_FAIL
			if not _eat(44) or count >= 4:
				return _T_FAIL
		return _T_FAIL

	## Array[int]([ints]) or Array[String](["strings"]) - the only typed arrays a save has.
	func _typed_array(depth: int) -> int:
		if depth > MAX_DEPTH:
			return _T_FAIL
		_spaces()
		if not _eat(91):
			return _T_FAIL
		_spaces()
		var type := _name()
		_spaces()
		if not _eat(93):
			return _T_FAIL
		var want := _T_INT if type == "int" else (_T_STRING if type == "String" else _T_FAIL)
		if want == _T_FAIL:
			return _T_FAIL
		_spaces()
		if not _eat(40):
			return _T_FAIL
		_ws()
		if _array(depth + 1, want) == _T_FAIL:
			return _T_FAIL
		_ws()
		return _T_OTHER if _eat(41) else _T_FAIL
