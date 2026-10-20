extends CanvasLayer
signal state_changed
signal answered(accepted:bool)
var overlay:Control
var buttons:Array[Button]=[]
var selected:int=0
func _ready():
 layer=56
 overlay=Control.new()
 add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var dim:=ColorRect.new()
 dim.color=Color(0.02,0.03,0.04,0.65)
 overlay.add_child(dim)
 dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var center:=CenterContainer.new()
 overlay.add_child(center)
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var panel:=PanelContainer.new()
 panel.custom_minimum_size=Vector2(620,300)
 center.add_child(panel)
 var margin:=MarginContainer.new()
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,30)
 panel.add_child(margin)
 var column:=VBoxContainer.new()
 column.add_theme_constant_override("separation",18)
 margin.add_child(column)
 var label:=Label.new()
 label.text="wqy：要不要来一场足球射门挑战？"
 label.add_theme_font_size_override("font_size",26)
 column.add_child(label)
 for i in range(2):
  var button:=Button.new()
  button.custom_minimum_size.y=58
  button.focus_mode=Control.FOCUS_NONE
  button.add_theme_font_size_override("font_size",26)
  button.pressed.connect(_answer.bind(i==0))
  button.mouse_entered.connect(_select.bind(i))
  column.add_child(button)
  buttons.append(button)
 var hint:=Label.new()
 hint.text="↑↓ 选择 · E / Enter 确认 · Esc 取消 · 也可鼠标点击"
 hint.add_theme_font_size_override("font_size",18)
 column.add_child(hint)
 overlay.hide()
func is_open()->bool:return overlay!=null and overlay.visible
func open():
 _select(0)
 overlay.show()
 state_changed.emit()
func close():
 overlay.hide()
 state_changed.emit()
func _select(index:int):
 selected=index
 for i in range(2):buttons[i].text=("▶  " if i==selected else "    ")+("是" if i==0 else "否")
func _answer(accepted:bool):
 close()
 answered.emit(accepted)
func _input(event:InputEvent):
 if not is_open() or not event is InputEventKey:return
 if event.pressed and not event.echo:
  var code:int=event.physical_keycode if event.physical_keycode else event.keycode
  if code in [KEY_UP,KEY_DOWN,KEY_W,KEY_S]:_select(1-selected)
  elif code in [KEY_E,KEY_ENTER,KEY_KP_ENTER]:_answer(selected==0)
  elif code==KEY_ESCAPE:_answer(false)
 get_viewport().set_input_as_handled()
