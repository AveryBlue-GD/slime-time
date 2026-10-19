extends RefCounted

## Hard level 8's tables (Levels.get_config(level, true); field meanings at Levels' hard-mode section:
## seed, slime_mult = HARD_SLIME_MULT, allowance = HARD_ALLOWANCE, branching / run = HARD_BRANCHING /
## HARD_RUN, v4_steps / v4_target = HARD_V4_STEPS / HARD_V4_TARGETS). One file per hard level so a demo
## export can leave out the ones it doesn't have (docs/demo-plan.md). Loaded by path only, never preloaded.

const HARD := {seed = 58160, slime_mult = 1.8, allowance = 1.23, branching = 0.15, run = 0.45, v4_steps = 77, v4_target = 0.96}
