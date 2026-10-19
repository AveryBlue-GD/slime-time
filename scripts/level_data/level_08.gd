extends RefCounted

## Story level 8: its maze recipe (Levels.get_config; field meanings in scripts/levels.gd) and its banner
## line (Story.level_line). One file per level so a demo export can leave out the levels it doesn't
## have (Demo.full_only_paths, docs/demo-plan.md). Loaded by path only (Levels.level_data), never preloaded.

const NORMAL := {cells = Vector2i(22, 12), seed = 8131, branching = 0.12, run = 0.40, loops = 4, spawn = 1, target = 0.88}


static func line() -> String:
	# i18n: joke under the level name, one line, max 296px. Keep it funny, not literal.
	return Loc.t("story.level_8", "A CELL FOR THE FORGOTTEN. YOU ARE UNFORGETTABLE")
