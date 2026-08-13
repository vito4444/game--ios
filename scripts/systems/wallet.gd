class_name Wallet
extends RefCounted

## Rig credits.
##
## The only legitimate income is a completed shift, and the only thing worth
## buying is contraband, so the balance doubles as a measure of how long the
## player has been playing along.

signal changed(balance: int)

var balance: int = 0


func credit(amount: int) -> void:
	if amount <= 0:
		return
	balance += amount
	changed.emit(balance)


func can_afford(amount: int) -> bool:
	return amount <= balance


func debit(amount: int) -> bool:
	if amount <= 0 or not can_afford(amount):
		return false
	balance -= amount
	changed.emit(balance)
	return true
