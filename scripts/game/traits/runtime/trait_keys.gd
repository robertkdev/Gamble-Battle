extends Object
class_name TraitKeys

# Centralized keys for trait-related stacks and helpers.
# Keep names stable across handlers and abilities.

# Generic helper: canonical stack key for a trait id
static func stack_key(trait_id: String) -> String:
	return "trait.%s" % String(trait_id)

# Common stack keys (referenced by abilities/handlers)
const TITAN := "trait.Titan"
const AEGIS := "trait.Aegis"
const STRIKER := "trait.Striker"
const ARCANIST := "trait.Arcanist"
const EXECUTIONER := "trait.Executioner"
const KALEIDOSCOPE := "trait.Kaleidoscope"
const EXILE := "trait.Exile"
const FORTIFIED := "trait.Fortified"
const OVERLOAD := "trait.Overload" # not a stack by default; reserved
const SCHOLAR := "trait.Scholar"
const CHRONOMANCER := "trait.Chronomancer"

# Additional traits (for consistency if stacks needed later)
const SANGUINE := "trait.Sanguine"
const BLESSED := "trait.Blessed"
const BULWARK := "trait.Bulwark"
const VINDICATOR := "trait.Vindicator"
const MENTOR := "trait.Mentor"
const HARMONY := "trait.Harmony"
const LIAISON := "trait.Liaison"
const CARTEL := "trait.Cartel"
const MOGUL := "trait.Mogul"
const TRADER := "trait.Trader"
const CATALYST := "trait.Catalyst"
