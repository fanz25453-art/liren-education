extends CanvasLayer
## 宿舍第一人称射门：鼠标瞄准、按住蓄力、松开踢球。
signal state_changed
const BEDROOM = preload("res://assets/tilesets/rasak/bedroom.png")
const CABINET_PALETTE = preload("res://scripts/cabinet_palette.gd")
const SHOTS := 5
# 目标是床窄端与向过道倾斜的梯子之间的三角空隙。
const GOALS := [Rect2(444,418,36,54),Rect2(800,418,36,54)]
const GOAL_OPENINGS := [
 [Vector2(432,275),Vector2(496,480),Vector2(432,480)],
 [Vector2(848,275),Vector2(848,480),Vector2(784,480)]
]
var overlay:Control
var canvas:Control
var restart_button:Button
var score:int=0
var shots:int=0
var phase:String="ready"
var aim:=Vector2(640,415)
var power:float=0.0
var charge_time:float=0.0
var elapsed:float=0.0
var shot_duration:float=0.8
var impact:=Vector2.ZERO
var shot_aim:=Vector2.ZERO
var scored:bool=false
var hit_frame:bool=false
var feedback:String=""
var ball_spin:float=0.0

class Pitch extends Control:
 var game:CanvasLayer
 func _draw():game.draw_pitch(self)

func _ready():
 layer=57
 overlay=Control.new()
 add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var black:=ColorRect.new()
 black.color=Color("#121b20")
 overlay.add_child(black)
 black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 canvas=Pitch.new()
 canvas.game=self
 canvas.size=Vector2(1280,800)
 canvas.clip_contents=true
 overlay.add_child(canvas)
 var back:=Button.new()
 back.text="返回宿舍  Esc"
 back.position=Vector2(1050,24)
 back.size=Vector2(200,48)
 back.focus_mode=Control.FOCUS_NONE
 back.add_theme_font_size_override("font_size",22)
 back.pressed.connect(close)
 canvas.add_child(back)
 restart_button=Button.new()
 restart_button.text="再踢一轮"
 restart_button.position=Vector2(520,535)
 restart_button.size=Vector2(240,64)
 restart_button.focus_mode=Control.FOCUS_NONE
 restart_button.add_theme_font_size_override("font_size",26)
 restart_button.pressed.connect(restart)
 canvas.add_child(restart_button)
 get_viewport().size_changed.connect(_layout)
 _layout()
 overlay.hide()
 set_process(false)
func _layout():
 var view:Vector2=get_viewport().get_visible_rect().size
 var factor:float=minf(view.x/1280.0,view.y/800.0)
 canvas.scale=Vector2.ONE*factor
 canvas.position=(view-Vector2(1280,800)*factor)*0.5
func is_open()->bool:return overlay!=null and overlay.visible
func open():
 restart()
 _layout()
 overlay.show()
 set_process(true)
 state_changed.emit()
func close():
 phase="ready"
 overlay.hide()
 set_process(false)
 state_changed.emit()
func restart():
 score=0
 shots=0
 phase="ready"
 power=0.0
 charge_time=0.0
 elapsed=0.0
 feedback="从门口射向床端：瞄准床与梯子之间的空隙"
 aim=Vector2(640,415)
 restart_button.hide()
 canvas.queue_redraw()
func _input(event:InputEvent):
 if not is_open():return
 if event is InputEventKey:
  if event.pressed and not event.echo:
   var code:int=event.physical_keycode if event.physical_keycode else event.keycode
   if code==KEY_ESCAPE:close()
   elif code==KEY_R and phase=="results":restart()
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and phase in ["ready","charging"]:
  _aim_at((event.position-canvas.position)/canvas.scale)
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  var local:Vector2=(event.position-canvas.position)/canvas.scale
  if event.pressed and phase=="ready" and Rect2(0,100,1280,640).has_point(local):
   _aim_at(local)
   phase="charging"
   charge_time=0.0
   power=0.0
   get_viewport().set_input_as_handled()
  elif not event.pressed and phase=="charging":
   _shoot()
   get_viewport().set_input_as_handled()
