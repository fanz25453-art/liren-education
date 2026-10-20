extends CanvasLayer
signal view_state_changed
const CABINET_PALETTE = preload("res://scripts/cabinet_palette.gd")
var overlay: Control
var frame: Control
var controller: Node

class CabinetFront extends Control:
	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_style_box(_surface(Color("#eee7d7")), Rect2(0,0,1100,840))
		draw_string(ThemeDB.fallback_font,Vector2(45,52),"宿舍柜子",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("#4d4d3e"))
		# 上下柜使用同一完整素材、同一尺寸，中间留出完整开放空间。
		for index in range(4):
			draw_texture_rect_region(CABINET_PALETTE.texture(),Rect2(90+index*230,85,230,220),Rect2(528,504,48,104))
		draw_rect(Rect2(90,315,920,227),Color("#e4dbc7"))
		# 下柜顶板就是台面，薄边直接衔接柜体，不另加悬空厚台。
		for index in range(4):
			draw_texture_rect_region(CABINET_PALETTE.texture(),Rect2(90+index*230,557,230,220),Rect2(528,504,48,104))
		draw_texture_rect_region(CABINET_PALETTE.texture(),Rect2(90,539,920,30),Rect2(675,388,18,128))
		draw_line(Vector2(90,539),Vector2(1010,539),Color("#e9dbb8"),3)
		draw_string(ThemeDB.fallback_font,Vector2(365,815),"E / Esc 返回宿舍",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("#5c604e"))
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
	_layout()
	overlay.show()
	view_state_changed.emit()

func close() -> void:
	overlay.hide()
	view_state_changed.emit()

func _input(event:InputEvent) -> void:
	if not is_open() or not event is InputEventKey:return
	var key:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if event.pressed and not event.echo and key in [KEY_E,KEY_ESCAPE]:close()
	get_viewport().set_input_as_handled()




