extends RefCounted

## Story level 9: its maze recipe (Levels.get_config; field meanings in scripts/levels.gd) and its banner
## line (Story.level_line). One file per level so a demo export can leave out the levels it doesn't
## have (Demo.full_only_paths, docs/demo-plan.md). Loaded by path only (Levels.level_script), never preloaded.

const NORMAL := {cells = Vector2i(24, 13), seed = 9283, branching = 0.14, run = 0.40, loops = 5, spawn = 2, target = 0.94}


static func line() -> String:
	# i18n: joke under the level name, one line, max 296px. Keep it funny, not literal.
	return Loc.t("story.level_9", "SO SHINY, DAYLIGHT MUST BE CLOSE")
