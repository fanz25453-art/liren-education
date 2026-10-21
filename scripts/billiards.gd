extends Control
## 手表内的单人桌球；坐标、球速和鼠标操作均使用同一逻辑台面。
const VIEW := Vector2(800, 560)
const TABLE := Rect2(32, 100, 736, 368)
const RADIUS := 10.0
const POCKET_RADIUS := 22.0
const MAX_PULL := 150.0
const MAX_SPEED := 1450.0
const FRICTION := 190.0
const POCKETS := [Vector2(24, 92), Vector2(400, 79), Vector2(776, 92),
	Vector2(24, 476), Vector2(400, 489), Vector2(776, 476)]
# 库边为六块实体多边形，斜切的端部也是碰撞面；袋口留出真实通道。
const CUSHIONS := [
	[Vector2(64, 100), Vector2(370, 100), Vector2(384, 84), Vector2(48, 84)],
	[Vector2(430, 100), Vector2(736, 100), Vector2(752, 84), Vector2(416, 84)],
	[Vector2(64, 468), Vector2(370, 468), Vector2(384, 484), Vector2(48, 484)],
	[Vector2(430, 468), Vector2(736, 468), Vector2(752, 484), Vector2(416, 484)],
	[Vector2(32, 132), Vector2(32, 436), Vector2(16, 452), Vector2(16, 116)],
	[Vector2(768, 132), Vector2(768, 436), Vector2(784, 452), Vector2(784, 116)],
]
const SPLASH_SECONDS := 3.0
const MAX_PHYSICS_DELTA := 1.0 / 30.0
const MAX_SUBSTEPS := 12

class Ball:
	var position: Vector2
	var velocity := Vector2.ZERO
	var active := true
	func _init(at: Vector2) -> void:
		position = at

enum Shot { AIM, LOCKED, DRAGGING, MOVING, PLACE, FINISHED }
var page := "library"
var shot: Shot = Shot.AIM
var balls: Array[Ball] = []
var score := 0
var strokes := 0
var direction := Vector2.RIGHT
var drag_origin := Vector2.ZERO
var pull := 0.0
var selection: VBoxContainer
var restart: Button
var splash_elapsed := 0.0
var home_elapsed := 0.0
var keji_texture := preload("res://assets/characters/keji.png")
var logo_font: SystemFont
var cushion_bounds: Array[Rect2] = []
var surface_cache: Dictionary = {}
var placement_cursor := Vector2.INF

func _ready() -> void:
	custom_minimum_size = Vector2(0, 560)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	for polygon in CUSHIONS:
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon: bounds = bounds.expand(point)
		cushion_bounds.append(bounds.grow(RADIUS + 0.001))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo_font = SystemFont.new()
	logo_font.font_names = PackedStringArray(["Arial", "Noto Sans"])
	logo_font.font_weight = 800
	logo_font.font_italic = true
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection = VBoxContainer.new()
	selection.add_theme_constant_override("separation", 28)
	center.add_child(selection)
	restart = _button("再来一局", start_game)
	add_child(restart)
	restart.hide()
	resized.connect(_layout_restart)
	show_library()

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(330, 72)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 28)
	var style := _surface(Color("#21785e"), 12)
	style.border_color = Color("#c5dfb1")
	style.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#329579")
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#155440")
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(action)
	return button

func _selection(heading: String, caption: String, action: Callable) -> void:
	for child in selection.get_children():
		selection.remove_child(child)
		child.queue_free()
	if not heading.is_empty():
		var label := Label.new()
		label.text = heading
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 30)
		selection.add_child(label)
	selection.add_child(_button(caption, action))
	selection.show()
	restart.hide()
	queue_redraw()

func show_library() -> void:
	page = "library"
	_selection("小游戏", "桌球", show_splash)

func show_splash() -> void:
	page = "splash"
	splash_elapsed = 0.0
	selection.hide()
	restart.hide()
	queue_redraw()

func show_modes() -> void:
	page = "modes"
	home_elapsed = 0.0
	_selection("", "单人模式", start_game)

func go_back() -> bool:
	if page == "library": return false
	if page in ["modes", "splash"]: show_library()
	else: show_modes()
	return true

