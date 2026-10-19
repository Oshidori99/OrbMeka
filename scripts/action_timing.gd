extends RefCounted
# Timers are independent of OS input, so tests never capture the pointer.
const PLACE_INTERVAL := 0.3
const BREAK_INTERVAL := 0.3
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.12

var place_interval := PLACE_INTERVAL
var break_interval := BREAK_INTERVAL
var breaking := false
var break_remaining := 0.0
var placing := false
var place_remaining := 0.0
var coyote_remaining := 0.0
var jump_remaining := 0.0

func set_break_pressed(pressed: bool, active: bool) -> bool:
	if not pressed or not active:
		stop_breaking()
		return false
	if breaking:
		return false
	breaking = true
	break_remaining = break_interval
	return true

func tick_break(delta: float, active: bool, button_held: bool) -> bool:
	if not active or not button_held:
		stop_breaking()
		return false
	if not breaking:
		return false
	break_remaining -= delta
	if break_remaining > 0.000001:
		return false
	break_remaining = break_interval
	return true

func stop_breaking() -> void:
	breaking = false
	break_remaining = 0.0

func set_place_pressed(pressed: bool, active: bool) -> bool:
	if not pressed or not active:
		stop_placing()
		return false
	if placing:
		return false
	placing = true
	place_remaining = place_interval
	return true

func tick_place(delta: float, active: bool, button_held: bool) -> bool:
	if not active or not button_held:
		stop_placing()
		return false
	if not placing:
		return false
	place_remaining -= delta
	if place_remaining > 0.000001:
		return false
	# Discard overdue time: never catch up with a burst after a slow frame.
	place_remaining = place_interval
	return true

func stop_placing() -> void:
	placing = false
	place_remaining = 0.0

func tick_jump(delta: float, grounded: bool, just_pressed: bool) -> bool:
	coyote_remaining = COYOTE_TIME if grounded else maxf(0.0, coyote_remaining - delta)
	jump_remaining = JUMP_BUFFER_TIME if just_pressed else maxf(0.0, jump_remaining - delta)
	if jump_remaining > 0.0 and coyote_remaining > 0.0:
		jump_remaining = 0.0
		coyote_remaining = 0.0
		return true
	return false

func cancel() -> void:
	stop_breaking()
	stop_placing()
	coyote_remaining = 0.0
	jump_remaining = 0.0