extends RefCounted

## Hard level 10's tables (Levels.get_config(level, true); field meanings at Levels' hard-mode section:
## seed, slime_mult = HARD_SLIME_MULT, allowance = HARD_ALLOWANCE, branching / run = HARD_BRANCHING /
## HARD_RUN, v4_steps / v4_target = HARD_V4_STEPS / HARD_V4_TARGETS). One file per hard level so a demo
## export can leave out the ones it doesn't have (docs/demo-plan.md). Loaded by path only, never preloaded.

const HARD := {seed = 60900, slime_mult = 2.0, allowance = 1.28, branching = 0.18, run = 0.40, v4_steps = 96, v4_target = 1.0}
