extends "res://autoload/router.gd"

## Lightweight router stand-in for setup-flow routing assertions.

var goto_calls := 0
var last_destination := ""
var last_fade := true


func _ready() -> void:
	pass


func goto(path: String, fade := true) -> void:
	goto_calls += 1
	last_destination = path
	last_fade = fade
