class_name Market
extends RefCounted

## The rig's unofficial trader, working out of a crate in the galley.
##
## He sells the things the company will not issue and buys anything that fits
## in a pocket. The spread is wide enough that grinding shifts is the sensible
## way to earn and selling salvage is a fallback, not a strategy.

signal bought(id: StringName, price: int)
signal sold(id: StringName, price: int)

## Buying costs more than the item is worth, selling returns less.
const BUY_MARKUP := 1.5
const SELL_RETURN := 0.5

## What he keeps in the crate. Everything else has to be found or made.
const STOCK: Array[StringName] = [
	&"torch_fuel",
	&"blank_docket",
	&"oxygen_bottle",
	&"keycard",
	&"scrap_metal",
	&"ration",
]

var _catalog: ItemCatalog
var _inventory: Inventory
var _wallet: Wallet


func _init(catalog: ItemCatalog, inventory: Inventory, wallet: Wallet) -> void:
	_catalog = catalog
	_inventory = inventory
	_wallet = wallet


func stock() -> Array[StringName]:
	return STOCK.duplicate()


func buy_price(id: StringName) -> int:
	var item := _catalog.get_item(id)
	return 0 if item == null else int(ceilf(item.value * BUY_MARKUP))


func sell_price(id: StringName) -> int:
	var item := _catalog.get_item(id)
	return 0 if item == null else int(floorf(item.value * SELL_RETURN))


func can_buy(id: StringName) -> bool:
	return (
		STOCK.has(id)
		and _wallet.can_afford(buy_price(id))
		and _inventory.can_add(id)
	)


func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	var price := buy_price(id)
	_wallet.debit(price)
	_inventory.add(id)
	bought.emit(id, price)
	return true


func can_sell(id: StringName) -> bool:
	return _inventory.has(id) and sell_price(id) > 0


func sell(id: StringName) -> bool:
	if not can_sell(id):
		return false
	var price := sell_price(id)
	_inventory.remove(id)
	_wallet.credit(price)
	sold.emit(id, price)
	return true
