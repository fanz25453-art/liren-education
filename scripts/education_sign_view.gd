extends CanvasLayer
signal view_state_changed
var overlay:Control
var frame:Control
var night:bool=false

class SignFace extends Control:
 var view:CanvasLayer
 var lettering:Font
 func _init():
  var calligraphy:=SystemFont.new()
  calligraphy.font_names=PackedStringArray(["STXingkai","华文行楷","KaiTi"])
  lettering=calligraphy
 func _draw():
  var dark:bool=view.night
  var font:Font=ThemeDB.fallback_font
  var background:=StyleBoxFlat.new()
  background.bg_color=Color("#101b23") if dark else Color("#ede9da")
  background.set_corner_radius_all(16)
  draw_style_box(background,Rect2(0,0,1100,650))
  draw_string(font,Vector2(42,58),"立仁教育 · 正面查看",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("#e9e5d5") if dark else Color("#4f5a53"))
  draw_rect(Rect2(65,180,970,300),Color("#24303a") if dark else Color("#d8d7c7"))
  for y in [240,320,400]:draw_line(Vector2(65,y),Vector2(1035,y),Color(0.5,0.55,0.5,0.09),1)
  draw_rect(Rect2(65,480,970,22),Color("#303e44") if dark else Color("#a5aca2"))
  var centers:Array[float]=[165,355,745,935]
  for i in range(4):
   var letter:String="立仁教育"[i]
   var width:float=lettering.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,150).x
   var at:=Vector2(centers[i]-width*0.5,390)
   if dark:
    for glow in [Vector2(40,0.025),Vector2(28,0.04),Vector2(18,0.09),Vector2(9,0.18)]:
     draw_string_outline(lettering,at,letter,HORIZONTAL_ALIGNMENT_LEFT,-1,150,int(glow.x),Color(1.0,0.12,0.08,glow.y))
   # 叠出红字的侧面厚度，正面保留书法笔画。
   for depth in range(7,0,-1):
    draw_string(lettering,at+Vector2(depth,depth),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,150,Color("#6d242b"))
   draw_string_outline(lettering,at,letter,HORIZONTAL_ALIGNMENT_LEFT,-1,150,1,Color("#ff8e7e") if dark else Color("#9c263e"))
   draw_string(lettering,at,letter,HORIZONTAL_ALIGNMENT_LEFT,-1,150,Color("#ff594c") if dark else Color("#b6223d"))
  _draw_badge(font,dark)
  draw_string(font,Vector2(405,598),"E / Esc 返回校园",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("#d3d9ce") if dark else Color("#59685e"))

 func _draw_badge(font:Font,dark:bool):
  var center:=Vector2(550,329)
  var red:=Color("#d83d53") if dark else Color("#aa2546")
  var cream:=Color("#ffd9d2") if dark else Color("#efd7cf")
  draw_circle(center+Vector2(5,7),78,Color(0.12,0.08,0.08,0.28))
  if dark:
   for radius in range(100,78,-3):
    draw_circle(center,radius,Color(1,0.08,0.08,0.015))
  draw_circle(center,78,red)
  draw_arc(center,74,0,TAU,96,cream,2,true)
  draw_arc(center,51,0,TAU,96,cream,2,true)
  var title:="LIRENJIAOYU"
  for i in range(title.length()):
   var angle:float=deg_to_rad(-165.0+i*150.0/(title.length()-1))
   var pos:Vector2=center+Vector2(cos(angle),sin(angle))*62
   draw_set_transform(pos,angle+PI/2)
   draw_string(font,Vector2(-5,6),title[i],HORIZONTAL_ALIGNMENT_LEFT,-1,14,cream)
  draw_set_transform(Vector2.ZERO)
  draw_string(font,center+Vector2(-40,18),"立仁",HORIZONTAL_ALIGNMENT_LEFT,-1,39,cream)
  draw_line(center+Vector2(-43,-28),center+Vector2(43,-28),cream,2,true)
  draw_line(center+Vector2(-43,28),center+Vector2(43,28),cream,2,true)
  draw_string(font,center+Vector2(-23,64),"2021",HORIZONTAL_ALIGNMENT_LEFT,-1,17,cream)

func _ready():
 layer=58
 overlay=Control.new()
 add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var dim:=ColorRect.new()
 dim.color=Color(0.015,0.025,0.03,0.85)
 overlay.add_child(dim)
 dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 frame=SignFace.new()
 frame.view=self
 frame.size=Vector2(1100,650)
 overlay.add_child(frame)
 var back:=Button.new()
 back.text="返回"
 back.position=Vector2(935,22)
 back.size=Vector2(120,48)
 back.focus_mode=Control.FOCUS_NONE
 back.add_theme_font_size_override("font_size",24)
 back.pressed.connect(close)
 frame.add_child(back)
 get_viewport().size_changed.connect(_layout)
 _layout()
 overlay.hide()
func _layout():
 var viewport_size:Vector2=get_viewport().get_visible_rect().size
 var factor:float=maxf(0.1,minf(1.0,minf((viewport_size.x-80)/1100.0,(viewport_size.y-80)/650.0)))
 frame.scale=Vector2.ONE*factor
 frame.position=(viewport_size-frame.size*factor)*0.5
func is_open()->bool:return overlay!=null and overlay.visible
func open(at_night:bool=false):
 night=at_night
 frame.queue_redraw()
 _layout()
 overlay.show()
 view_state_changed.emit()
func close():
 overlay.hide()
 view_state_changed.emit()
func _input(event:InputEvent):
 if not is_open() or not event is InputEventKey:return
 var code:int=event.physical_keycode if event.physical_keycode else event.keycode
 if event.pressed and not event.echo and code in [KEY_E,KEY_ESCAPE]:close()
 get_viewport().set_input_as_handled()
