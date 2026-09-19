extends Camera3D

## User-controlled framing stays independent of the chess position and window size.

signal view_changed

const HOME_ELEVATION := PI * 0.32
const MIN_ELEVATION := PI * 0.25
const MAX_ELEVATION := PI * 0.45
const MIN_ZOOM := 0.7
const MAX_ZOOM := 2.0
const MAX_PAN := 4.0
const DISTANCE := 24.0
const TARGET_HEIGHT := 0.15
const FRAMING_BOUNDS: Array[AABB] = [
	AABB(Vector3(-4.95, -0.7, -6.0), Vector3(9.9, 0.85, 12.0)),
	AABB(Vector3(-4.0, 0.205, -4.0), Vector3(8.0, 1.8, 8.0)),
	AABB(Vector3(-4.25, 0.13, -5.7), Vector3(8.5, 0.65, 11.4)),
]

var top_down := false
var azimuth := 0.0
var elevation := HOME_ELEVATION
var zoom_factor := 1.0
var pan_offset := Vector2.ZERO
var _home_side := 0
var _viewport_size := Vector2(1280, 720)
var _flip_tween: Tween
var _flip_target := 0.0


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	near = 0.1
	far = 80.0
	_update_view()


## Local opponents share an overhead view; a solo player faces their own pieces.
func configure(overhead: bool, home_side: int) -> void:
	top_down = overhead
	_home_side = home_side
	reset_view()


## Returning home also recovers the whole board after a close zoom or a long pan.
func reset_view() -> void:
	_cancel_flip()
	azimuth = PI if _home_side == 1 else 0.0
	elevation = PI * 0.5 if top_down else HOME_ELEVATION
	zoom_factor = 1.0
	pan_offset = Vector2.ZERO
	_update_view()


## Resizing refits the table without throwing away the user's camera adjustments.
func resize_view(viewport_size: Vector2) -> void:
	_viewport_size = viewport_size.max(Vector2.ONE)
	_update_view()


## Direction is screen-relative: right is positive X and down is positive Y.
func move_camera(direction: Vector2, delta: float) -> void:
	if direction.is_zero_approx():
		return
	_cancel_flip()
	var step := direction.limit_length() * clampf(delta, 0.0, 0.1)
	if top_down:
		_pan((basis.x * step.x - basis.y * step.y) * 5.0 / zoom_factor)
	else:
		azimuth = wrapf(azimuth + step.x * 1.5, 0.0, TAU)
		elevation = clampf(elevation - step.y, MIN_ELEVATION, MAX_ELEVATION)
	_update_view()


## Dragging grabs the view, with sensitivity independent of virtual UI resolution.
func drag_camera(relative: Vector2) -> void:
	_cancel_flip()
	if top_down:
		_pan((-basis.x * relative.x + basis.y * relative.y) * size / _viewport_size.y)
	else:
		azimuth = wrapf(azimuth - relative.x / _viewport_size.x * TAU, 0.0, TAU)
		elevation = clampf(elevation + relative.y / _viewport_size.y * PI * 0.7,
			MIN_ELEVATION, MAX_ELEVATION)
	_update_view()


## Wheel steps are multiplicative so zoom remains useful at both ends of its range.
func zoom_camera(steps: float) -> void:
	zoom_factor = clampf(
		zoom_factor * pow(1.13, clampf(steps, -8.0, 8.0)), MIN_ZOOM, MAX_ZOOM
	)
	_update_view()


## Flipping preserves zoom, pan and elevation, including the local overhead lock.
func flip_view(immediate: bool) -> void:
	_cancel_flip()
	_flip_target = azimuth + PI
	if immediate:
		_set_azimuth(_flip_target)
	else:
		_flip_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_flip_tween.tween_method(_set_azimuth, azimuth, _flip_target, 0.4)


## Accessibility changes finish only an active flip, never reset a freely moved view.
func finish_transition() -> void:
	if is_transitioning():
		_cancel_flip()
		_set_azimuth(_flip_target)


## Piece selection waits for a flip, not for normal user-controlled camera movement.
func is_transitioning() -> bool:
	return _flip_tween != null and _flip_tween.is_running()


## Square navigation follows the nearest board axis, even at a quarter-turn orbit.
func square_direction(direction: Vector2i) -> Vector2i:
	var quarter := roundi(azimuth / (PI * 0.5))
	var angle := quarter * PI * 0.5
	return Vector2i(
		roundi(cos(angle) * direction.x - sin(angle) * direction.y),
		roundi(sin(angle) * direction.x + cos(angle) * direction.y)
	)


## Letter badges sit on the camera-facing edge of each base, not a fixed board edge.
func badge_offset() -> Vector3:
	return Vector3(sin(azimuth) * 0.26, 0.12, cos(azimuth) * 0.26)


func _cancel_flip() -> void:
	if _flip_tween != null:
		_flip_tween.kill()
		_flip_tween = null


func _set_azimuth(value: float) -> void:
	azimuth = wrapf(value, 0.0, TAU)
	_update_view()


func _pan(offset: Vector3) -> void:
	pan_offset = (pan_offset + Vector2(offset.x, offset.z)).clamp(
		Vector2.ONE * -MAX_PAN, Vector2.ONE * MAX_PAN
	)


func _update_view() -> void:
	var target := Vector3(pan_offset.x, TARGET_HEIGHT, pan_offset.y)
	var offset := Vector3.UP * DISTANCE if top_down else Vector3(
		sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)
	) * DISTANCE
	position = target + offset
	# Looking straight down needs a board-plane up vector, not collinear world UP.
	var up := Vector3.FORWARD.rotated(Vector3.UP, azimuth) if top_down else Vector3.UP
	basis = Basis.looking_at(-offset, up)
	var inverse := basis.inverse()
	var half_width := 0.0
	var half_height := 0.0
	for bounds in FRAMING_BOUNDS:
		for x in [bounds.position.x, bounds.end.x]:
			for z in [bounds.position.z, bounds.end.z]:
				for y in [bounds.position.y, bounds.end.y]:
					var point := inverse * Vector3(x, y - TARGET_HEIGHT, z)
					half_width = maxf(half_width, absf(point.x))
					half_height = maxf(half_height, absf(point.y))
	var aspect := _viewport_size.x / _viewport_size.y
	size = (maxf(half_height * 2.0, half_width * 2.0 / aspect) + 0.5) / zoom_factor
	view_changed.emit()
