extends Object
class_name TraitMath

# Shared small math helpers for trait/ability interactions.

static func execution_threshold(stacks: int) -> float:
    # Base 12% + 2% per stack, capped at 40%.
    var base_t: float = 0.12
    var inc: float = 0.02 * float(max(0, stacks))
    return clamp(base_t + inc, 0.0, 0.40)

