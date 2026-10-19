extends CanvasLayer
## X：传统菜单；G：手表。小游戏内提供单人桌球。
signal menu_state_changed
const MENU_ITEMS := ["背包", "装备", "道具", "状态", "技能", "存档", "设置"]
const APPS := ["B站视频", "小游戏", "时钟", "相册", "相机", "手电筒"]
const APP_COLORS := ["#e68daf", "#83bca1", "#83b5d0", "#b59bd2", "#d3b982", "#9eacbc"]
var mode: String = ""
var selected: int = 0
var showing_placeholder: bool = false
var overlay: Control
var watch_strap: Control
var panel: PanelContainer
var title: Label
var subtitle: Label
var choices: GridContainer
var detail: Label
var footer: Label
var buttons: Array[Button] = []
var controller: Node
var minigames: Control
var showing_games := false

class WatchStrap extends Control:
	func _draw() -> void:
		# 上下表带压在表盘下方，与表盘中线对齐。
		for top in [0.0, 1110.0]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("#344354")
			style.border_color = Color("#75889a")
			style.set_border_width_all(3)
			style.set_corner_radius_all(22)
			draw_style_box(style, Rect2(325, top, 250, 270))
			for x in [344.0, 556.0]:
				draw_line(Vector2(x, top + 24), Vector2(x, top + 248), Color("#536679"), 2)
			for y in range(45, 240, 25):
				draw_line(Vector2(358, top + y), Vector2(542, top + y), Color("#3c4d60"), 2)
		# 上带金属扣和固定环。
		draw_rect(Rect2(353, 25, 194, 77), Color("#a6b3bc"), false, 9)
		draw_line(Vector2(450, 30), Vector2(450, 90), Color("#c3cdd4"), 6)
		draw_rect(Rect2(320, 148, 260, 25), Color("#253443"))
		draw_line(Vector2(322, 150), Vector2(578, 150), Color("#677c8c"), 2)
		# 下带调节孔，仅作外观。
		for y in [1182, 1218, 1254, 1290, 1326]:
			draw_style_box(_hole(), Rect2(439, y, 22, 12))
	func _hole() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#14212e")
		style.border_color = Color("#647688")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		return style

class AppIcon extends Control:
	var index: int = 0
	func _draw() -> void:
		var color := Color("#edf3f5")
		var r := Rect2(8, 8, 88, 88)
		match index:
			0:
				draw_style_box(_box(Color("#edf3f5")), Rect2(13, 23, 78, 55))
				draw_line(Vector2(37, 12), Vector2(46, 23), color, 4)
				draw_line(Vector2(68, 12), Vector2(58, 23), color, 4)
				draw_colored_polygon(PackedVector2Array([Vector2(44, 35), Vector2(44, 65), Vector2(68, 50)]), Color("#d37b9d"))
			1:
				draw_style_box(_box(color), Rect2(10, 28, 84, 51))
				draw_line(Vector2(24, 53), Vector2(46, 53), Color("#4b8269"), 6)
				draw_line(Vector2(35, 42), Vector2(35, 64), Color("#4b8269"), 6)
				draw_circle(Vector2(70, 45), 5, Color("#4b8269"))
				draw_circle(Vector2(80, 61), 5, Color("#4b8269"))
			2:
				draw_arc(Vector2(52, 52), 35, 0, TAU, 48, color, 5, true)
				draw_line(Vector2(52, 52), Vector2(52, 28), color, 5)
				draw_line(Vector2(52, 52), Vector2(73, 62), color, 5)
			3:
				draw_rect(Rect2(13, 18, 78, 68), color, false, 5)
				draw_circle(Vector2(68, 37), 8, color)
				draw_colored_polygon(PackedVector2Array([Vector2(20, 77), Vector2(42, 44), Vector2(61, 68), Vector2(73, 55), Vector2(86, 77)]), color)
			4:
				draw_style_box(_box(color), Rect2(10, 30, 84, 53))
				draw_rect(Rect2(28, 20, 35, 14), color)
				draw_circle(Vector2(52, 56), 20, Color("#8f7955"))
				draw_circle(Vector2(52, 56), 13, color)
			5:
				draw_colored_polygon(PackedVector2Array([Vector2(29, 20), Vector2(75, 20), Vector2(66, 44), Vector2(38, 44)]), color)
				draw_rect(Rect2(38, 44, 28, 43), color)
				draw_line(Vector2(52, 5), Vector2(52, 13), color, 3)
				draw_line(Vector2(18, 9), Vector2(26, 16), color, 3)
				draw_line(Vector2(86, 9), Vector2(78, 16), color, 3)
	func _box(color: Color) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(10)
		return style

func _ready() -> void:
	layer = 40
	controller = get_parent()
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.04, 0.78)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	watch_strap = WatchStrap.new()
	watch_strap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(watch_strap)
	watch_strap.hide()
	panel = PanelContainer.new()
	overlay.add_child(panel)
	panel.add_theme_stylebox_override("panel", _style("#152335", "#92a9bd", 3))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 38)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	title = _label("", 38)
	column.add_child(title)
	subtitle = _label("", 22)
	subtitle.modulate = Color("#b5c8d9")
	column.add_child(subtitle)
	choices = GridContainer.new()
	choices.add_theme_constant_override("h_separation", 20)
	choices.add_theme_constant_override("v_separation", 20)
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(choices)
	detail = _label("", 30)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(detail)
	minigames = preload("res://scripts/billiards.gd").new()
	column.add_child(minigames)
	minigames.hide()
	footer = _label("", 21)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(footer)
	overlay.hide()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _style(bg: String, border: String, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg)
	style.border_color = Color(border)
	style.set_border_width_all(width)
	style.set_corner_radius_all(16)
	return style

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#edf3f8"))
	return label

