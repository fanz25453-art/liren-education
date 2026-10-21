extends CanvasLayer
## 新游戏专用的门外第一人称开场，不改变校园出生点。
signal state_changed
const MONOLOGUE := "终于逃出恒一那个鬼地方了，现在不知道立仁会是怎么样。"
var overlay: Control
var dialogue: PanelContainer
var continue_button: Button

class GateView extends Control:
 func _ready()->void:
  mouse_filter=Control.MOUSE_FILTER_IGNORE
  resized.connect(queue_redraw)
 func box(rect:Rect2,color:String)->void:draw_rect(rect,Color(color))
 func polygon(points:Array,color:String)->void:draw_colored_polygon(PackedVector2Array(points),Color(color))
 func text(at:Vector2,value:String,font_size:int,color:String)->void:
  draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(color))
 func _draw()->void:
  draw_rect(Rect2(Vector2.ZERO,size),Color("#809da2"))
  var factor:float=maxf(size.x/2400.0,size.y/1400.0)
  draw_set_transform((size-Vector2(2400,1400)*factor)*0.5,0,Vector2.ONE*factor)
  # 人眼站在门外朝北看：远处教学楼、抬高的平台、左保安厅和右食堂。
  for y in range(0,780,12):
   draw_rect(Rect2(0,y,2400,12),Color("#8fb8c3").lerp(Color("#e3e5cf"),float(y)/780))
  box(Rect2(0,740,2400,660),"#b7b5a6")
  polygon([Vector2(0,1400),Vector2(900,770),Vector2(1500,770),Vector2(2400,1400)],"#c9c5b7")
  # 两侧绿化留在校园内，不挡住中央广场视线。
  for x in [190,330,2090,2250]:
   box(Rect2(x,550,18,250),"#716d55")
   draw_circle(Vector2(x+9,510),100,Color("#5d815b"))
   draw_circle(Vector2(x-25,470),65,Color("#779769"))
  box(Rect2(420,226,1570,510),"#b9b9a7")
  box(Rect2(394,210,1620,28),"#5c6d63")
  for floor in range(5):
   var y:float=248+floor*91
   box(Rect2(420,y,1570,63),"#d0d0be")
   for col in range(12):
    var x:float=450+col*128
    box(Rect2(x,y+9,64,43),"#6c7b73")
    box(Rect2(x+4,y+13,56,35),"#b4d1d4")
    draw_line(Vector2(x+32,y+14),Vector2(x+32,y+48),Color("#e3e9de"),2)
   for x in [642.0,1148.0,1650.0]:
    box(Rect2(x,y+4,38,59),"#78847a")
    box(Rect2(x+4,y+8,30,51),"#d7dacb")
   box(Rect2(420,y+63,1570,10),"#65746b")
   draw_line(Vector2(420,y+78),Vector2(1990,y+78),Color("#8c9a87"),3)
   for x in range(430,1990,32):draw_line(Vector2(x,y+73),Vector2(x,y+88),Color("#84917e"),2)
  # 平台挡墙及左右两组楼梯，立仁教育字位于中间墙面。
  polygon([Vector2(330,736),Vector2(2070,736),Vector2(2160,805),Vector2(240,805)],"#bdbbae")
  box(Rect2(240,805,1920,88),"#9a9f92")
  box(Rect2(240,800,1920,12),"#616d65")
  for x in [570.0,1650.0]:
   polygon([Vector2(x,805),Vector2(x+150,805),Vector2(x+194,960),Vector2(x-44,960)],"#b6b2a5")
   for i in range(9):
    var t:float=float(i)/8
    var y:float=813+t*147
    draw_line(Vector2(x-t*44,y),Vector2(x+150+t*44,y),Color("#777c72"),3)
   draw_line(Vector2(x-8,800),Vector2(x-52,966),Color("#59665f"),12)
   draw_line(Vector2(x+158,800),Vector2(x+202,966),Color("#59665f"),12)
  text(Vector2(1015,868),"立 仁 教 育",48,"#a33435")
  # 保安厅在左前方，食堂沿右边延伸。
  box(Rect2(40,740,330,240),"#d2ccb2")
  box(Rect2(24,714,362,30),"#617d6e")
  text(Vector2(135,738),"保安厅",24,"#f0f0dd")
  box(Rect2(75,785,128,108),"#6c7064")
  box(Rect2(82,792,114,94),"#b4cacf")
  draw_line(Vector2(90,800),Vector2(180,875),Color("#dee4df"),4)
  box(Rect2(246,790,84,190),"#7f897b")
  box(Rect2(254,798,68,182),"#b7c6b8")
  polygon([Vector2(2040,673),Vector2(2400,620),Vector2(2400,995),Vector2(2040,940)],"#7b8793")
  polygon([Vector2(2025,657),Vector2(2400,602),Vector2(2400,641),Vector2(2025,696)],"#4e6071")
  for x in range(2070,2400,84):box(Rect2(x,735-(x-2070)*0.12,52,56),"#b0ced3")
  text(Vector2(2130,687),"食堂",27,"#eef0e6")
  # 近景连续铁栅栏，以粗细、立柱和横梁体现眼前的铁栏杆。
  for x in range(-30,2440,44):
   box(Rect2(x,638,7,429),"#2d3d40")
   draw_line(Vector2(x+1,638),Vector2(x+1,1067),Color("#8c9d9b"),2)
   polygon([Vector2(x-4,638),Vector2(x+3,616),Vector2(x+11,638)],"#34464a")
  for y in [680.0,815.0,1048.0]:
   box(Rect2(0,y,2400,13),"#304044")
   draw_line(Vector2(0,y),Vector2(2400,y),Color("#9aaba7"),3)
  for x in [120.0,540.0,960.0,1380.0,1800.0,2220.0]:
   box(Rect2(x,600,22,485),"#33464a")
   box(Rect2(x+2,606,4,474),"#9baaa4")
   box(Rect2(x-5,591,32,14),"#526965")
  # 门外车辆停在两侧，采用车头正面的透视轮廓。
  for entry in [[-70.0,"#e3e5e2","#b4b9b8"],[2120.0,"#9c2928","#692221"]]:
   var x:float=entry[0]
   polygon([Vector2(x,1065),Vector2(x+40,920),Vector2(x+260,920),Vector2(x+310,1065)],entry[2])
   polygon([Vector2(x+58,933),Vector2(x+244,933),Vector2(x+277,1012),Vector2(x+30,1012)],"#9fc4cc")
   box(Rect2(x-12,1040,336,160),entry[1])
   box(Rect2(x+20,1100,65,26),"#e6deb9")
   box(Rect2(x+227,1100,65,26),"#e6deb9")
   box(Rect2(x+105,1130,102,17),"#394649")
   box(Rect2(x+25,1192,40,30),"#303b3e")
   box(Rect2(x+245,1192,40,30),"#303b3e")
  draw_set_transform(Vector2.ZERO)

