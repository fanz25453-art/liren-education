extends Control
## 独立标题场景；进入游戏时才创建校园和角色。
const SAVE=preload("res://scripts/campus_save.gd")
const TITLE_PHOTO=preload("res://assets/title/title_photo.jpg")
var storage_root:=SAVE.DEFAULT_DIR
var panel: PanelContainer
var column: VBoxContainer
var buttons: Array[Button]=[]
var selected:=0
var page:="home"
var message:=""
var transitioning:=false

func _ready()->void:
 panel=PanelContainer.new()
 add_child(panel)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("#142b30ed")
 style.border_color=Color("#658b82")
 style.set_border_width_all(2)
 style.set_corner_radius_all(20)
 panel.add_theme_stylebox_override("panel",style)
 var margin:=MarginContainer.new()
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,40)
 panel.add_child(margin)
 column=VBoxContainer.new()
 column.add_theme_constant_override("separation",20)
 margin.add_child(column)
 resized.connect(_layout)
 render()
 _layout()

func _process(_delta:float)->void:
 # 自动换行首次测量可能暂时撑高容器，待子节点完成布局后收回设计尺寸。
 if panel.size!=Vector2(760,1010) and panel.get_combined_minimum_size().y<=1010:
  _layout()

func _layout()->void:
 var factor:=minf(size.x/2400.0,size.y/1400.0)
 panel.size=Vector2(760,1010)
 panel.scale=Vector2.ONE*factor
 panel.position=Vector2(size.x*0.09,(size.y-1010*factor)*0.5)
 queue_redraw()

func line(value:String,font_size:int,color:Color=Color("#eef3e8"))->void:
 var label:=Label.new()
 label.text=value
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",color)
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 column.add_child(label)

func button(caption:String,callback:Callable,enabled:bool=true)->void:
 var item:=Button.new()
 item.text=caption
 item.custom_minimum_size.y=78 if page=="home" else 60
 item.add_theme_font_size_override("font_size",28)
 item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 item.focus_mode=Control.FOCUS_NONE
 item.disabled=not enabled
 item.pressed.connect(callback)
 column.add_child(item)
 if enabled:
  var index:=buttons.size()
  item.mouse_entered.connect(select.bind(index))
  buttons.append(item)

func render()->void:
 for child in column.get_children():
  column.remove_child(child)
  child.queue_free()
 buttons.clear()
 column.add_theme_constant_override("separation",20 if page=="home" else 12)
 line("L I R E N   ·   C A M P U S",21,Color("#b6cbb7"))
 line("立仁校园",72 if page=="home" else 56)
 line("在熟悉的校园里，开始新的一天。",24,Color("#c4d5cb"))
 var spacer:=Control.new()
 spacer.custom_minimum_size.y=12
 column.add_child(spacer)
 if not message.is_empty():line(message,23,Color("#f0ce91"))
 if page=="home":
  button("开始新游戏",start_game)
  button("读取存档",show_load)
  button("退出游戏",quit_game)
 elif page=="load":
  line("读取存档",32)
  for slot in range(1,4):
   var data:Dictionary=SAVE.read_slot(slot,storage_root)
   line("存档 %d　%s" % [slot,SAVE.summary(data)],22)
   button("读取存档 %d"%slot,load_game.bind(slot),not data.is_empty())
  button("返回",show_home)
 var flexible:=Control.new()
 flexible.size_flags_vertical=Control.SIZE_EXPAND_FILL
 column.add_child(flexible)
 line("方向键选择  ·  Enter 确认  ·  鼠标点击",20,Color("#a8c0b5"))
 selected=clampi(selected,0,maxi(0,buttons.size()-1))
 highlight()

func select(index:int)->void:
 selected=index
 highlight()

func highlight()->void:
 for i in range(buttons.size()):
  var style:=StyleBoxFlat.new()
  style.bg_color=Color("#41665b") if i==selected else Color("#203f3e")
  style.border_color=Color("#e1c98f") if i==selected else Color("#55776b")
  style.set_border_width_all(3 if i==selected else 1)
  style.set_corner_radius_all(9)
  buttons[i].add_theme_stylebox_override("normal",style)
  buttons[i].add_theme_stylebox_override("hover",style)

func show_home()->void:
 page="home"
 selected=0
 message=""
 render()

func show_load()->void:
 page="load"
 selected=0
 message=""
 render()

func start_game()->void:
 if transitioning:return
 get_tree().set_meta("play_campus_intro",true)
 if get_tree().has_meta("pending_campus_save"):get_tree().remove_meta("pending_campus_save")
 transitioning=true
 call_deferred("_enter_game")