func _layout() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var required_height: float = 1440.0 if mode == "watch" else 1000.0
	var factor: float = minf(1.0, minf(view.x / 1000.0, view.y / required_height))
	panel.size = Vector2(900, 900)
	panel.scale = Vector2.ONE * factor
	panel.position = (view - panel.size * factor) * 0.5
	watch_strap.size = Vector2(900, 1380)
	watch_strap.scale = Vector2.ONE * factor
	watch_strap.position = panel.position - Vector2(0, 240) * factor

func is_open() -> bool:
	return not mode.is_empty()

func open(next_mode: String) -> void:
	mode = next_mode
	selected = 0
	showing_placeholder = false
	showing_games = false
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	buttons.clear()
	var watch: bool = mode == "watch"
	title.text = "智能手表" if watch else "冒险菜单"
	subtitle.text = "应用" if watch else controller.player.display_name
	choices.columns = 3 if watch else 1
	var entries: Array = APPS if watch else MENU_ITEMS
	for index in range(entries.size()):
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(260, 250) if watch else Vector2(780, 65)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 27)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.pressed.connect(_confirm.bind(index))
		button.mouse_entered.connect(_select.bind(index))
		choices.add_child(button)
		buttons.append(button)
		if watch:
			var icon := AppIcon.new()
			icon.index = index
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(icon)
			icon.position = Vector2(78, 38)
			icon.size = Vector2(104, 104)
			var caption := _label(entries[index], 27)
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.add_child(caption)
			caption.position = Vector2(0, 177)
			caption.size = Vector2(260, 46)
		else:
			button.text = entries[index]
	overlay.show()
	_refresh()
	_layout()
	menu_state_changed.emit()

func close() -> void:
	mode = ""
	minigames.hide()
	overlay.hide()
	menu_state_changed.emit()

func _select(index: int) -> void:
	if showing_placeholder or showing_games: return
	selected = index
	_refresh()

func _confirm(index: int) -> void:
	selected = index
	if mode == "watch" and index == 1:
		showing_games = true
		minigames.show_library()
		_refresh()
		return
	showing_placeholder = true
	_refresh()

func _refresh() -> void:
	watch_strap.visible = mode == "watch"
	choices.visible = not showing_placeholder and not showing_games
	detail.visible = showing_placeholder and not showing_games
	minigames.visible = showing_games
	if showing_games:
		subtitle.text = "小游戏 · 桌球"
		footer.text = "Esc 返回　·　G 关闭手表"
		return
	subtitle.text = "应用" if mode == "watch" else controller.player.display_name
	var entries: Array = APPS if mode == "watch" else MENU_ITEMS
	detail.text = str(entries[selected]) + "\n\n未开发完成"
	footer.text = "Esc 返回　·　%s 关闭" % ("G" if mode == "watch" else "X") if showing_placeholder else "方向键选择　·　Enter 确认　·　Esc 返回　·　%s 关闭" % ("G" if mode == "watch" else "X")
	for index in range(buttons.size()):
		var bg: String = APP_COLORS[index] if mode == "watch" else "#263b53"
		buttons[index].add_theme_stylebox_override("normal", _style(bg, "#ffe19b" if index == selected else "#62788e", 5 if index == selected else 2))
		buttons[index].add_theme_stylebox_override("hover", _style(bg, "#ffe19b", 5))
		buttons[index].add_theme_stylebox_override("pressed", _style(bg, "#ffffff", 5))

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if not is_open():
		if key not in [KEY_X, KEY_G] or event.echo: return
		if not controller.message.is_empty() or controller.noticeboard_view.visible or controller.bed_transition_busy: return
		open("menu" if key == KEY_X else "watch")
	else:
		if event.echo and key not in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			get_viewport().set_input_as_handled()
			return
		if (mode == "menu" and key == KEY_X) or (mode == "watch" and key == KEY_G):
			close()
		elif key == KEY_ESCAPE:
			if showing_games:
				if not minigames.go_back(): showing_games = false
				_refresh()
			elif showing_placeholder:
				showing_placeholder = false
				_refresh()
			else: close()
		elif not showing_placeholder and not showing_games:
			var columns: int = 3 if mode == "watch" else 1
			var count: int = APPS.size() if mode == "watch" else MENU_ITEMS.size()
			match key:
				KEY_UP: selected = posmod(selected - columns, count)
				KEY_DOWN: selected = posmod(selected + columns, count)
				KEY_LEFT: selected = posmod(selected - 1, count)
				KEY_RIGHT: selected = posmod(selected + 1, count)
				KEY_ENTER, KEY_KP_ENTER: _confirm(selected)
			_refresh()
	get_viewport().set_input_as_handled()
