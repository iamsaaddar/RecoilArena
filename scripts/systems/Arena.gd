extends Node2D
## Arena backdrop, player spawns, and projectile ownership.

const BACKGROUND_COLOR := Color("1e2029")
const ARENA_COLOR := Color("191b23")
const GRID_COLOR := Color("262936")
const WALL_COLOR := Color("111a27")
const NEON_COLOR := Color("38d9ff")
const NEON_HIGHLIGHT := Color("a5f2ff")

const ARENA_RECT := Rect2(120.0, 70.0, 1040.0, 580.0)
const OUTER_WALL_RECT := Rect2(108.0, 58.0, 1064.0, 604.0)
const INNER_WALL_RECT := Rect2(132.0, 82.0, 1016.0, 556.0)
const GRID_SPACING := 40

const GUN_SCENE := preload("res://scenes/player/Gun.tscn")
const BULLET_SCENE := preload("res://scenes/projectiles/Bullet.tscn")
const HIT_SPARK_SCENE := preload("res://scenes/effects/HitSpark.tscn")
const HEALTH_HUD_SCRIPT := preload("res://scripts/systems/HealthHUD.gd")
const GUN_FIRE_SOUND := preload("res://assets/audio/gun_fire.wav")
const WALL_BOUNCE_SOUND := preload("res://assets/audio/wall_bounce.wav")
const HIT_IMPACT_SOUND := preload("res://assets/audio/hit_impact.wav")
const ELIMINATION_SOUND := preload("res://assets/audio/elimination.wav")
const EXPLOSION_SOUND := preload("res://assets/audio/explosion.wav")

var _projectiles: Node2D
var _health_hud: HealthHUD
var _camera: Camera2D
var _guns: Array[ArenaGun] = []
var _round_over := false
var _round_transitioning := false
var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_intensity := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_camera = Camera2D.new()
	_camera.name = "ArenaCamera"
	_camera.position = Vector2(640.0, 360.0)
	_camera.enabled = true
	add_child(_camera)
	_camera.make_current()
	get_viewport().size_changed.connect(_update_camera_zoom)
	_update_camera_zoom()
	_projectiles = Node2D.new()
	_projectiles.name = "Projectiles"
	add_child(_projectiles)
	_health_hud = HEALTH_HUD_SCRIPT.new() as HealthHUD
	add_child(_health_hud)
	_health_hud.play_again_requested.connect(_on_play_again_requested)
	_spawn_player(1, Vector2(360.0, 360.0), 0.0, Color("3b82f6"), &"player_1_shoot")
	_spawn_player(2, Vector2(920.0, 360.0), 180.0, Color("ef4444"), &"player_2_shoot")


func _unhandled_input(event: InputEvent) -> void:
	if _round_over or _round_transitioning:
		return
	if event is InputEventScreenTouch and event.pressed:
		var viewport_width := get_viewport_rect().size.x
		var player_id := 1 if event.position.x < viewport_width * 0.5 else 2
		for gun in _guns:
			if is_instance_valid(gun) and gun.player_id == player_id:
				gun.request_touch_fire()
				break
		get_viewport().set_input_as_handled()


func _update_camera_zoom() -> void:
	if not is_instance_valid(_camera):
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var fit_scale := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	_camera.zoom = Vector2.ONE / fit_scale
	queue_redraw()


func _process(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time = maxf(0.0, _shake_time - delta)
	var fade := _shake_time / maxf(_shake_duration, 0.001)
	_camera.offset = Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	) * _shake_intensity * fade
	if _shake_time <= 0.0:
		_camera.offset = Vector2.ZERO
		_shake_intensity = 0.0
		_shake_duration = 0.0


