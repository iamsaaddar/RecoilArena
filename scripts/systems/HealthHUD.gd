extends CanvasLayer
class_name HealthHUD
## Compact three-segment health display with a short hit-loss animation.

signal play_again_requested

const SEGMENT_COUNT := 3
const SEGMENT_WIDTH := 34.0
const SEGMENT_HEIGHT := 8.0
const SEGMENT_GAP := 8.0
const ANIMATION_DURATION := 0.32
const LEFT_MARGIN := 52.0
const TOP_MARGIN := 8.0

var _health := {1: 0, 2: 0}
var _colors := {1: Color("3b82f6"), 2: Color("ef4444")}
var _animations := {1: -1.0, 2: -1.0}
var _draw_layer: Control
var _winner_text := ""
var _round_overlay: Control
var _winner_label: Label
var _play_again_button: Button


func _ready() -> void:
	_draw_layer = Control.new()
	_draw_layer.name = "HealthDisplay"
	_draw_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.draw.connect(_draw_health)
	add_child(_draw_layer)
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
	_winner_text = "PLAYER %d WINS" % player_id
	_winner_label.text = _winner_text
	_winner_label.show()
	_play_again_button.text = "PLAY AGAIN"
	_play_again_button.disabled = false
	_play_again_button.show()
	_round_overlay.show()
	_draw_layer.queue_redraw()


func show_countdown(value: String) -> void:
	_winner_label.text = value
	_winner_label.show()
	_play_again_button.hide()
	_round_overlay.show()


func reset_health() -> void:
	_health[1] = 0
	_health[2] = 0
	_animations[1] = -1.0
	_animations[2] = -1.0
	_winner_text = ""
	_draw_layer.queue_redraw()


func hide_round_overlay() -> void:
	_round_overlay.hide()


func _create_round_overlay() -> void:
	_round_overlay = Control.new()
	_round_overlay.name = "RoundOverlay"
	_round_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_round_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_round_overlay.hide()
	add_child(_round_overlay)

	_winner_label = Label.new()
	_winner_label.name = "WinnerLabel"
	_winner_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_winner_label.offset_left = -250.0
	_winner_label.offset_top = -76.0
	_winner_label.offset_right = 250.0
	_winner_label.offset_bottom = -20.0
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_winner_label.add_theme_font_size_override("font_size", 34)
	_winner_label.add_theme_color_override("font_color", Color("f8fafc"))
	_round_overlay.add_child(_winner_label)

	_play_again_button = Button.new()
	_play_again_button.name = "PlayAgainButton"
	_play_again_button.text = "PLAY AGAIN"
	_play_again_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_play_again_button.offset_left = -112.0
	_play_again_button.offset_top = 12.0
	_play_again_button.offset_right = 112.0
	_play_again_button.offset_bottom = 64.0
	_play_again_button.add_theme_font_size_override("font_size", 18)
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_round_overlay.add_child(_play_again_button)

func _on_play_again_pressed() -> void:
	_play_again_button.disabled = true
	play_again_requested.emit()


func _process(delta: float) -> void:
	var needs_redraw := false
	for player_id in [1, 2]:
		if _animations[player_id] >= 0.0:
			_animations[player_id] += delta
			if _animations[player_id] >= ANIMATION_DURATION:
				_animations[player_id] = -1.0
			needs_redraw = true
	if needs_redraw:
		_draw_layer.queue_redraw()


func _draw_health() -> void:
	var font := ThemeDB.fallback_font
	var total_width := SEGMENT_COUNT * SEGMENT_WIDTH + (SEGMENT_COUNT - 1) * SEGMENT_GAP
	_draw_player(1, Vector2(LEFT_MARGIN, TOP_MARGIN), font)
	_draw_player(2, Vector2(_draw_layer.size.x - LEFT_MARGIN - total_width, TOP_MARGIN), font)
func _draw_player(player_id: int, origin: Vector2, font: Font) -> void:
	var color: Color = _colors[player_id]
	var label := "PLAYER %d" % player_id
	_draw_layer.draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.78, 0.82, 0.9, 0.9))
	var segments_y := origin.y + 13.0
	for index in range(SEGMENT_COUNT):
		var rect := Rect2(origin.x + index * (SEGMENT_WIDTH + SEGMENT_GAP), segments_y, SEGMENT_WIDTH, SEGMENT_HEIGHT)
		var lost: bool = index < int(_health[player_id])
		if lost:
			var is_new_loss: bool = index == int(_health[player_id]) - 1 and float(_animations[player_id]) >= 0.0
			if is_new_loss:
				var progress: float = clampf(_animations[player_id] / ANIMATION_DURATION, 0.0, 1.0)
				var scale_x := lerpf(1.0, 0.35, progress)
				var animated_rect := Rect2(rect.position + Vector2((1.0 - scale_x) * rect.size.x * 0.5, 0.0), Vector2(rect.size.x * scale_x, rect.size.y))
				_draw_layer.draw_rect(animated_rect.grow(3.0 * (1.0 - progress)), Color(color, (1.0 - progress) * 0.45), true)
				_draw_layer.draw_rect(animated_rect, Color(color, 1.0 - progress), true)
			else:
				_draw_layer.draw_rect(rect, Color(0.20, 0.23, 0.30, 0.75), true)
				_draw_layer.draw_rect(rect, Color(0.42, 0.47, 0.56, 0.18), false, 1.0)
		else:
			_draw_layer.draw_rect(rect.grow(3.0), Color(color, 0.12), true)
			_draw_layer.draw_rect(rect, color, true)
			_draw_layer.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.35), false, 1.0)