func _ready()->void:
 layer=70
 overlay=Control.new()
 add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var art:=GateView.new()
 overlay.add_child(art)
 art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 dialogue=PanelContainer.new()
 overlay.add_child(dialogue)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("#12272af5")
 style.border_color=Color("#b1bd9c")
 style.set_border_width_all(2)
 style.set_corner_radius_all(12)
 dialogue.add_theme_stylebox_override("panel",style)
 var margin:=MarginContainer.new()
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,28)
 dialogue.add_child(margin)
 var column:=VBoxContainer.new()
 column.add_theme_constant_override("separation",18)
 margin.add_child(column)
 var speaker:=Label.new()
 speaker.text="科技技"
 speaker.add_theme_font_size_override("font_size",26)
 speaker.add_theme_color_override("font_color",Color("#e5ce96"))
 column.add_child(speaker)
 var words:=Label.new()
 words.text=MONOLOGUE
 words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 words.add_theme_font_size_override("font_size",34)
 column.add_child(words)
 continue_button=Button.new()
 continue_button.text="E / Enter · 继续"
 continue_button.focus_mode=Control.FOCUS_NONE
 continue_button.custom_minimum_size=Vector2(260,48)
 continue_button.size_flags_horizontal=Control.SIZE_SHRINK_END
 continue_button.add_theme_font_size_override("font_size",22)
 continue_button.pressed.connect(close)
 column.add_child(continue_button)
 get_viewport().size_changed.connect(_layout)
 overlay.hide()
 _layout()

func _layout()->void:
 var view:Vector2=get_viewport().get_visible_rect().size
 var factor:float=minf(view.x/2400.0,view.y/1400.0)
 dialogue.scale=Vector2.ONE*factor
 dialogue.size=Vector2(minf(2100,view.x/factor-120),260)
 dialogue.position=Vector2((view.x-dialogue.size.x*factor)*0.5,view.y-310*factor)

func open()->void:
 overlay.show()
 _layout()
 state_changed.emit()

func is_open()->bool:return overlay!=null and overlay.visible

func close()->void:
 if not is_open():return
 overlay.hide()
 state_changed.emit()

func _process(_delta:float)->void:
 if is_open():_layout()

func _input(event:InputEvent)->void:
 if not is_open():return
 if event is InputEventKey:
  if event.pressed and not event.echo:
   var key:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
   if key in [KEY_E,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:close()
  get_viewport().set_input_as_handled()
