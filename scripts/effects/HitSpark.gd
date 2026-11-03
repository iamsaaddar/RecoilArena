extends Node2D
class_name HitSpark
## Chunky radial hit burst inspired by the sample HTML's 40-particle explosion.

@export var effect_color := Color("60a5fa")
@export var is_elimination := false

const PARTICLE_COUNT := 40
const LIFETIME_MIN := 0.3
const LIFETIME_MAX := 0.8
const SPEED_MIN := 80.0
const SPEED_MAX := 500.0
const ELIMINATION_LIFETIME := 1.15

var _particles: Array[Dictionary] = []
var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()
var _shards: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
	var count := 64 if is_elimination else PARTICLE_COUNT
	for index in range(count):
		var angle := _rng.randf_range(0.0, TAU)
		var direction := Vector2.RIGHT.rotated(angle)
		var speed := _rng.randf_range(130.0, 680.0) if is_elimination else _rng.randf_range(SPEED_MIN, SPEED_MAX)
		var particle_color := effect_color if _rng.randf() > 0.3 else Color("fde047")
		var lifetime := _rng.randf_range(0.65, ELIMINATION_LIFETIME) if is_elimination else _rng.randf_range(LIFETIME_MIN, LIFETIME_MAX)
		_particles.append({
			"position": Vector2.ZERO,
			"velocity": direction * speed,
			"size": _rng.randf_range(4.0, 10.0),
			"lifetime": lifetime,
			"age": 0.0,
			"color": particle_color,
		})
	if is_elimination:
		for index in range(14):
			var angle := _rng.randf_range(0.0, TAU)
			_shards.append({
				"position": Vector2.ZERO,
				"velocity": Vector2.RIGHT.rotated(angle) * _rng.randf_range(180.0, 560.0),
				"rotation": _rng.randf_range(0.0, TAU),
				"spin": _rng.randf_range(-12.0, 12.0),
				"size": _rng.randf_range(5.0, 13.0),
			})


func _process(delta: float) -> void:
	_elapsed += delta
	var has_live_particles := false
	for particle in _particles:
		if particle["age"] >= particle["lifetime"]:
			continue
		has_live_particles = true
		particle["age"] += delta
		particle["position"] += particle["velocity"] * delta
		particle["velocity"] *= pow(0.92, delta * 60.0)
	for shard in _shards:
		shard["position"] += shard["velocity"] * delta
		shard["velocity"] *= pow(0.90, delta * 60.0)
		shard["rotation"] += shard["spin"] * delta
	if not has_live_particles and (not is_elimination or _elapsed >= ELIMINATION_LIFETIME):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var ring_duration := 0.62 if is_elimination else 0.24
	var ring_progress := clampf(_elapsed / ring_duration, 0.0, 1.0)
	var ring_alpha := 1.0 - ring_progress
	var ring_radius := lerpf(8.0, 150.0 if is_elimination else 48.0, ring_progress)
	draw_circle(Vector2.ZERO, lerpf(25.0 if is_elimination else 12.0, 2.0, ring_progress), Color(1.0, 1.0, 1.0, ring_alpha * (0.9 if is_elimination else 0.65)))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color(effect_color, ring_alpha * 0.95), lerpf(11.0 if is_elimination else 5.0, 1.0, ring_progress), true)
	draw_arc(Vector2.ZERO, ring_radius * 0.72, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, ring_alpha * 0.65), 2.5 if is_elimination else 1.5, true)
	if is_elimination and _elapsed < 0.16:
		var flash := 1.0 - _elapsed / 0.16
		draw_circle(Vector2.ZERO, lerpf(12.0, 76.0, 1.0 - flash), Color(1.0, 1.0, 1.0, flash * 0.8))

	for particle in _particles:
		var age: float = particle["age"]
		var lifetime: float = particle["lifetime"]
		if age >= lifetime:
			continue
		var fade := 1.0 - age / lifetime
		var radius: float = particle["size"] * (0.5 + 0.5 * fade)
		var particle_position: Vector2 = particle["position"]
		var particle_color: Color = particle["color"]
		# Layered glow gives the burst the bright, explosive look of the HTML canvas.
		draw_circle(particle_position, radius * 2.2, Color(particle_color, fade * 0.12))
		draw_circle(particle_position, radius, Color(particle_color, fade))
		draw_circle(particle_position, radius * 0.42, Color(1.0, 1.0, 1.0, fade * 0.9))
	for shard in _shards:
		var shard_position: Vector2 = shard["position"]
		var shard_rotation: float = shard["rotation"]
		var size: float = shard["size"]
		var direction := Vector2.RIGHT.rotated(shard_rotation)
		draw_colored_polygon(PackedVector2Array([
			shard_position + direction * size,
			shard_position + direction.rotated(2.5) * size * 0.55,
			shard_position - direction * size * 0.7,
			shard_position + direction.rotated(-2.2) * size * 0.45,
		]), effect_color)