func _aim_at(point:Vector2):
 aim=Vector2(clampf(point.x,80,1200),clampf(point.y,300,520))
 canvas.queue_redraw()
func _shoot():
 if phase!="charging":return
 shots+=1
 shot_aim=aim
 # 中等力度贴地穿过空隙，过轻停在床前，过重抬高撞床架。
 impact=shot_aim+Vector2(0,(0.60-power)*150.0)
 if power<0.18:impact=Vector2(lerpf(640,aim.x,power/0.18),lerpf(650,aim.y,power/0.18))
 scored=false
 scored=_is_goal(impact)
 hit_frame=not scored and _hits_bed_frame(impact)
 shot_duration=lerpf(1.05,0.60,power)
 phase="flight"
 elapsed=0.0
 feedback=""
 canvas.queue_redraw()
func _process(delta:float):
 if phase=="charging":
  charge_time+=delta
  power=minf(charge_time/1.25,1.0)
  canvas.queue_redraw()
 elif phase=="flight":
  elapsed+=delta
  ball_spin+=delta*12.0
  if elapsed>=shot_duration:
   phase="feedback"
   elapsed=0.0
   if scored:
    score+=1
    feedback="进球！  +1"
   elif power<0.18:feedback="力气太小，球停在床前了"
   elif hit_frame:feedback="碰到床架或梯子了，再压低一点试试" if impact.y<418 else "撞到边缘了，瞄准空隙中央"
   else:feedback="偏出空隙了，调整方向再来"
  canvas.queue_redraw()
 elif phase=="feedback":
  elapsed+=delta
  if elapsed>1.15:
   if shots>=SHOTS:
    phase="results"
    restart_button.show()
   else:
    phase="ready"
    power=0.0
  canvas.queue_redraw()
func _text(c:Control,pos:Vector2,value:String,size:int=24,color:Color=Color("#f5f0dc")):
 c.draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func _poly(c:Control,points:Array,color:Color):
 c.draw_colored_polygon(PackedVector2Array(points),color)
func _is_goal(point:Vector2)->bool:
 # 整个足球必须能穿过三角空隙，不能擦着梯子或床柱算进球。
 for opening in GOAL_OPENINGS:
  var polygon:=PackedVector2Array(opening)
  if not Geometry2D.is_point_in_polygon(point,polygon):continue
  var clear:bool=true
  for i in range(polygon.size()):
   if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()]))<11.0:
    clear=false
    break
  if clear:return true
 return false
func _hits_bed_frame(point:Vector2)->bool:
 if point.x<144 and point.y>300:return true
 if Rect2(962.5,381.25,250,318.75).grow(11).has_point(point):return true
 if point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(960,443.75),Vector2(880,700)))<21:return true
 for left in [true,false]:
  var x:float=230 if left else 850
  if Rect2(x,225,200,255).grow(11).has_point(point):return true
  var top:=Vector2(432,275) if left else Vector2(848,275)
  var foot:=Vector2(496,480) if left else Vector2(784,480)
  if point.distance_to(Geometry2D.get_closest_point_to_segment(point,top,foot))<19:return true
 return false
func _mattress_top(c:Control,corners:Array):
 # 原版单人床保持竖向，枕头朝远处，床尾朝门口；通过四角投影表现纵深。
 var uv:=PackedVector2Array([Vector2(240,48),Vector2(288,48),Vector2(288,192),Vector2(240,192)])
 for i in range(uv.size()):uv[i]/=BEDROOM.get_size()
 c.draw_polygon(PackedVector2Array(corners),PackedColorArray([Color(1.25,1.55,1.75)]),uv,BEDROOM)
