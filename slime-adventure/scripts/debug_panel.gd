extends CanvasLayer
## 调试入口：等号开关面板，加减号逐时段切换。
signal panel_state_changed
var controller: Node
var panel: PanelContainer
var current_time: Label
var previous_button: Button
var teleport_301_button: Button

func _ready() -> void:
	layer = 60
	controller = get_parent()
	panel = PanelContainer.new()
	add_child(panel)
	panel.position = Vector2(610, 150)
	panel.custom_minimum_size = Vector2(600, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#142638")
	style.border_color = Color("#89b9ce")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)
	var title := Label.new()
	title.text = "调试面板"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	current_time = Label.new()
	current_time.add_theme_font_size_override("font_size", 32)
	column.add_child(current_time)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	previous_button = _button("− 上一时段", -1)
	row.add_child(previous_button)
	row.add_child(_button("＋ 下一时段", 1))
	column.add_child(HSeparator.new())
	var teleport_label := Label.new()
	teleport_label.text = "传送"
	teleport_label.add_theme_font_size_override("font_size", 24)
	column.add_child(teleport_label)
	teleport_301_button = Button.new()
	teleport_301_button.text = "传送到301宿舍"
	teleport_301_button.custom_minimum_size = Vector2(0, 64)
	teleport_301_button.focus_mode = Control.FOCUS_NONE
	teleport_301_button.add_theme_font_size_override("font_size", 25)
	teleport_301_button.pressed.connect(_teleport_to_301)
	column.add_child(teleport_301_button)
	var hint := Label.new()
	hint.text = "+ / − 切换时段（支持小键盘）\n= 或 Esc 关闭 · 第1天早上为起点"
	hint.add_theme_font_size_override("font_size", 21)
	column.add_child(hint)
	controller.day_cycle.changed.connect(_refresh)
	_refresh()
	panel.hide()

func _button(text: String, direction: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 60)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(func(): controller._debug_step_time(direction))
	return button

func _refresh() -> void:
	current_time.text = controller.day_cycle.display_text()
	previous_button.disabled = controller.day_cycle.day == 1 and controller.day_cycle.period == 0

func is_open() -> bool:
	return panel != null and panel.visible

func close() -> void:
	panel.hide()
	panel_state_changed.emit()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key: int = event.keycode
	var physical: int = event.physical_keycode
	var plus: bool = key in [KEY_PLUS, KEY_KP_ADD] or physical == KEY_KP_ADD or (event.shift_pressed and (key == KEY_EQUAL or physical == KEY_EQUAL))
	var equal: bool = not plus and (key == KEY_EQUAL or physical == KEY_EQUAL)
	if not is_open():
		if not event.pressed or event.echo or not equal: return
		if controller.bed_transition_busy: return
		if controller.game_menu.is_open(): controller.game_menu.close()
		panel.show()
		_refresh()
		panel_state_changed.emit()
	elif event.pressed and not event.echo:
		if equal or key == KEY_ESCAPE: close()
		elif plus: controller._debug_step_time(1)
		elif key in [KEY_MINUS, KEY_KP_SUBTRACT] or physical in [KEY_MINUS, KEY_KP_SUBTRACT]: controller._debug_step_time(-1)
	get_viewport().set_input_as_handled()

func _teleport_to_301() -> void:
	# 使用正常场景切换入口，清理上铺、坐姿、对话等临时状态。
	controller._load_place("宿舍尽头房间一", Vector2(550, 200))
	close()