extends RefCounted

## Hard level 4's tables (Levels.get_config(level, true); field meanings at Levels' hard-mode section:
## seed, slime_mult = HARD_SLIME_MULT, allowance = HARD_ALLOWANCE, branching / run = HARD_BRANCHING /
## HARD_RUN, v4_steps / v4_target = HARD_V4_STEPS / HARD_V4_TARGETS). One file per hard level so a demo
## export can leave out the ones it doesn't have (docs/demo-plan.md). Loaded by path only, never preloaded.

const HARD := {seed = 54019, slime_mult = 1.4, allowance = 1.20, branching = 0.20, run = 0.45, v4_steps = 48, v4_target = 0.91}