func _bed(c:Control,left:bool,goal_enabled:bool=true):
 # 先画左床，右床镜像几何；床头在远处，面对玩家的是短床尾。
 var front_left:float=230 if left else 850
 var front_right:float=430 if left else 1050
 var back_left:float=320 if left else 830
 var back_right:float=450 if left else 960
 var inner:float=432 if left else 848
 var foot_x:float=496 if left else 784
 _poly(c,[Vector2(front_left,480),Vector2(front_right,480),Vector2(back_right,400),Vector2(back_left,400)],Color(0.15,0.16,0.14,0.2))
 # 后床柱和沿床长度延伸的侧梁。
 for x in [back_left,back_right]:
  c.draw_rect(Rect2(x-4,160,8,245),Color("#967039"))
 _poly(c,[Vector2(front_left,283),Vector2(back_left,238),Vector2(back_left,250),Vector2(front_left,295)],Color("#9b7135"))
 _poly(c,[Vector2(front_right,283),Vector2(back_right,238),Vector2(back_right,250),Vector2(front_right,295)],Color("#9b7135"))
 _poly(c,[Vector2(front_left,420),Vector2(back_left,355),Vector2(back_left,367),Vector2(front_left,432)],Color("#9b7135"))
 _poly(c,[Vector2(front_right,420),Vector2(back_right,355),Vector2(back_right,367),Vector2(front_right,432)],Color("#9b7135"))
 # 上铺顶部木板与两层淡蓝床垫都沿纵深摆放，不再横向旋转素材。
 _poly(c,[Vector2(back_left-5,155),Vector2(back_right+5,155),Vector2(front_right,225),Vector2(front_left,225)],Color("#c18a3b"))
 for i in range(1,7):
  var ratio:float=i/7.0
  c.draw_line(Vector2(lerpf(back_left,back_right,ratio),158),Vector2(lerpf(front_left,front_right,ratio),222),Color("#d9a558"),1.5)
 _mattress_top(c,[Vector2(back_left+6,238),Vector2(back_right-6,238),Vector2(front_right-9,275),Vector2(front_left+9,275)])
 c.draw_rect(Rect2(front_left+8,275,184,15),Color("#91b9ca"))
 c.draw_rect(Rect2(front_left,291,200,12),Color("#b0803c"))
 _mattress_top(c,[Vector2(back_left+6,355),Vector2(back_right-6,355),Vector2(front_right-9,419),Vector2(front_left+9,419)])
 c.draw_rect(Rect2(front_left+8,419,184,13),Color("#91b9ca"))
 c.draw_rect(Rect2(front_left,432,200,12),Color("#b0803c"))
 # 床尾下方透出地面，支柱是实际障碍，目标空隙在床尾旁边。
 c.draw_rect(Rect2(front_left+9,444,182,36),Color("#666d62"))
 for x in [front_left,front_right-8]:
  c.draw_rect(Rect2(x,225,8,255),Color("#a67839"))
  c.draw_line(Vector2(x+2,228),Vector2(x+2,478),Color("#ddb366"),2)
 c.draw_rect(Rect2(front_left,225,200,10),Color("#b7833d"))
 # 正对短床端时，侧边梯子向过道伸出，床柱与梯子之间形成三角门。
 if goal_enabled:
  var opening:=PackedVector2Array(GOAL_OPENINGS[0 if left else 1])
  c.draw_colored_polygon(opening,Color(0.25,0.31,0.27,0.16))
 for shift in [-5.0,7.0]:
  c.draw_line(Vector2(inner+shift,275),Vector2(foot_x+shift,480),Color("#a5793d"),5)
 for y in range(295,478,26):
  var t:float=(y-275.0)/205.0
  var x:float=lerpf(inner,foot_x,t)
  c.draw_line(Vector2(x-7,y),Vector2(x+11,y),Color("#e0b66d"),5)
 if goal_enabled:
  # 仅在靠地面的入口标记，不把整块床底误画成球门。
  var marker_y:float=477
  var min_x:float=minf(inner,foot_x)+13
  var max_x:float=maxf(inner,foot_x)-13
  for offset in range(0,int(max_x-min_x),14):
   c.draw_line(Vector2(min_x+offset,marker_y),Vector2(minf(min_x+offset+7,max_x),marker_y),Color("#d3e6c3"),2)
  _text(c,Vector2(285 if left else 825,514),"左床端空隙" if left else "右床端空隙",20,Color("#44594f"))
