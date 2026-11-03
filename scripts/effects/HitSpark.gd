extends Node2D
class_name HitSpark
## Chunky radial hit burst inspired by the sample HTML's 40-particle explosion.

@export var effect_color := Color("60a5fa")

const PARTICLE_COUNT := 40
const LIFETIME_MIN := 0.3
const LIFETIME_MAX := 0.8
const SPEED_MIN := 80.0
const SPEED_MAX := 500.0

var _particles: Array[Dictionary] = []
var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for index in range(PARTICLE_COUNT):
		var angle := _rng.randf_range(0.0, TAU)
		var direction := Vector2.RIGHT.rotated(angle)
		var speed := _rng.randf_range(SPEED_MIN, SPEED_MAX)
		var particle_color := effect_color if _rng.randf() > 0.3 else Color("fde047")
		var lifetime := _rng.randf_range(LIFETIME_MIN, LIFETIME_MAX)
		_particles.append({
			"position": Vector2.ZERO,
			"velocity": direction * speed,
			"size": _rng.randf_range(4.0, 10.0),
			"lifetime": lifetime,
			"age": 0.0,
			"color": particle_color,
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
	if not has_live_particles:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var ring_progress := clampf(_elapsed / 0.24, 0.0, 1.0)
	var ring_alpha := 1.0 - ring_progress
	var ring_radius := lerpf(5.0, 48.0, ring_progress)
	draw_circle(Vector2.ZERO, lerpf(12.0, 2.0, ring_progress), Color(1.0, 1.0, 1.0, ring_alpha * 0.65))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(effect_color, ring_alpha * 0.9), lerpf(5.0, 1.0, ring_progress), true)
	draw_arc(Vector2.ZERO, ring_radius * 0.72, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, ring_alpha * 0.55), 1.5, true)

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
