extends ScrollContainer
## 精简 X 菜单：背包内使用补给，状态查看体力与精力。
const CATALOG = preload("res://scripts/supply_catalog.gd")
const ITEMS = CATALOG.ITEMS
const STARTER_INVENTORY = {"iced_tea":2,"snacks":3,"fenmian":2,"cup":1}
var cash: int = 30
var wallet_day: int = 1
var last_time_slot: int = 0
var controller: Node
var page := ""
var inventory: Dictionary = STARTER_INVENTORY.duplicate(true)
var stats: Dictionary = {"stamina":100.0,"energy":100.0}
var rows: VBoxContainer
var actions: Array[Button] = []
var cursor := 0
var feedback := ""
var refresh_timer := 0.0
var base_speed := 0.0
const SAVE = preload("res://scripts/campus_save.gd")
var storage_root := SAVE.DEFAULT_DIR
var pending := ""
var changing_scene := false

func _ready() -> void:
 size_flags_vertical = Control.SIZE_EXPAND_FILL
 horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 rows = VBoxContainer.new()
 rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 rows.add_theme_constant_override("separation",12)
 add_child(rows)
 hide()

func setup(owner_node: Node) -> void:
 controller=owner_node
 base_speed=controller.player.speed
 reset_time_anchor()
 controller.day_cycle.changed.connect(_on_time_changed)

func limits() -> Dictionary:
 return {"stamina":100.0,"energy":100.0}

func _process(delta: float) -> void:
 if controller==null:return
 controller.player.speed=base_speed*(0.7+0.3*float(stats.stamina)/100.0)
 if visible and page=="状态":
  refresh_timer+=delta
  if refresh_timer>1:
   refresh_timer=0
   render()

func show_page(next_page: String) -> void:
 if next_page not in ["背包","状态","存档","返回标题界面"]:return
 page=next_page
 pending=""
 feedback=""
 cursor=0
 scroll_vertical=0
 show()
 render()

func label_line(value: String, font_size: int=24) -> void:
 var item:=Label.new()
 item.text=value
 item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 item.add_theme_font_size_override("font_size",font_size)
 rows.add_child(item)

func action(caption: String, callback: Callable, enabled: bool=true) -> void:
 var button:=Button.new()
 button.text=caption
 button.custom_minimum_size.y=54
 button.add_theme_font_size_override("font_size",24)
 button.disabled=not enabled
 button.focus_mode=Control.FOCUS_NONE
 button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 button.pressed.connect(callback)
 rows.add_child(button)
 if enabled:actions.append(button)

func render() -> void:
 for child in rows.get_children():
  rows.remove_child(child)
  child.queue_free()
 actions.clear()
 label_line(page,32)
 if not feedback.is_empty():label_line(feedback,22)
 if page=="背包":
  label_line("选择食品或饮料即可使用；属性已满时不消耗。",22)
  label_line("今日零钱：%d / 30 元"%cash,24)
  for id in ITEMS:
   if int(inventory.get(id,0))<=0:continue
   var spec: Dictionary=ITEMS[id]
   var caption: String="%s × %d　·　%s" % [spec.name,int(inventory.get(id,0)),CATALOG.description(spec)]
   if spec.get("usable",true):
    action(caption,use_item.bind(id),int(inventory.get(id,0))>0)
   else:
    label_line(caption)
 elif page=="状态":
  label_line("%s　·　%s\n%s" % [controller.player.display_name,controller.place,controller.day_cycle.display_text()])
  label_line("体力  %d / 100\n精力  %d / 100" % [stats.stamina,stats.energy],30)
  label_line("每过一个时段，体力与精力各减少20。体力越低，移速越慢。午休和晚睡后精力回满；精力暂不影响行动。\n今日零钱：%d / 30 元（每天补至30元）"%cash,22)
 elif page=="存档":
  label_line("选择存档槽，保存或读取当前进度。",22)
  for slot in range(1,4):
   var data: Dictionary=SAVE.read_slot(slot,storage_root)
   label_line("存档 %d　%s" % [slot,SAVE.summary(data)],21)
   action(("确认覆盖存档 %d" if pending=="save%d"%slot else "保存到存档 %d")%slot,save_slot.bind(slot))
   action(("确认读取存档 %d" if pending=="load%d"%slot else "读取存档 %d")%slot,load_slot.bind(slot),not data.is_empty())
  if not pending.is_empty():action("取消",cancel_pending)
 elif page=="返回标题界面":
  label_line("未保存的进度将丢失。确认返回标题界面吗？",26)
  action("取消 · 继续游戏",cancel_return)
  action("确认返回标题界面",return_to_title)
 cursor=clampi(cursor,0,maxi(0,actions.size()-1))
 highlight()

func handle_key(code: int) -> void:
 if actions.is_empty():return
 if code in [KEY_UP,KEY_DOWN,KEY_TAB]:
  cursor=posmod(cursor+(-1 if code==KEY_UP else 1),actions.size())
  highlight()
  ensure_control_visible(actions[cursor])
 elif code in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
  actions[cursor].pressed.emit()

func highlight() -> void:
 for i in range(actions.size()):
  actions[i].modulate=Color("#ffe19b") if i==cursor else Color.WHITE

