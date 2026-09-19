extends "res://games/anti_chess/gameplay.gd"

## Exercise the shipped match without writing achievements, progression or store coins.

var observed_achievements := PackedStringArray()
var observed_coins := 0
var bank_store_rewards := false


func _reset_round_state() -> void:
	super()
	observed_achievements.clear()
	observed_coins = 0


func _unlock_round_achievement(id: String) -> void:
	observed_achievements.append(id)


func _record_round(_one: int, _two: int) -> String:
	return ""


func _bank_store_points(one: int, two: int) -> void:
	observed_coins += _round_points_earned(one, two)
	if bank_store_rewards:
		super(one, two)