func start_game() -> void:
	page = "playing"
	selection.hide()
	restart.hide()
	balls.clear()
	balls.append(Ball.new(Vector2(200, 284)))
	# 五排三角形，首球朝向白球；间隙避免开局穿插。
	for row in range(5):
		for column in range(row + 1):
			balls.append(Ball.new(Vector2(525 + row * 18.0, 284 + (column - row * 0.5) * 20.8)))
	score = 0
	strokes = 0
	pull = 0.0
	direction = Vector2.RIGHT
	shot = Shot.AIM
	queue_redraw()

func _view_scale() -> float:
	return maxf(0.01, minf(size.x / VIEW.x, size.y / VIEW.y))

func _view_offset() -> Vector2:
	return (size - VIEW * _view_scale()) * 0.5

func _pointer(local: Vector2) -> Vector2:
	return (local - _view_offset()) / _view_scale()

func _layout_restart() -> void:
	if restart == null: return
	var factor := _view_scale()
	restart.scale = Vector2.ONE * factor
	restart.size = Vector2(200, 48)
	restart.position = _view_offset() + Vector2(300, 501) * factor

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if page == "splash":
		splash_elapsed += delta
		if splash_elapsed >= SPLASH_SECONDS: show_modes()
		queue_redraw()
		return
	if page == "modes":
		home_elapsed += delta
		queue_redraw()
		return
	if page != "playing": return
	if shot == Shot.AIM:
		var aim := _pointer(get_local_mouse_position()) - balls[0].position
		if aim.length_squared() > 1.0:
			var next_direction := aim.normalized()
			if not direction.is_equal_approx(next_direction):
				direction = next_direction
				queue_redraw()
	elif shot == Shot.PLACE:
		var cursor := _pointer(get_local_mouse_position())
		if not placement_cursor.is_equal_approx(cursor):
			placement_cursor = cursor
			queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if page != "playing" or not event is InputEventMouseButton: return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	var cursor := _pointer(event.position)
	if shot == Shot.PLACE:
		if _can_place(cursor):
			balls[0].position = cursor
			balls[0].active = true
			shot = Shot.AIM
	elif shot == Shot.AIM and TABLE.has_point(cursor):
		var aim := cursor - balls[0].position
		if aim.length_squared() <= 1.0: return
		direction = aim.normalized()
		shot = Shot.LOCKED
	elif shot == Shot.LOCKED:
		drag_origin = cursor
		pull = 0.0
		shot = Shot.DRAGGING
	accept_event()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or page != "playing" or shot != Shot.DRAGGING: return
	# 全局接收拖动和松手，鼠标离开表盘后也能正常出杆。
	if event is InputEventMouseMotion:
		_update_pull(_pointer((make_input_local(event) as InputEventMouseMotion).position))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_update_pull(_pointer((make_input_local(event) as InputEventMouseButton).position))
		if pull >= 3.0:
			balls[0].velocity = direction * MAX_SPEED * pull / MAX_PULL
			strokes += 1
			shot = Shot.MOVING
		else:
			shot = Shot.LOCKED
		pull = 0.0
		get_viewport().set_input_as_handled()
	queue_redraw()

func _update_pull(cursor: Vector2) -> void:
	pull = clampf((drag_origin - cursor).dot(direction), 0.0, MAX_PULL)

func _physics_process(delta: float) -> void:
	if not is_visible_in_tree() or page != "playing" or shot != Shot.MOVING: return
	# 根据当前实际球速细分；低速无需重复跑高速开球的全部子步。
	var fastest := 0.0
	for ball in balls:
		if ball.active: fastest = maxf(fastest, ball.velocity.length())
	# 偶发长帧不无限补算，避免越卡越积压。正常60Hz和高速防穿透不变。
	var elapsed := minf(delta, MAX_PHYSICS_DELTA)
	var steps := clampi(ceili(elapsed * fastest / (RADIUS * 0.45)), 1, MAX_SUBSTEPS)
	var dt := elapsed / steps
	for step in range(steps):
		_simulate(dt)
	var moving := false
	for ball in balls:
		if ball.active and ball.velocity != Vector2.ZERO: moving = true
	if not moving:
		if score == 15:
			shot = Shot.FINISHED
			restart.show()
			_layout_restart()
		else:
			shot = Shot.AIM if balls[0].active else Shot.PLACE
	queue_redraw()

