extends CanvasLayer
## 等号开关面板；所有调试操作仅用鼠标按钮，避免加减号误触。
signal panel_state_changed
var main_column: VBoxContainer
var music_column: VBoxContainer
var music_status: Label
var song_buttons: Array[Button] = []
var song_menu_button: Button
var controller: Node
var panel: PanelContainer
var current_time: Label
var current_event: Label
var next_event: Label
var next_event_button: Button
var previous_button: Button
var next_time_button: Button
var teleport_301_button: Button

func _ready() -> void:
	layer=60
	controller=get_parent()
	panel=PanelContainer.new()
	add_child(panel)
	panel.size=Vector2(820,860)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("#142638")
	style.border_color=Color("#89b9ce")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new()
	main_column=column
	column.add_theme_constant_override("separation",16)
	panel.add_child(column)
	column.add_child(_label("调试面板",30))
	current_time=_label("",30)
	column.add_child(current_time)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	column.add_child(row)
	previous_button=_button("− 上一时段",func():controller._debug_step_time(-1))
	next_time_button=_button("＋ 下一时段",func():controller._debug_step_time(1))
	row.add_child(previous_button)
	row.add_child(next_time_button)
	column.add_child(HSeparator.new())
	current_event=_label("",23)
	column.add_child(current_event)
	next_event=_label("",22)
	column.add_child(next_event)
	next_event_button=_button("＋ 跳到下一个事件节点",_next_event)
	column.add_child(next_event_button)
	column.add_child(HSeparator.new())
	teleport_301_button=_button("传送到301宿舍",_teleport_to_301)
	column.add_child(teleport_301_button)
	song_menu_button=_button("点歌",_open_music)
	column.add_child(song_menu_button)
	column.add_child(_label("时段、事件和传送均使用鼠标点击。\n事件跳转会同步时段，保留当前天数。",21))
	column.add_child(_button("关闭调试面板",close))
	music_column=VBoxContainer.new()
	music_column.add_theme_constant_override("separation",16)
	panel.add_child(music_column)
	music_column.add_child(_label("点歌",30))
	music_status=_label("当前未播放歌曲",24)
	music_column.add_child(music_status)
	var music_script=preload("res://scripts/night_music.gd")
	for i in range(music_script.TRACK_NAMES.size()):
		var button: Button=_button(music_script.TRACK_NAMES[i],_choose_song.bind(i))
		music_column.add_child(button)
		song_buttons.append(button)
	music_column.add_child(_button("停止播放",_stop_music))
	music_column.add_child(_button("返回调试面板",_back_to_main))
	music_column.add_child(_label("鼠标点歌 · 选中后立即播放
切换场景继续播放，进入下一时段时结束。",21))
	music_column.hide()
	controller.day_cycle.changed.connect(_refresh)
	controller.story.changed.connect(_refresh)
	get_viewport().size_changed.connect(_layout)
	_refresh()
	panel.hide()
	_layout()

func _label(caption:String,font_size:int) -> Label:
	var label:=Label.new()
	label.text=caption
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	return label

func _button(caption:String,callback:Callable) -> Button:
	var button:=Button.new()
	button.text=caption
	button.custom_minimum_size=Vector2(260,60)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.focus_mode=Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",24)
	button.pressed.connect(callback)
	return button

func _layout() -> void:
	var view:Vector2=get_viewport().get_visible_rect().size
	panel.size=Vector2(820,860)
	var factor:float=minf(1,minf((view.x-60)/820,(view.y-60)/860))
	panel.scale=Vector2.ONE*factor
	panel.position=(view-panel.size*factor)*0.5

func _process(_delta:float) -> void:
	if is_open() and panel.size.y!=860 and panel.get_combined_minimum_size().y<=860:_layout()

func _refresh() -> void:
	current_time.text=controller.day_cycle.display_text()
	previous_button.disabled=controller.day_cycle.day==1 and controller.day_cycle.period==0
	current_event.text="当前事件："+controller.story.node_name(controller.story.node_id)
	var next:String=controller.story.next_node_id()
	next_event_button.disabled=next.is_empty()
	if next.is_empty():
		next_event.text="已到最后一个已制作的事件节点。"
	else:
		var periods:Array=["早上","中午","下午","晚上"]
		next_event.text="下个节点：%s · %s"%[controller.story.node_name(next),periods[controller.story.node_period(next)]]

func _next_event() -> void:
	controller._debug_next_event()
	_refresh()

func is_open() -> bool:
	return panel!=null and panel.visible

func close() -> void:
	panel.hide()
	_back_to_main()
	panel_state_changed.emit()

func _input(event:InputEvent) -> void:
	if not event is InputEventKey:return
	var key:int=event.keycode
	var physical:int=event.physical_keycode
	var plus:bool=key in [KEY_PLUS,KEY_KP_ADD] or physical==KEY_KP_ADD or (event.shift_pressed and (key==KEY_EQUAL or physical==KEY_EQUAL))
	var equal:bool=not plus and (key==KEY_EQUAL or physical==KEY_EQUAL)
	if not is_open():
		if not event.pressed or event.echo or not equal:return
		if controller.bed_transition_busy or (controller.supply_view != null and controller.supply_view.is_open()):return
		if controller.game_menu.is_open():controller.game_menu.close()
		panel.show()
		_refresh()
		_layout()
		panel_state_changed.emit()
	elif event.pressed and not event.echo:
		if key==KEY_ESCAPE and music_column.visible:_back_to_main()
		elif equal or key==KEY_ESCAPE:close()
	# 面板开启时键盘只用于关闭，不再绑定任何时段或事件操作。
	get_viewport().set_input_as_handled()

func _teleport_to_301() -> void:
	controller._load_place("宿舍尽头房间一",Vector2(550,200))
	close()

func _open_music() -> void:
	main_column.hide()
	music_column.show()
	if not controller.night_music.changed.is_connected(_refresh_music):controller.night_music.changed.connect(_refresh_music)
	_refresh_music()
	_layout()
func _back_to_main() -> void:
	music_column.hide()
	main_column.show()
	_layout()
func _refresh_music() -> void:
	music_status.text=controller.night_music.status_text()
func _choose_song(index: int) -> void:
	controller.night_music.play_song(index)
	_refresh_music()
func _stop_music() -> void:
	controller.night_music.stop_song()
	_refresh_music()
