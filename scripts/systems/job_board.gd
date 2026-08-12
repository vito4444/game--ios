class_name JobBoard
extends RefCounted

## Shift work.
##
## A shift is a fixed number of interactions at the right prop in the right
## room. Turning up and doing all of them pays in full; doing half pays half,
## which is what makes slipping away mid-shift a real trade rather than a free
## action. Salvage from the work is the main way crafting material enters the
## game legitimately.

signal shift_started(job: Job)
signal unit_worked(job: Job, units_done: int, salvage: StringName)
signal shift_settled(job: Job, paid: int, units_done: int)

const DEFAULT_PATH := "res://data/jobs/jobs.json"

## Game minutes per unit of work.
const MINUTES_PER_UNIT := 25

const SHIFT_EVENT := &"shift_start"
const SHIFT_END_EVENT := &"lunch"


class Job:
	var id: StringName
	var name: String
	var zone: StringName
	var station: StringName
	var pay: int
	var units: int
	var stat: StringName
	var salvage: StringName
	var salvage_chance: float

	func _init(data: Dictionary) -> void:
		id = StringName(data.get("id", ""))
		name = data.get("name", "")
		zone = StringName(data.get("zone", ""))
		station = StringName(data.get("station", ""))
		pay = int(data.get("pay", 0))
		units = int(data.get("units", 1))
		stat = StringName(data.get("stat", ""))
		salvage = StringName(data.get("salvage", ""))
		salvage_chance = float(data.get("salvage_chance", 0.0))

	## Pay owed for a partly worked shift, rounded down.
	func pay_for(units_done: int) -> int:
		return pay * mini(units_done, units) / units


var jobs: Array[Job] = []
var errors: PackedStringArray = PackedStringArray()

var assigned: Job = null
var units_done: int = 0
var on_shift: bool = false

var _wallet: Wallet
var _inventory: Inventory
var _stats: Stats
var _rng: RandomNumberGenerator


static func load_from(
	path: String, wallet: Wallet, inventory: Inventory, stats: Stats, seed_value: int = 0
) -> JobBoard:
	var board := JobBoard.new()
	board._wallet = wallet
	board._inventory = inventory
	board._stats = stats
	board._rng = RandomNumberGenerator.new()
	board._rng.seed = seed_value

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		board.errors.append("cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return board

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		board.errors.append("%s is not a JSON object" % path)
		return board

	for entry in (parsed as Dictionary).get("jobs", []) as Array:
		board.jobs.append(Job.new(entry as Dictionary))
	board._validate()
	return board


func is_valid() -> bool:
	return errors.is_empty()


func by_id(id: StringName) -> Job:
	for job in jobs:
		if job.id == id:
			return job
	return null


func job_at(zone: StringName, station: StringName) -> Job:
	for job in jobs:
		if job.zone == zone and job.station == station:
			return job
	return null


func assign(id: StringName) -> bool:
	var job := by_id(id)
	if job == null:
		return false
	assigned = job
	units_done = 0
	return true


func begin_shift() -> void:
	if assigned == null or on_shift:
		return
	on_shift = true
	units_done = 0
	shift_started.emit(assigned)


## One interaction at the job's station. Returns false when this is not the
## player's job, the shift is over, or the day's work is already done.
func work(zone: StringName, station: StringName) -> bool:
	if assigned == null or not on_shift or units_done >= assigned.units:
		return false
	if assigned.zone != zone or assigned.station != station:
		return false

	units_done += 1
	var salvage := _roll_salvage()
	unit_worked.emit(assigned, units_done, salvage)
	return true


func is_shift_complete() -> bool:
	return assigned != null and units_done >= assigned.units


func remaining_units() -> int:
	return 0 if assigned == null else maxi(assigned.units - units_done, 0)


## Ends the shift and pays for what was actually done.
func settle() -> int:
	if assigned == null or not on_shift:
		return 0
	on_shift = false

	var job := assigned
	var owed := job.pay_for(units_done)
	if owed > 0:
		_wallet.credit(owed)
		# Doing the work is also how you get better at it.
		_stats.train(job.stat)
	shift_settled.emit(job, owed, units_done)
	units_done = 0
	return owed


func _roll_salvage() -> StringName:
	if assigned.salvage == &"" or _rng.randf() >= assigned.salvage_chance:
		return &""
	if not _inventory.add(assigned.salvage):
		return &""
	return assigned.salvage


func _validate() -> void:
	if jobs.is_empty():
		errors.append("no jobs defined")
	var seen := {}
	for job in jobs:
		if seen.has(job.id):
			errors.append("duplicate job id: %s" % job.id)
		seen[job.id] = true
		if job.units <= 0:
			errors.append("%s must have at least one unit of work" % job.id)
		if job.pay <= 0:
			errors.append("%s must pay something" % job.id)
		if job.pay % job.units != 0:
			errors.append(
				"%s pays %d over %d units, which does not divide evenly"
				% [job.id, job.pay, job.units]
			)
		if not Stats.ALL.has(job.stat):
			errors.append("%s trains '%s', which is not a stat" % [job.id, job.stat])
		if not TileCatalog.PROPS_ORDER.has(job.station):
			errors.append("%s is worked at '%s', which is not a prop" % [job.id, job.station])
