"""Shared `--check` helper (M32 / CON-03 / CON-06): no outline colour may be darker than a max channel of 16.

    from art_checks import outline_problems
    bad = outline_problems({"theme k": (22, 20, 34), ...})   # -> list of messages, empty when fine
"""
MIN_OUTLINE_CHANNEL = 16


def outline_problems(outlines: dict) -> list[str]:
    return ["%s %s: max channel %d < %d (near-black outline)" % (name, tuple(c[:3]), max(c[:3]), MIN_OUTLINE_CHANNEL)
            for name, c in outlines.items() if max(c[:3]) < MIN_OUTLINE_CHANNEL]
