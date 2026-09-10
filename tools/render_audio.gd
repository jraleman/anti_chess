extends SceneTree

## Reproducible, original ceramic/wood cues; render offline, never on an audio callback.

const RATE := 22050
const OUTPUT := "res://games/anti_chess/assets/audio/"


func _initialize() -> void:
	var error := DirAccess.make_dir_recursive_absolute(OUTPUT)
	if error != OK:
		printerr("Could not create the Anti-Chess sound directory: %s" % error_string(error))
		quit(1)
		return
	for cue in ["move", "capture", "promote", "finish"]:
		error = _render(cue)
		if error != OK:
			printerr("Could not render %s: %s" % [cue, error_string(error)])
			quit(1)
			return
	print("Rendered four original Anti-Chess cues.")
	quit(0)


func _render(cue: String) -> Error:
	var duration := 0.20 if cue == "move" else 0.36 if cue == "capture" else 0.75
	var samples := PackedByteArray()
	samples.resize(int(duration * RATE) * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7319
	for index in samples.size() / 2:
		var time := float(index) / RATE
		var value := _clack(time, rng.randf_range(-1.0, 1.0))
		if cue == "capture" and time > 0.085:
			value += _clack(time - 0.085, rng.randf_range(-1.0, 1.0)) * 0.65
		if cue == "promote" or cue == "finish":
			value *= 0.35
			for note in 3:
				var start := float(note) * 0.13
				if time < start:
					continue
				var pitch: float = [440.0, 550.0, 660.0][note]
				if cue == "finish":
					pitch = [660.0, 550.0, 440.0][note]
				var age := time - start
				value += sin(TAU * pitch * age) * exp(-age * 9.0) * 0.22
				value += sin(TAU * pitch * 2.01 * age) * exp(-age * 18.0) * 0.06
		value *= minf(time * 1500.0, 1.0) * minf((duration - time) * 80.0, 1.0)
		samples.encode_s16(index * 2, roundi(clampf(value, -1.0, 1.0) * 26000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = samples
	return stream.save_to_wav(OUTPUT + cue + ".wav")


func _clack(time: float, noise: float) -> float:
	return (
		sin(TAU * 1480.0 * time) * exp(-time * 55.0) * 0.35
		+ sin(TAU * 730.0 * time) * exp(-time * 42.0) * 0.25
		+ noise * exp(-time * 170.0) * 0.20
	)