func load_game(slot:int)->void:
 if transitioning:return
 var data:Dictionary=SAVE.read_slot(slot,storage_root)
 if data.is_empty():
  message="存档无法读取，请选择其他存档。"
  render()
  return
 if get_tree().has_meta("play_campus_intro"):get_tree().remove_meta("play_campus_intro")
 get_tree().set_meta("pending_campus_save",data)
 transitioning=true
 call_deferred("_enter_game")

func _enter_game()->void:
 var result:=get_tree().change_scene_to_file("res://liren.tscn")
 if result!=OK:
  if get_tree().has_meta("play_campus_intro"):get_tree().remove_meta("play_campus_intro")
  if get_tree().has_meta("pending_campus_save"):get_tree().remove_meta("pending_campus_save")
  transitioning=false
  message="进入游戏失败："+error_string(result)
  render()

func quit_game()->void:
 get_tree().quit()

func _input(event:InputEvent)->void:
 if transitioning or not event is InputEventKey or not event.pressed:return
 var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
 if event.echo and code not in [KEY_UP,KEY_DOWN]:return
 if code in [KEY_UP,KEY_DOWN,KEY_TAB] and not buttons.is_empty():
  select(posmod(selected+(-1 if code==KEY_UP else 1),buttons.size()))
 elif code in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE] and not buttons.is_empty():
  buttons[selected].pressed.emit()
 elif code==KEY_ESCAPE and page=="load":show_home()
 else:return
 get_viewport().set_input_as_handled()

func _draw()->void:
 var scale_factor:=minf(size.x/2400.0,size.y/1400.0)
 draw_rect(Rect2(Vector2.ZERO,size),Color("#172d33"))
 draw_set_transform(Vector2(size.x-2400*scale_factor,size.y-1400*scale_factor)*0.5,0,Vector2.ONE*scale_factor)
 # 暮色天空与暖光；校园示意图使用原生绘制，适配不同窗口尺寸。
 for y in range(0,1400,14):
  var blend:=float(y)/1400
  draw_rect(Rect2(0,y,2400,14),Color("#21454c").lerp(Color("#8b9c7b"),blend))
 draw_circle(Vector2(2010,260),105,Color("#e8d9a5"))
 draw_circle(Vector2(2010,260),125,Color(0.9,0.85,0.65,0.08))
 draw_colored_polygon(PackedVector2Array([Vector2(900,650),Vector2(1220,410),Vector2(1530,650),Vector2(1780,460),Vector2(2400,710),Vector2(2400,1400),Vector2(900,1400)]),Color("#526f64"))
 draw_rect(Rect2(0,990,2400,410),Color("#3d6859"))
 draw_colored_polygon(PackedVector2Array([Vector2(800,1400),Vector2(1450,1010),Vector2(1970,1010),Vector2(2400,1400)]),Color("#a6aa94"))
 # 教学楼、走廊、窗户和台阶。
 draw_rect(Rect2(1112,580,1120,450),Color("#314c47"))
 draw_rect(Rect2(1090,550,1120,450),Color("#d3cfb1"))
 draw_rect(Rect2(1068,526,1164,30),Color("#536c60"))
 for floor in range(4):
  var y:=580+floor*105
  for col in range(10):
   var x:=1120+col*106
   draw_rect(Rect2(x,y,70,55),Color("#6b8277"))
   draw_rect(Rect2(x+5,y+5,60,45),Color("#e1d5a3") if (col+floor)%3==0 else Color("#a4c8c6"))
   draw_line(Vector2(x+35,y+6),Vector2(x+35,y+49),Color("#e4ead9"),3)
  draw_rect(Rect2(1090,y+68,1120,17),Color("#82917a"))
 draw_rect(Rect2(1510,932,240,68),Color("#435e55"))
 for i in range(5):draw_rect(Rect2(1460-i*12,1000+i*12,340+i*24,10),Color("#c3c1a5"))
 # 前景绿植。
 for x in [1050,1240,2180,2340]:
  draw_rect(Rect2(x,935,14,165),Color("#51604c"))
  draw_circle(Vector2(x+7,900),66,Color("#376751"))
  draw_circle(Vector2(x-14,869),48,Color("#4d7b58"))
 # 右下角照片按原始比例缩放，完整放入指定区域。
 var photo_area:=Rect2(1665,1065,675,270)
 var photo_size:Vector2=TITLE_PHOTO.get_size()
 var photo_scale:float=minf(photo_area.size.x/photo_size.x,photo_area.size.y/photo_size.y)
 var fitted_size:Vector2=photo_size*photo_scale
 var photo_rect:=Rect2(photo_area.position+(photo_area.size-fitted_size)*0.5,fitted_size)
 draw_texture_rect(TITLE_PHOTO,photo_rect,false)
 draw_set_transform(Vector2.ZERO)