func _wash_area(c:Control):
 # 视线沿中间开口进入卫生区：设施沿左右侧墙延伸，不排在后墙上。
 c.draw_rect(Rect2(520,180,240,260),Color("#d3dfd8"))
 _poly(c,[Vector2(520,430),Vector2(600,350),Vector2(680,350),Vector2(760,430)],Color("#acbfba"))
 _poly(c,[Vector2(520,210),Vector2(600,240),Vector2(600,350),Vector2(520,430)],Color("#c2d3cc"))
 _poly(c,[Vector2(680,240),Vector2(760,210),Vector2(760,430),Vector2(680,350)],Color("#ceddd4"))
 for x in [540,580,620,660,700,740]:
  c.draw_line(Vector2(640+(x-640)*0.32,350),Vector2(x,430),Color("#91aaa2"),1)
 for y in [369,392,420]:c.draw_line(Vector2(520,y),Vector2(760,y),Color("#9fb6ad"),1)
 c.draw_rect(Rect2(602,205,76,49),Color("#93aca3"))
 c.draw_rect(Rect2(607,210,66,39),Color("#e0ece5"))
 c.draw_line(Vector2(640,210),Vector2(640,249),Color("#f5f5e8"),3)
 # 左侧淋浴与厕所都是关闭的侧门，仅显示门面。
 for corners in [
  [Vector2(527,260),Vector2(558,272),Vector2(558,392),Vector2(527,419)],
  [Vector2(566,278),Vector2(594,289),Vector2(594,354),Vector2(566,384)]
 ]:
  _poly(c,corners,Color("#819d90"))
  var inset:Array=[]
  var center:=Vector2.ZERO
  for point in corners:center+=point
  center/=4.0
  for point in corners:inset.append(point.lerp(center,0.14))
  _poly(c,inset,Color("#e1e8d9"))
 _poly(c,[Vector2(533,278),Vector2(551,285),Vector2(551,309),Vector2(533,305)],Color("#b7d2c9"))
 _poly(c,[Vector2(572,291),Vector2(588,298),Vector2(588,315),Vector2(572,311)],Color("#b7d2c9"))
 c.draw_circle(Vector2(550,348),2,Color("#708376"))
 c.draw_circle(Vector2(587,339),1.6,Color("#708376"))
 # 右侧两面镜子及洗漱盆，沿侧墙向里排列。
 for shift in [0,33]:
  var x:float=692+shift
  var y:float=285-shift*0.37
  _poly(c,[Vector2(x,y),Vector2(x+24,y-9),Vector2(x+24,y+35),Vector2(x,y+39)],Color("#879f98"))
  _poly(c,[Vector2(x+3,y+3),Vector2(x+21,y-3),Vector2(x+21,y+31),Vector2(x+3,y+35)],Color("#d5e8e4"))
  c.draw_line(Vector2(x+5,y+27),Vector2(x+19,y+10),Color("#f5f8ee"),1.5)
  var basin_y:float=342+shift*0.7
  _poly(c,[Vector2(x-7,basin_y),Vector2(x+24,basin_y-9),Vector2(x+24,basin_y+4),Vector2(x-7,basin_y+15)],Color("#f0f3e9"))
  _poly(c,[Vector2(x-2,basin_y+1),Vector2(x+19,basin_y-5),Vector2(x+19,basin_y+1),Vector2(x-2,basin_y+8)],Color("#a6c7c7"))
  c.draw_line(Vector2(x+12,basin_y-4),Vector2(x+12,basin_y-13),Color("#6f8b84"),3)
  c.draw_line(Vector2(x+12,basin_y-13),Vector2(x+7,basin_y-11),Color("#6f8b84"),3)
  c.draw_line(Vector2(x+6,basin_y+14),Vector2(x+6,basin_y+33),Color("#95ada1"),5)
 # 洗衣池在右侧最靠近开口的位置，只露出池沿。
 _poly(c,[Vector2(734,395),Vector2(758,386),Vector2(758,416),Vector2(734,425)],Color("#91ada3"))
 _poly(c,[Vector2(737,396),Vector2(755,390),Vector2(755,404),Vector2(737,411)],Color("#e2eeea"))
 # 两侧厚隔墙挡住卫生区的大部分，只从中央开口看见局部。
 c.draw_rect(Rect2(0,170,500,260),Color("#e5e2cf"))
 c.draw_rect(Rect2(780,170,500,260),Color("#e5e2cf"))
 _poly(c,[Vector2(500,170),Vector2(520,187),Vector2(520,440),Vector2(500,430)],Color("#c8cbb9"))
 _poly(c,[Vector2(760,187),Vector2(780,170),Vector2(780,430),Vector2(760,440)],Color("#b9c2af"))
 c.draw_line(Vector2(500,430),Vector2(0,430),Color("#b5bbaa"),6)
 c.draw_line(Vector2(780,430),Vector2(1280,430),Color("#b5bbaa"),6)