func _simulate(dt: float) -> void:
	for index in range(balls.size()):
		var ball := balls[index]
		if not ball.active: continue
		ball.position += ball.velocity * dt
		var pocketed := false
		for pocket in POCKETS:
			# 只有穿过库边开口、到达落袋区才进袋，台面上的擦袋球不会被吸走。
			if not TABLE.has_point(ball.position) and ball.position.distance_squared_to(pocket) < POCKET_RADIUS * POCKET_RADIUS:
				ball.active = false
				ball.velocity = Vector2.ZERO
				if index > 0: score += 1
				pocketed = true
				break
		if pocketed: continue
		_collide_cushions(ball)
		ball.velocity = ball.velocity.move_toward(Vector2.ZERO, FRICTION * dt)
	for i in range(balls.size()):
		var a := balls[i]
		if not a.active: continue
		for j in range(i + 1, balls.size()):
			var b := balls[j]
			if not b.active: continue
			var separation := b.position - a.position
			var distance_squared := separation.length_squared()
			if distance_squared >= RADIUS * RADIUS * 4.0: continue
			var distance := sqrt(distance_squared)
			var normal := separation / distance if distance > 0.001 else Vector2.RIGHT
			var correction := normal * (RADIUS * 2.0 - distance) * 0.5
			a.position -= correction
			b.position += correction
			var approach := (a.velocity - b.velocity).dot(normal)
			if approach > 0.0:
				var impulse := normal * approach * 0.98
				a.velocity -= impulse
				b.velocity += impulse
	# 球球碰撞的位置修正也须遵守库边，不能将球挤进实体库边。
	for ball in balls:
		if ball.active: _collide_cushions(ball)

func _collide_cushions(ball: Ball) -> void:
	for index in range(CUSHIONS.size()):
		# 大多数球远离库边，先用缓存包围盒排除，不遍历24条边及开平方。
		if not cushion_bounds[index].has_point(ball.position): continue
		var polygon: Array = CUSHIONS[index]
		for edge in range(polygon.size()):
			var a: Vector2 = polygon[edge]
			var b: Vector2 = polygon[(edge + 1) % polygon.size()]
			var nearest := Geometry2D.get_closest_point_to_segment(ball.position, a, b)
			var separation := ball.position - nearest
			var distance_squared := separation.length_squared()
			if distance_squared >= RADIUS * RADIUS or distance_squared < 0.00000001: continue
			var distance := sqrt(distance_squared)
			var normal := separation / distance
			ball.position += normal * (RADIUS - distance)
			var toward := ball.velocity.dot(normal)
			if toward < 0.0:
				# 法向恢复系数损失能量，切向分量不作镜像，保留正确反射角。
				ball.velocity -= normal * toward * 1.86

func _can_place(at: Vector2) -> bool:
	if not TABLE.grow(-RADIUS - 1.0).has_point(at): return false
	for pocket in POCKETS:
		if at.distance_to(pocket) < POCKET_RADIUS + RADIUS: return false
	for index in range(1, balls.size()):
		if balls[index].active and at.distance_to(balls[index].position) < RADIUS * 2.0 + 1.0: return false
	return true