func _trigger_screen_shake(intensity: float, duration: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_time = maxf(_shake_time, duration)


func _play_sound(stream: AudioStream, world_position: Vector2, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = world_position
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.max_distance = 1800.0
	player.attenuation = 0.8
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _on_gun_collision(impact_strength: float, impact_position: Vector2) -> void:
	var intensity := clampf(impact_strength / 360.0, 0.0, 1.0)
	# Layer a weighty impact thump with the existing ricochet's short metallic tail.
	# These are real project samples, not the artificial oscillator used previously.
	var pitch_variation := _rng.randf_range(0.96, 1.04)
	_play_sound(HIT_IMPACT_SOUND, impact_position, lerpf(-10.0, -3.5, intensity), 0.82 * pitch_variation)
	_play_sound(WALL_BOUNCE_SOUND, impact_position, lerpf(-13.0, -7.0, intensity), 0.74 * pitch_variation)


func _spawn_player(
	player_id: int,
	spawn_position: Vector2,
	start_angle: float,
	player_color: Color,
	action: StringName
) -> void:
	var gun := GUN_SCENE.instantiate() as ArenaGun
	gun.name = "Player%dGun" % player_id
	gun.player_id = player_id
	gun.fire_action = action
	gun.gun_color = player_color
	gun.starting_rotation_degrees = start_angle
	gun.position = spawn_position
	gun.shot_requested.connect(_on_shot_requested)
	gun.eliminated.connect(_on_player_eliminated)
	gun.gun_collision.connect(_on_gun_collision)
	add_child(gun)
	_guns.append(gun)


func _on_shot_requested(gun: ArenaGun, muzzle_position: Vector2, shot_direction: Vector2) -> void:
	_play_sound(GUN_FIRE_SOUND, muzzle_position, -2.0)
	var bullet := BULLET_SCENE.instantiate() as ArenaBullet
	bullet.bullet_color = gun.gun_color
	bullet.target_hit.connect(_on_bullet_hit)
	bullet.wall_bounced.connect(_on_bullet_wall_bounced)
	_projectiles.add_child(bullet)
	bullet.setup(gun, muzzle_position, shot_direction)


func _on_bullet_wall_bounced(bullet_position: Vector2) -> void:
	_play_sound(WALL_BOUNCE_SOUND, bullet_position, 4.0)


func _on_bullet_hit(
	target: ArenaGun,
	shooter: ArenaGun,
	impact_direction: Vector2,
	_impact_position: Vector2
) -> void:
	if _round_over or not is_instance_valid(target) or not is_instance_valid(shooter):
		return
	target.receive_hit(impact_direction)
	_health_hud.update_health(target.player_id, target.hit_count, target.gun_color)
	_play_sound(HIT_IMPACT_SOUND, _impact_position, -1.5, _rng.randf_range(0.92, 1.08))
	_trigger_screen_shake(5.5, 0.18)
	var spark := HIT_SPARK_SCENE.instantiate() as HitSpark
	spark.effect_color = target.gun_color
	# The reference prototype bursts particles from the gun's center, not the bullet tip.
	spark.global_position = target.global_position
	add_child(spark)
	print("Player %d hit by Player %d (%d/%d)" % [
		target.player_id,
		shooter.player_id,
		target.hit_count,
		ArenaGun.HITS_TO_ELIMINATE
	])


func _on_player_eliminated(gun: ArenaGun) -> void:
	if _round_over:
		return
	var burst := HIT_SPARK_SCENE.instantiate() as HitSpark
	burst.effect_color = gun.gun_color
	burst.is_elimination = true
	burst.global_position = gun.global_position
	add_child(burst)
	_play_sound(ELIMINATION_SOUND, gun.global_position, -1.0, _rng.randf_range(0.96, 1.04))
	_play_sound(EXPLOSION_SOUND, gun.global_position, -5.0, _rng.randf_range(0.94, 1.06))
	_trigger_screen_shake(14.0, 0.42)
	gun.visible = false
	gun.collision_layer = 0
	gun.collision_mask = 0
	var winner_id := 2 if gun.player_id == 1 else 1
	_end_round(winner_id)


func _end_round(winner_id: int) -> void:
	if _round_over:
		return
	_round_over = true
	for gun in _guns:
		if is_instance_valid(gun):
			gun.set_round_locked(true)
	for projectile in _projectiles.get_children():
		if projectile is ArenaBullet:
			projectile.cancel()
	_health_hud.announce_winner(winner_id)
	print("ROUND OVER: Player %d wins" % winner_id)


func _on_play_again_requested() -> void:
	if _round_over and not _round_transitioning:
		_start_next_round()


func _start_next_round() -> void:
	_round_transitioning = true
	for count in [3, 2, 1]:
		_health_hud.show_countdown(str(count))
		await get_tree().create_timer(0.8).timeout
	_health_hud.show_countdown("GO!")
	await get_tree().create_timer(0.35).timeout

	for projectile in _projectiles.get_children():
		if projectile is ArenaBullet:
			projectile.cancel()
	for gun in _guns:
		if not is_instance_valid(gun):
			continue
		if gun.player_id == 1:
			gun.reset_for_round(Vector2(360.0, 360.0), 0.0)
		else:
			gun.reset_for_round(Vector2(920.0, 360.0), 180.0)
	_health_hud.reset_health()
	_round_over = false
	_round_transitioning = false
	_health_hud.hide_round_overlay()
	print("ROUND START")


func _draw() -> void:
	# Extend the backdrop into any extra space created by aspect-ratio fitting.
	var visible_size := get_viewport_rect().size * _camera.zoom
	var visible_rect := Rect2(Vector2(640.0, 360.0) - visible_size * 0.5, visible_size)
	draw_rect(visible_rect, BACKGROUND_COLOR)
	# Base 16:9 arena backdrop.
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), BACKGROUND_COLOR)
	# Soft cyan glow around the full 24 px wall frame.
	draw_rect(OUTER_WALL_RECT.grow(7.0), Color(0.10, 0.78, 1.0, 0.07), false, 18.0)
	draw_rect(OUTER_WALL_RECT.grow(3.0), Color(0.10, 0.78, 1.0, 0.12), false, 12.0)
	draw_rect(OUTER_WALL_RECT, Color(0.10, 0.78, 1.0, 0.22), false, 6.0)
	# Solid wall frame and dark arena floor.
	draw_rect(OUTER_WALL_RECT, WALL_COLOR)
	draw_rect(INNER_WALL_RECT, ARENA_COLOR)
	draw_rect(OUTER_WALL_RECT, NEON_COLOR, false, 2.0)
	draw_rect(INNER_WALL_RECT, Color(NEON_COLOR, 0.8), false, 2.0)
	draw_rect(OUTER_WALL_RECT.grow(-3.0), Color(NEON_HIGHLIGHT, 0.42), false, 1.0)
	for x in range(int(ARENA_RECT.position.x) + GRID_SPACING, int(ARENA_RECT.end.x), GRID_SPACING):
		draw_line(Vector2(x, ARENA_RECT.position.y), Vector2(x, ARENA_RECT.end.y), GRID_COLOR, 1.0)
	for y in range(int(ARENA_RECT.position.y) + GRID_SPACING, int(ARENA_RECT.end.y), GRID_SPACING):
		draw_line(Vector2(ARENA_RECT.position.x, y), Vector2(ARENA_RECT.end.x, y), GRID_COLOR, 1.0)