func _near_cabinet(c:Control):
 # 柜体侧面收薄，仍使用原版米黄色侧板。
 c.draw_set_transform(Vector2.ZERO,0,Vector2(0.60,1.0))
 var texture:Texture2D=CABINET_PALETTE.texture()
 var uv:=PackedVector2Array([Vector2(672,384),Vector2(696,384),Vector2(696,608),Vector2(672,608)])
 for i in range(uv.size()):uv[i]/=texture.get_size()
 var side:=PackedVector2Array([Vector2(-25,245),Vector2(130,250),Vector2(195,710),Vector2(-25,710)])
 var depth:=PackedVector2Array([Vector2(130,250),Vector2(190,282),Vector2(240,660),Vector2(195,710)])
 c.draw_polygon(depth,PackedColorArray([Color(0.86,0.88,0.84)]),uv,texture)
 c.draw_polygon(side,PackedColorArray([Color.WHITE]),uv,texture)
 _poly(c,[Vector2(-25,245),Vector2(130,250),Vector2(190,282),Vector2(20,279)],Color("#ddd0ab"))
 for y in [400,553]:
  var edge_x:float=lerpf(130,195,(y-250.0)/460.0)
  c.draw_line(Vector2(-25,y),Vector2(edge_x,y),Color("#9e9475"),3)
  c.draw_line(Vector2(-25,y+3),Vector2(edge_x,y+3),Color("#e4d8b4"),2)
 c.draw_line(Vector2(195,710),Vector2(240,660),Color("#8e896e"),4)
 c.draw_set_transform(Vector2.ZERO)
func _near_bed(c:Control):
 # 直接复用右侧远床，近处仅作统一透视放大；不绘制球门标记。
 c.draw_set_transform(Vector2(-100,100),0,Vector2(1.25,1.25))
 _bed(c,false,false)
 c.draw_set_transform(Vector2.ZERO)
func _ball(c:Control,position:Vector2,radius:float,rotation:float,alpha:float=1.0):
 c.draw_circle(position+Vector2(3,radius*0.75),radius*0.85,Color(0,0,0,0.16*alpha))
 c.draw_circle(position,radius,Color(0.94,0.95,0.90,alpha))
 var points:=PackedVector2Array()
 for i in range(5):points.append(position+Vector2.from_angle(rotation+i*TAU/5.0)*radius*0.36)
 c.draw_colored_polygon(points,Color(0.15,0.22,0.24,alpha))
 for i in range(5):
  var direction:=Vector2.from_angle(rotation+i*TAU/5.0)
  c.draw_line(position+direction*radius*0.38,position+direction*radius*0.91,Color(0.3,0.35,0.35,alpha),maxf(1,radius*0.035))
 c.draw_arc(position,radius,0,TAU,32,Color(0.6,0.65,0.61,alpha),1.2)