func _text(at: Vector2, text: String, font_size: int = 22, color := Color("#edf3f8")) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	draw_set_transform(_view_offset(), 0, Vector2.ONE * _view_scale())
	if page == "splash":
		_draw_splash()
		return
	if page == "modes":
		_draw_home()
		return
	if page != "playing": return
	_text(Vector2(24, 31), "单人桌球", 28)
	_text(Vector2(360, 31), "得分 %d / 15    击球 %d 杆" % [score, strokes], 24)
	draw_style_box(_surface(Color("#694530"), 18), TABLE.grow(20))
	draw_rect(TABLE, Color("#238554"))
	draw_line(Vector2(210, 101), Vector2(210, 467), Color("#40976b"), 1)
	for pocket in POCKETS:
		draw_circle(pocket, POCKET_RADIUS + 4, Color("#372b25"))
		draw_circle(pocket, POCKET_RADIUS, Color("#071411"))
		draw_arc(pocket, POCKET_RADIUS - 5, 0.2, PI - 0.2, 16, Color("#283d34"), 2, true)
	for cushion in CUSHIONS:
		var polygon := PackedVector2Array(cushion)
		draw_colored_polygon(polygon, Color("#145439"))
		draw_line(polygon[0], polygon[1], Color("#66aa79"), 2, true)
	for index in range(balls.size()):
		var ball := balls[index]
		if not ball.active: continue
		draw_circle(ball.position + Vector2(2, 3), RADIUS, Color(0, 0, 0, 0.25))
		draw_circle(ball.position, RADIUS, Color("#f4f1e7") if index == 0 else Color("#d72f42"))
		draw_circle(ball.position + Vector2(-3, -3), 3, Color(1, 1, 1, 0.45))
	if shot in [Shot.AIM, Shot.LOCKED, Shot.DRAGGING]:
		var cue := balls[0].position
		var length := _aim_length(cue)
		draw_dashed_line(cue + direction * RADIUS, cue + direction * length, Color("#f3e1a0"), 2, 8)
		var cue_start := cue - direction * (RADIUS + 12 + pull * 0.45)
		draw_line(cue_start, cue_start - direction * 95, Color("#d5b17b"), 5, true)
		draw_line(cue_start, cue_start - direction * 10, Color("#e5eff6"), 5, true)
	if shot == Shot.PLACE:
		var cursor := _pointer(get_local_mouse_position())
		draw_circle(cursor, RADIUS, Color(0.8, 1, 0.8, 0.6) if _can_place(cursor) else Color(1, 0.3, 0.3, 0.6))
	var hints := {
		Shot.AIM: "移动鼠标瞄准 · 左键单击锁定方向",
		Shot.LOCKED: "方向已锁定 · 再按住左键，向击球反方向拖动",
		Shot.DRAGGING: "反向拖动蓄力 · 松开左键出杆",
		Shot.MOVING: "球正在运动，请等待停稳……",
		Shot.PLACE: "白球落袋，不扣分 · 点击空闲台面重新摆放白球",
		Shot.FINISHED: "全部红球落袋！最终得分 15 分 · 共 %d 杆" % strokes,
	}
	_text(Vector2(24, 52), hints[shot], 18)
	if shot != Shot.FINISHED:
		_text(Vector2(24, 549), "力度", 22)
		draw_style_box(_surface(Color("#293f50"), 8), Rect2(90, 532, 570, 16))
		if pull > 0:
			draw_style_box(_surface(Color("#e4c66c"), 8), Rect2(90, 532, 570 * pull / MAX_PULL, 16))
		_text(Vector2(680, 549), "%d%%" % roundi(pull / MAX_PULL * 100), 22)

func _surface(color: Color, radius: int) -> StyleBoxFlat:
	var key := "%s/%d" % [color.to_rgba32(), radius]
	if surface_cache.has(key): return surface_cache[key]
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	surface_cache[key] = style
	return style

