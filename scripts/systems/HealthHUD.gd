extends CanvasLayer
class_name HealthHUD
## Compact three-segment health display with a short hit-loss animation.

signal play_again_requested
signal return_to_menu_requested

const SEGMENT_COUNT := 3
const HEART_SIZE := Vector2(30.0, 27.0)
const HEART_GAP := 12.0
const ANIMATION_DURATION := 0.32

var _health := {1: 0, 2: 0}
var _colors := {1: Color("3b82f6"), 2: Color("ef4444")}
var _animations := {1: -1.0, 2: -1.0}
var _draw_layer: Control
var _round_overlay: Control
var _winner_label: Label
var _play_again_button: Button
var _return_to_menu_button: Button


func _ready() -> void:
	_draw_layer = Control.new()
	_draw_layer.name = "HealthDisplay"
	_draw_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.draw.connect(_draw_health)
	add_child(_draw_layer)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_create_round_overlay()


func update_health(player_id: int, hit_count: int, player_color: Color) -> void:
	if not _health.has(player_id):
		return
	var previous_hits: int = _health[player_id]
	_health[player_id] = clampi(hit_count, 0, SEGMENT_COUNT)
	_colors[player_id] = player_color
	if hit_count > previous_hits:
		_animations[player_id] = 0.0
	_draw_layer.queue_redraw()


func announce_winner(player_id: int) -> void:
	_winner_label.text = "PLAYER %d WINS" % player_id
	_winner_label.show()
	_play_again_button.text = "PLAY AGAIN"
	_play_again_button.disabled = false
	_play_again_button.show()
	_return_to_menu_button.show()
	_round_overlay.show()
	_draw_layer.queue_redraw()


func show_countdown(value: String) -> void:
	_winner_label.text = value
	_winner_label.show()
	_play_again_button.hide()
	_return_to_menu_button.hide()
	_round_overlay.show()


func reset_health() -> void:
	_health[1] = 0
	_health[2] = 0
	_animations[1] = -1.0
	_animations[2] = -1.0
	_draw_layer.queue_redraw()


func hide_round_overlay() -> void:
	_round_overlay.hide()


func _create_round_overlay() -> void:
	_round_overlay = Control.new()
	_round_overlay.name = "RoundOverlay"
	_round_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_round_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_round_overlay.hide()
	add_child(_round_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.045, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_round_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "ResultPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250.0
	panel.offset_top = -115.0
	panel.offset_right = 250.0
	panel.offset_bottom = 115.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("101b2a")
	panel_style.border_color = Color("38d9ff", 0.8)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", panel_style)
	_round_overlay.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	_winner_label = Label.new()
	_winner_label.name = "WinnerLabel"
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_winner_label.add_theme_font_size_override("font_size", 34)
	_winner_label.add_theme_color_override("font_color", Color("f8fafc"))
	content.add_child(_winner_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	_play_again_button = Button.new()
	_play_again_button.name = "PlayAgainButton"
	_play_again_button.text = "PLAY AGAIN"
	_play_again_button.custom_minimum_size = Vector2(150.0, 44.0)
	_style_result_button(_play_again_button)
	_play_again_button.pressed.connect(_on_play_again_pressed)
	actions.add_child(_play_again_button)
	_return_to_menu_button = Button.new()
	_return_to_menu_button.name = "ReturnToMenuButton"
	_return_to_menu_button.text = "MAIN MENU"
	_return_to_menu_button.custom_minimum_size = Vector2(150.0, 44.0)
	_style_result_button(_return_to_menu_button)
	_return_to_menu_button.pressed.connect(func() -> void: return_to_menu_requested.emit())
	actions.add_child(_return_to_menu_button)


func _style_result_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("17384d")
	normal.border_color = Color("38d9ff", 0.65)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("20536d")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color("f1f5f9"))

func _on_play_again_pressed() -> void:
	_play_again_button.disabled = true
	play_again_requested.emit()


func _process(delta: float) -> void:
	var needs_redraw := false
	for player_id in range(1, 3):
		if _animations[player_id] >= 0.0:
			_animations[player_id] += delta
			needs_redraw = true
			if _animations[player_id] >= ANIMATION_DURATION:
				_animations[player_id] = -1.0
	if needs_redraw:
		_draw_layer.queue_redraw()


func _draw_health() -> void:
	var viewport_size := _draw_layer.size
	var stack_height := SEGMENT_COUNT * HEART_SIZE.y + (SEGMENT_COUNT - 1) * HEART_GAP
	var top := (viewport_size.y - stack_height) * 0.5
	var side_margin := clampf(viewport_size.x * 0.022, 14.0, 28.0)
	_draw_player(1, Vector2(side_margin, top))
	_draw_player(2, Vector2(viewport_size.x - HEART_SIZE.x - side_margin, top))


func _on_viewport_size_changed() -> void:
	if is_instance_valid(_draw_layer):
		_draw_layer.queue_redraw()

func _draw_player(player_id: int, origin: Vector2) -> void:
	var color: Color = _colors[player_id]
	for index in range(SEGMENT_COUNT):
		var heart_origin := origin + Vector2(0.0, index * (HEART_SIZE.y + HEART_GAP))
		var lost: bool = index < int(_health[player_id])
		var heart_color := Color("273343", 0.92) if lost else color
		if lost:
			var is_new_loss: bool = index == int(_health[player_id]) - 1 and float(_animations[player_id]) >= 0.0
			if is_new_loss:
				var progress: float = clampf(_animations[player_id] / ANIMATION_DURATION, 0.0, 1.0)
				heart_color = Color(color, 1.0 - progress)
				_draw_heart(heart_origin, Color(color, (1.0 - progress) * 0.38), 1.0 + (1.0 - progress) * 0.18)
		_draw_heart(heart_origin, heart_color, 1.0)


func _draw_heart(origin: Vector2, color: Color, scale_factor: float) -> void:
	var center := origin + HEART_SIZE * 0.5
	var points := PackedVector2Array([
		Vector2(15.0, 25.0), Vector2(2.0, 13.0), Vector2(1.0, 8.0),
		Vector2(4.0, 3.0), Vector2(9.0, 2.0), Vector2(15.0, 8.0),
		Vector2(21.0, 2.0), Vector2(26.0, 3.0), Vector2(29.0, 8.0),
		Vector2(28.0, 13.0)
	])
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(center + (point - HEART_SIZE * 0.5) * scale_factor)
	_draw_layer.draw_colored_polygon(scaled, color)
	var outline := scaled.duplicate()
	outline.append(scaled[0])
	_draw_layer.draw_polyline(outline, Color(1.0, 1.0, 1.0, 0.38 if color.a > 0.5 else 0.12), 1.0, true)