func draw_pitch(c:Control):
 c.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 c.draw_rect(Rect2(0,0,1280,800),Color("#dcd7bf"))
 c.draw_rect(Rect2(0,100,1280,350),Color("#e9e5d3"))
 c.draw_rect(Rect2(0,450,1280,350),Color("#b9b9aa"))
 for x in range(-1280,2561,160):c.draw_line(Vector2(640+(x-640)*0.3,450),Vector2(x,800),Color("#a4a699"),1)
 for y in [480,530,600,700]:c.draw_line(Vector2(0,y),Vector2(1280,y),Color("#a4a699"),1)
 _wash_area(c)
 _bed(c,true)
 _bed(c,false)
 _near_bed(c)
 _near_cabinet(c)
 var start:=Vector2(640,690)
 if phase in ["ready","charging"]:
  c.draw_line(start,aim,Color(0.98,0.98,0.85,0.22),2)
  c.draw_arc(aim,15,0,TAU,28,Color("#e9f2d8"),2)
  c.draw_line(aim-Vector2(22,0),aim+Vector2(22,0),Color("#53786f"),2)
  c.draw_line(aim-Vector2(0,22),aim+Vector2(0,22),Color("#53786f"),2)
  _ball(c,start,35,0)
  if phase=="charging":
   var foot:=Vector2(735+power*32,742+power*15)
   c.draw_rect(Rect2(foot,Vector2(45,80)),Color("#3a515c"))
   c.draw_circle(foot+Vector2(10,2),25,Color("#e6e4d5"))
 elif phase=="flight":
  var t:float=clampf(elapsed/shot_duration,0,1)
  var ground:Vector2=start.lerp(impact,t)
  var lift:float=sin(t*PI)*power*80.0
  c.draw_circle(ground+Vector2(0,8),lerpf(25,9,t),Color(0.05,0.07,0.07,0.15))
  _ball(c,ground-Vector2(0,lift),lerpf(35,11,t),ball_spin)
  if t<0.22:
   var foot:Vector2=Vector2(735,790).lerp(Vector2(650,700),t/0.22)
   c.draw_rect(Rect2(foot,Vector2(42,100)),Color("#3a515c"))
   c.draw_circle(foot,25,Color("#e6e4d5"))
 elif phase=="feedback":
  var t:float=clampf(elapsed/1.15,0,1)
  if scored:_ball(c,impact-Vector2(0,t*10),lerpf(11,4,t),ball_spin,1-t)
  elif hit_frame:
   var bounce:Vector2=impact.lerp(Vector2(lerpf(impact.x,640,0.35),590),t)
   _ball(c,bounce-Vector2(0,sin(t*PI)*35),lerpf(11,23,t),ball_spin+t*8)
  else:_ball(c,impact+Vector2(0,t*18),11,ball_spin)
 c.draw_rect(Rect2(0,0,1280,100),Color("#243e43"))
 _text(c,Vector2(30,38),"wqy 的宿舍射门挑战",28)
 _text(c,Vector2(30,77),"进球 %d  /  射门 %d/%d" % [score,shots,SHOTS],24)
 c.draw_rect(Rect2(0,740,1280,60),Color("#243e43"))
 _text(c,Vector2(24,778),"鼠标瞄准 · 按住左键蓄力 · 松开踢球",23)
 c.draw_rect(Rect2(690,758,320,18),Color("#142a30"))
 c.draw_rect(Rect2(690+320*0.45,758,320*0.3,18),Color("#547d69"))
 c.draw_rect(Rect2(690,758,320*power,18),Color("#e6cd7b"))
 _text(c,Vector2(1025,777),"力度 %d%%" % int(power*100),21)
 if not feedback.is_empty() and phase!="results":
  c.draw_rect(Rect2(300,105,680,48),Color(0.14,0.23,0.25,0.9))
  _text(c,Vector2(320,138),feedback,23,Color("#e8f0cc") if scored else Color("#f4ecd5"))
 if phase=="results":
  c.draw_rect(Rect2(0,100,1280,640),Color(0.04,0.08,0.10,0.75))
  _text(c,Vector2(485,335),"挑战结束",44)
  _text(c,Vector2(490,410),"5 次射门，进球 %d 个" % score,30)
  _text(c,Vector2(400,470),"wqy：好球！" if score>=3 else "wqy：再来一轮，找准空隙就行！",27)
  _text(c,Vector2(490,640),"R 重试 · Esc 返回宿舍",23)




