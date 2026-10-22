extends RefCounted

## Story level 5: its maze recipe (Levels.get_config; field meanings in scripts/levels.gd) and its banner
## line (Story.level_line). One file per level so a demo export can leave out the levels it doesn't
## have (Demo.full_only_paths, docs/demo-plan.md). Loaded by path only (Levels.level_script), never preloaded.

const NORMAL := {cells = Vector2i(16, 9), seed = 5053, branching = 0.25, run = 0.45, loops = 0, spawn = 1, target = 0.70}


static func line() -> String:
	# i18n: joke under the level name, one line, max 296px. Keep it funny, not literal.
	return Loc.t("story.level_5", "A SLIME IN SLIME, NOBODY WILL NOTICE")
