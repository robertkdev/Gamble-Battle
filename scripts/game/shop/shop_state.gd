extends RefCounted
class_name ShopState

# Immutable-ish snapshot of the current shop state.

var offers: Array[ShopOffer] = []
var locked: bool = false
var free_rerolls: int = 0

func _init(_offers: Array[ShopOffer] = [], _locked: bool = false, _free_rerolls: int = 0) -> void:
    offers = _offers.duplicate() if _offers != null else []
    locked = bool(_locked)
    free_rerolls = max(0, int(_free_rerolls))

