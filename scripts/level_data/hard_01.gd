extends RefCounted

## Hard level 1's tables (Levels.get_config(level, true); field meanings at Levels' hard-mode section:
## seed, slime_mult = HARD_SLIME_MULT, allowance = HARD_ALLOWANCE, branching / run = HARD_BRANCHING /
## HARD_RUN, v4_steps / v4_target = HARD_V4_STEPS / HARD_V4_TARGETS). One file per hard level so a demo
## export can leave out the ones it doesn't have (docs/demo-plan.md). Loaded by path only, never preloaded.

const HARD := {seed = 51089, slime_mult = 1.1, allowance = 1.12, branching = 0.10, run = 0.30, v4_steps = 25, v4_target = 0.89}
