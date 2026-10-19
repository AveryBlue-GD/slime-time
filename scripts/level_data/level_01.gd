extends RefCounted

## Story level 1: its maze recipe (Levels.get_config; field meanings in scripts/levels.gd) and its banner
## line (Story.level_line). One file per level so a demo export can leave out the levels it doesn't
## have (Demo.full_only_paths, docs/demo-plan.md). Loaded by path only (Levels.level_data), never preloaded.

const NORMAL := {cells = Vector2i(10, 6), seed = 1118, branching = 0.05, run = 0.35, loops = 0, spawn = 0, target = 0.45}


static func line() -> String:
	# i18n: joke under the level name, one line, max 296px. Keep it funny, not literal.
	return Loc.t("story.level_1", "SPLAT. IT IS DAMP, UP IS THAT WAY")