func use_item(id: String) -> bool:
 if not ITEMS.has(id) or int(inventory.get(id,0))<=0:return false
 var spec: Dictionary=ITEMS[id]
 if not spec.get("usable",true):return false
 if spec.get("kind","")=="noodles" and not controller.can_use_noodles_at_counter():
  feedback="方便面只能在宿舍301展开的桌板上吃。"
  render()
  return false
 var stamina_gain: float=float(spec.get("stamina",0))
 var energy_gain: float=float(spec.get("energy",0))
 if (stamina_gain<=0 or float(stats.stamina)>=100) and (energy_gain<=0 or float(stats.energy)>=100):
  feedback="属性已满，未消耗"+str(spec.name)
  render()
  return false
 stats.stamina=minf(100,float(stats.stamina)+stamina_gain)
 stats.energy=minf(100,float(stats.energy)+energy_gain)
 inventory[id]=int(inventory[id])-1
 if spec.get("kind","")=="noodles":
  controller.map.dorm_table_has_bowl=true
  controller.map.queue_redraw()
 feedback="已使用"+str(spec.name)
 render()
 return true

func cancel_pending() -> void:
 pending=""
 feedback="已取消"
 render()

func save_slot(slot: int) -> bool:
 if slot<1 or slot>3:return false
 if FileAccess.file_exists(SAVE.path(slot,storage_root)) and pending!="save%d"%slot:
  pending="save%d"%slot
  feedback="再次选择确认覆盖，或选择取消。"
  render()
  return false
 var result: Error=SAVE.write_slot(slot,SAVE.capture(controller,inventory,stats),storage_root)
 pending=""
 feedback="存档 %d 已保存"%slot if result==OK else "保存失败："+error_string(result)
 render()
 return result==OK

func load_slot(slot: int) -> bool:
 var data: Dictionary=SAVE.read_slot(slot,storage_root)
 if data.is_empty():
  feedback="存档不存在或已损坏，当前进度未改变。"
  render()
  return false
 if pending!="load%d"%slot:
  pending="load%d"%slot
  feedback="读取会替换当前未保存的进度，再次选择确认。"
  render()
  return false
 pending=""
 return restore_save(data)

func restore_save(data: Dictionary) -> bool:
 if not SAVE.valid(data):return false
 for id in ITEMS:inventory[id]=clampi(int(data.inventory.get(id,STARTER_INVENTORY.get(id,0))),0,999)
 for stat in stats:stats[stat]=clampf(float(data.stats.get(stat,100)),0,100)
 controller.day_cycle.day=clampi(int(data.day),1,99999)
 controller.day_cycle.period=clampi(int(data.period),0,3)
 var ctx: Dictionary=data.context
 for key in ["completed_meals","meal_slot","meal_taken","bed_visit_rest_used","dorm_wet_return_room"]:
  if typeof(ctx.get(key))==typeof(controller.get(key)):controller.set(key,ctx[key])
 controller.teaching_restroom_return_floor=clampi(int(ctx.get("teaching_restroom_return_floor",1)),1,5)
 for key in ["dorm_small_room_return","dorm_wet_return_position"]:
  controller.set(key,Vector2(float(ctx[key].x),float(ctx[key].y)))
 controller.map.dorm_small_room_is_laundry=bool(ctx.get("laundry",false))
 # 旧版曾扣到柜子里的实际物品退回背包；新版本仅保留放好行李的标记。
 var story_data: Dictionary=data.get("story",{})
 if not story_data.has("belongings_stored"):
  var legacy_items: Variant=story_data.get("stored_items",{})
  if legacy_items is Dictionary:
   for id in legacy_items:
    if ITEMS.has(id):inventory[id]=clampi(int(inventory.get(id,0))+maxi(0,int(legacy_items[id])),0,999)
 cash=clampi(int(data.get("supplies",{}).get("cash",30)),0,30)
 wallet_day=clampi(int(data.get("supplies",{}).get("wallet_day",data.day)),1,99999)
 controller.dorm_table_deployed=bool(data.get("supplies",{}).get("table_deployed",false))
 controller.night_music.restore(data.get("night_music",{}))
 reset_time_anchor()
 controller.story.restore(story_data)
 controller._load_place(str(data.place),Vector2(float(data.position.x),float(data.position.y)))
 var direction: String=str(data.get("facing","down"))
 controller.player.facing=direction if direction in ["up","down","left","right"] else "down"
 controller.day_cycle.changed.emit()
 controller.game_menu.close()
 return true

func cancel_return() -> void:
 controller.game_menu.close()

func return_to_title() -> void:
 if changing_scene:return
 changing_scene=true
 call_deferred("_change_to_title")

func _change_to_title() -> void:
 var result:=get_tree().change_scene_to_file("res://title.tscn")
 if result!=OK:
  changing_scene=false
  feedback="返回标题失败："+error_string(result)
  render()

func reset_time_anchor() -> void:
 last_time_slot=(controller.day_cycle.day-1)*4+controller.day_cycle.period

func _on_time_changed() -> void:
 var now: int=(controller.day_cycle.day-1)*4+controller.day_cycle.period
 var elapsed: int=maxi(0,now-last_time_slot)
 stats.stamina=maxf(0,float(stats.stamina)-20*elapsed)
 stats.energy=maxf(0,float(stats.energy)-20*elapsed)
 last_time_slot=now
 if wallet_day!=controller.day_cycle.day:
  wallet_day=controller.day_cycle.day
  cash=30

func buy_item(id: String) -> bool:
 if id not in CATALOG.SHOP_IDS or controller.place!="小卖部内部":return false
 var spec: Dictionary=ITEMS[id]
 if cash<int(spec.price):
  feedback="零钱不足，今天还剩%d元。"%cash
  return false
 if int(inventory.get(id,0))>=999:
  feedback="背包里的数量已满。"
  return false
 cash-=int(spec.price)
 inventory[id]=int(inventory.get(id,0))+1
 feedback="买到了%s，放入背包。"%spec.name
 return true
