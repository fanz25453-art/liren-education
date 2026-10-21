extends CanvasLayer
signal view_state_changed
const CABINET_PALETTE = preload("res://scripts/cabinet_palette.gd")
var overlay: Control
var frame: Control
var controller: Node
var story_controls: Array[Control] = []
var story_buttons: Array[Button] = []
var selected_story_button: int = 0
var noodle_feedback: String = ""

class CabinetFront extends Control:
	var own_cabinet: bool = false
	var belongings_stored: bool = false
	var show_noodle_bowl: bool = false
	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_style_box(_surface(Color("#eee7d7")),Rect2(0,0,1100,840))
		draw_string(ThemeDB.fallback_font,Vector2(45,52),"宿舍柜子",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("#4d4d3e"))
		for index in range(4):
			draw_texture_rect_region(CABINET_PALETTE.texture(),Rect2(90+index*230,85,230,220),Rect2(528,504,48,104))
		draw_rect(Rect2(90,315,920,227),Color("#e4dbc7"))
		for index in range(4):
			draw_texture_rect_region(CABINET_PALETTE.texture(),Rect2(90+index*230,557,230,220),Rect2(528,504,48,104))
		draw_texture_rect_region(CABINET_PALETTE.texture(),Rect2(90,539,920,30),Rect2(675,388,18,128))
		draw_line(Vector2(90,539),Vector2(1010,539),Color("#e9dbb8"),3)
		if own_cabinet:
			draw_string(ThemeDB.fallback_font,Vector2(115,348),"柜子台面",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("#5b604e"))
			draw_rect(Rect2(780,557,230,220),Color("#a58a4e"),false,4)
			draw_string(ThemeDB.fallback_font,Vector2(812,595),"自己的柜子",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("#65562f"))
			if belongings_stored:
				draw_string(ThemeDB.fallback_font,Vector2(816,719),"物品已放好",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("#4b6148"))
		if show_noodle_bowl:
			draw_circle(Vector2(550,488),31,Color("#faf0d7"))
			draw_circle(Vector2(550,488),24,Color("#c99458"))
			for y in [480,487,494]:
				draw_line(Vector2(534,y),Vector2(563,y+2),Color("#e6cb6d"),3)
			draw_line(Vector2(574,466),Vector2(603,444),Color("#73654d"),3)
		draw_string(ThemeDB.fallback_font,Vector2(195,815),"↑↓ 选择 · Enter 操作 · E / Esc 返回宿舍",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("#5c604e"))
	func _surface(color:Color) -> StyleBoxFlat:
		var style:=StyleBoxFlat.new()
		style.bg_color=color
		style.set_corner_radius_all(16)
		return style

func _ready() -> void:
	layer=55
	controller=get_parent()
	overlay=Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim:=ColorRect.new()
	dim.color=Color(0.02,0.035,0.04,0.84)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame=CabinetFront.new()
	overlay.add_child(frame)
	frame.size=Vector2(1100,840)
	var close_button:=Button.new()
	close_button.text="返回"
	close_button.focus_mode=Control.FOCUS_NONE
	close_button.position=Vector2(940,18)
	close_button.size=Vector2(115,48)
	close_button.add_theme_font_size_override("font_size",24)
	close_button.pressed.connect(close)
	frame.add_child(close_button)
	get_viewport().size_changed.connect(_layout)
	_layout()
	overlay.hide()

func _layout() -> void:
	var view:Vector2=get_viewport().get_visible_rect().size
	var factor:float=minf(1.0,minf((view.x-80.0)/1100.0,(view.y-80.0)/840.0))
	frame.scale=Vector2.ONE*maxf(0.1,factor)
	frame.position=(view-frame.size*frame.scale)*0.5

func is_open() -> bool:
	return overlay!=null and overlay.visible

func open() -> void:
	selected_story_button=0
	noodle_feedback=""
	frame.show_noodle_bowl=false
	refresh_story_contents()
	_layout()
	overlay.show()
	view_state_changed.emit()

func close() -> void:
	overlay.hide()
	view_state_changed.emit()

func refresh_story_contents() -> void:
	for control in story_controls:
		frame.remove_child(control)
		control.queue_free()
	story_controls.clear()
	story_buttons.clear()
	frame.own_cabinet=controller.place=="宿舍尽头房间一"
	frame.belongings_stored=controller.story.belongings_stored and frame.own_cabinet
	if frame.own_cabinet:
		if controller.can_organize_dorm_items():
			_add_story_button("放好随身物品",controller.organize_dorm_items,Vector2(795,640),Vector2(200,56))
		elif controller.story.node_id=="dorm_organize" and not frame.belongings_stored:
			_add_note("中午再来整理",Vector2(800,655),Vector2(200,46))
		_add_note("泡面请在宿舍中间展开的桌板上吃。",Vector2(115,418),Vector2(880,44))
	selected_story_button=clampi(selected_story_button,0,maxi(0,story_buttons.size()-1))
	_highlight_story_button()
	frame.queue_redraw()

func _eat_noodles() -> void:
	var used: bool=controller.game_menu.features.use_item("instant_noodles")
	noodle_feedback=controller.game_menu.features.feedback
	if used:
		frame.show_noodle_bowl=true
		noodle_feedback="泡面吃完了，体力恢复了。"
	refresh_story_contents()

func _add_note(caption:String,at:Vector2,dimensions:Vector2) -> void:
	var note:=Label.new()
	note.text=caption
	note.position=at
	note.size=dimensions
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size",21)
	note.add_theme_color_override("font_color",Color("#595c4c"))
	frame.add_child(note)
	story_controls.append(note)

func _add_story_button(caption:String,callback:Callable,at:Vector2,dimensions:Vector2,enabled:bool=true) -> void:
	var button:=Button.new()
	button.text=caption
	button.position=at
	button.size=dimensions
	button.add_theme_font_size_override("font_size",22)
	button.focus_mode=Control.FOCUS_NONE
	button.disabled=not enabled
	button.pressed.connect(callback)
	frame.add_child(button)
	story_controls.append(button)
	if enabled:story_buttons.append(button)

func _highlight_story_button() -> void:
	for index in range(story_buttons.size()):
		story_buttons[index].modulate=Color("#ffe09b") if index==selected_story_button else Color.WHITE

func _input(event:InputEvent) -> void:
	if not is_open() or not event is InputEventKey:return
	var key:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if event.pressed and not event.echo:
		if key in [KEY_E,KEY_ESCAPE]:close()
		elif key in [KEY_UP,KEY_DOWN] and not story_buttons.is_empty():
			selected_story_button=posmod(selected_story_button+(-1 if key==KEY_UP else 1),story_buttons.size())
			_highlight_story_button()
		elif key in [KEY_ENTER,KEY_KP_ENTER] and not story_buttons.is_empty():
			story_buttons[selected_story_button].pressed.emit()
	get_viewport().set_input_as_handled()
