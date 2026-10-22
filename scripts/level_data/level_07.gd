extends RefCounted

## Story level 7: its maze recipe (Levels.get_config; field meanings in scripts/levels.gd) and its banner
## line (Story.level_line). One file per level so a demo export can leave out the levels it doesn't
## have (Demo.full_only_paths, docs/demo-plan.md). Loaded by path only (Levels.level_script), never preloaded.

const NORMAL := {cells = Vector2i(20, 11), seed = 7132, branching = 0.21, run = 0.45, loops = 3, spawn = 0, target = 0.82}


static func line() -> String:
	# i18n: joke under the level name, one line, max 296px. Keep it funny, not literal.
	return Loc.t("story.level_7", "COLDER NOW. SLIME DOES NOT SHIVER, IT JIGGLES")
