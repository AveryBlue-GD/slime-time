extends "res://tests/suite_base.gd"

## Coin.METAL (the map's coin colors) equals tools/make_coins.py COINS, and the map palette uses each
## level's metal on every paper with a readable rim.
## Run: ./tools/godot.sh --path . --headless --quit-after 60 -s res://tests/test_coin_metal.gd


func _initialize() -> void:
	var src := FileAccess.get_file_as_string("res://tools/make_coins.py")
	var block := src.split("COINS = {")[1].split("\n}")[0]
	var rx := RegEx.new()
	rx.compile("\"(\\w+)\": \\[(.*)\\]")
	var tuple := RegEx.new()
	tuple.compile("\\((\\d+), (\\d+), (\\d+)\\)")
	var n := 0
	for m in rx.search_all(block):
		var theme := m.get_string(1)
		var cols := tuple.search_all(m.get_string(2))
		var ok: bool = Coin.METAL.has(theme) and cols.size() == 5 and Coin.METAL[theme].size() == 5
		for i in cols.size():
			if ok:
				var c := Color8(cols[i].get_string(1).to_int(), cols[i].get_string(2).to_int(), cols[i].get_string(3).to_int())
				ok = ok and Coin.METAL[theme][i] == c
		_check(ok, "METAL %s matches make_coins.py" % theme)
		n += 1
	_check(n == 10 and Coin.METAL.size() == 10, "all 10 themes")
	for theme: String in Themes.BY_LEVEL:
		for paper in ["", "blueprint", "night", "goldleaf"]:
			var pal := MapView.palette(theme, paper, Color(0.4, 0.8, 0.4))
			_check(pal.coin in [Coin.METAL[theme][1], Coin.METAL[theme][2], Coin.METAL[theme][3]], "%s/%s coin fill is the metal's face/light/shine" % [theme, paper])
			var fd := absf(MapView._luma(pal.coin) - MapView._luma(pal.floor))
			var ed := absf(MapView._luma(pal.coin_edge) - MapView._luma(pal.floor))
			_check(maxf(fd, ed) >= 0.25, "%s/%s coin fill reads on the paper" % [theme, paper])
			_check(absf(MapView._luma(pal.coin) - MapView._luma(pal.coin_edge)) >= 0.08, "%s/%s coin rim differs from its face" % [theme, paper])
	_result()
	quit(1 if failures else 0)