func _centered(text: String, baseline: float, font: Font, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((VIEW.x - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _brand(baseline: float, font_size: int, color: Color) -> void:
	_centered("keji", baseline, logo_font, font_size, color)
	_centered("sports", baseline + font_size * 0.40, logo_font, roundi(font_size * 0.32), color)
	var center := Vector2(400 + font_size * 0.95, baseline - font_size * 0.64)
	draw_arc(center, font_size * 0.22, -2.5, 1.0, 28, color, maxf(2, font_size * 0.035), true)
	draw_circle(center, font_size * 0.065, color)

func _draw_splash() -> void:
	draw_style_box(_surface(Color("#f7f5ef"), 14), Rect2(Vector2.ZERO, VIEW))
	var alpha := smoothstep(0.0, 0.45, splash_elapsed) * (1.0 - smoothstep(2.6, 3.0, splash_elapsed))
	_brand(280, 112, Color(0.08, 0.13, 0.16, alpha))
	_centered("让每一次出杆，都有精彩。", 407, ThemeDB.fallback_font, 20, Color(0.22, 0.35, 0.31, alpha))
	draw_line(Vector2(325, 455), Vector2(475, 455), Color("#dbe2db"), 3, true)
	draw_line(Vector2(325, 455), Vector2(325 + 150 * clampf(splash_elapsed / SPLASH_SECONDS, 0, 1), 455), Color("#328064"), 3, true)

func _draw_home() -> void:
	draw_style_box(_surface(Color("#101f26"), 14), Rect2(Vector2.ZERO, VIEW))
	# 球房灯光与斜置球桌，按钮始终覆盖在背景正中央。
	draw_colored_polygon(PackedVector2Array([Vector2(300, 24), Vector2(520, 24), Vector2(800, 530), Vector2(20, 530)]), Color("#1b3033"))
	draw_line(Vector2(410, 0), Vector2(410, 34), Color("#64776f"), 3)
	draw_style_box(_surface(Color("#d8c58e"), 8), Rect2(340, 29, 140, 12))
	var outline := PackedVector2Array([Vector2(238, 188), Vector2(664, 143), Vector2(786, 420), Vector2(273, 500)])
	draw_colored_polygon(outline, Color("#583e30"))
	var felt := PackedVector2Array([Vector2(254, 205), Vector2(652, 161), Vector2(757, 404), Vector2(287, 477)])
	draw_colored_polygon(felt, Color("#22714f"))
	draw_polyline(PackedVector2Array([felt[0], felt[1], felt[2], felt[3], felt[0]]), Color("#459570"), 5, true)
	for pocket in [felt[0], felt[1], felt[2], felt[3], (felt[0] + felt[1]) * 0.5, (felt[2] + felt[3]) * 0.5]:
		draw_circle(pocket, 14, Color("#0c1918"))
	for at in [Vector2(597, 333), Vector2(621, 328), Vector2(610, 351), Vector2(636, 346), Vector2(625, 369)]:
		draw_circle(at + Vector2(2, 4), 11, Color(0, 0, 0, 0.22))
		draw_circle(at, 10, Color("#db4050"))
		draw_circle(at + Vector2(-3, -3), 3, Color("#ee8d8e"))
	var stroke := sin(home_elapsed * 1.8) * 7.0
	draw_circle(Vector2(469 + maxf(stroke, 0) * 1.5, 345), 11, Color("#f5f1d9"))
	# 使用 keji 自身的右向角色帧，俯身朝球桌，球杆做轻微运杆动画。
	var factor := _view_scale()
	var origin := _view_offset()
	draw_set_transform(origin + Vector2(125, 297) * factor, -0.22, Vector2.ONE * factor)
	draw_texture_rect_region(keji_texture, Rect2(-104, -154, 288, 288), Rect2(0, 704, 64, 64))
	draw_set_transform(origin, 0, Vector2.ONE * factor)
	draw_line(Vector2(183 + stroke, 319), Vector2(449 + stroke, 344), Color("#d4b884"), 5, true)
	draw_line(Vector2(433 + stroke, 342), Vector2(449 + stroke, 344), Color("#ecf4e7"), 5, true)
	draw_circle(Vector2(266 + stroke * 0.2, 327), 7, Color("#e4c6a4"))
	# 中央留出原生单人模式按钮，暗条提高文字与背景的对比度。
	draw_style_box(_surface(Color(0.02, 0.06, 0.07, 0.35), 12), Rect2(210, 222, 380, 112))
	_brand(115, 65, Color("#f2ebd4"))
	_centered("桌 球", 194, ThemeDB.fallback_font, 25, Color("#c1d6bd"))
	_centered("十五颗红球，一杆接一杆。", 535, ThemeDB.fallback_font, 21, Color("#c1d6bd"))

func _aim_length(cue: Vector2) -> float:
	var length := 220.0
	for axis in range(2):
		if absf(direction[axis]) < 0.0001: continue
		var edge: float = TABLE.end[axis] if direction[axis] > 0 else TABLE.position[axis]
		length = minf(length, (edge - cue[axis]) / direction[axis])
	return maxf(RADIUS, length)
