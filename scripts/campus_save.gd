extends RefCounted
## 标题页与游戏菜单共用的本地存档格式。
const NIGHT_MUSIC = preload("res://scripts/night_music.gd")
const STORY = preload("res://scripts/campus_story.gd")
const DEFAULT_DIR := "user://campus_saves"
const PLACES := ["校园 G0","教学楼前平台","休息区","教学楼 F2","教学楼 F3","教学楼 F4","教学楼 F5","教学楼男厕","二层第一教室","一楼办公室","教学楼一楼内走廊","食堂内部","二号空房间","会议室内部","小食堂内部","小卖部内部","白房内部","宿舍一楼小房间","男生宿舍内部","男生宿舍 F2","男生宿舍 F3","宿舍尽头房间一","宿舍尽头房间二","宿舍洗澡间","宿舍厕所"]

static func path(slot: int, directory: String=DEFAULT_DIR) -> String:
 return directory+"/slot_%d.json"%slot

static func number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func valid(data: Variant) -> bool:
 if not data is Dictionary:return false
 if not number(data.get("version")) or int(data.version) not in [1,2,3]:return false
 if data.has("night_music") and not NIGHT_MUSIC.valid(data.night_music):return false
 if data.has("supplies"):
  if not data.supplies is Dictionary:return false
  for key in ["cash","wallet_day"]:
   if not number(data.supplies.get(key)):return false
  if not data.supplies.get("table_deployed") is bool:return false
 if data.has("story"):
  if not data.story is Dictionary:return false
  if str(data.story.get("node_id","")) not in STORY.NODES:return false
  if data.story.has("belongings_stored") and not data.story.belongings_stored is bool:return false
  if not data.story.get("stored_items",{}) is Dictionary:return false
  for value in data.story.get("stored_items",{}).values():
   if not number(value):return false
 if not data.get("place") in PLACES:return false
 for key in ["position","stats","inventory","context"]:
  if not data.get(key) is Dictionary:return false
 var pos: Dictionary=data.position
 if not number(pos.get("x")) or not number(pos.get("y")):return false
 if absf(float(pos.x))>20000 or absf(float(pos.y))>20000:return false
 for key in ["day","period"]:
  if not number(data.get(key)):return false
 for section in ["stats","inventory"]:
  for value in data[section].values():
   if not number(value):return false
 var ctx: Dictionary=data.context
 for key in ["dorm_small_room_return","dorm_wet_return_position"]:
  var vector=ctx.get(key)
  if not vector is Dictionary or not number(vector.get("x")) or not number(vector.get("y")):return false
 if not ctx.get("completed_meals") is Dictionary:return false
 if not number(ctx.get("teaching_restroom_return_floor")):return false
 if not ctx.get("dorm_wet_return_room","") in ["宿舍尽头房间一","宿舍尽头房间二"]:return false
 return true

static func read_slot(slot: int, directory: String=DEFAULT_DIR) -> Dictionary:
 if slot<1 or slot>3:return {}
 var file:=FileAccess.open(path(slot,directory),FileAccess.READ)
 if file==null:return {}
 var parser:=JSON.new()
 if parser.parse(file.get_as_text())!=OK:return {}
 return parser.data if valid(parser.data) else {}

static func write_slot(slot: int, data: Dictionary, directory: String=DEFAULT_DIR) -> Error:
 if slot<1 or slot>3 or not valid(data):return ERR_INVALID_DATA
 var result:=DirAccess.make_dir_recursive_absolute(directory)
 if result!=OK:return result
 var target:=path(slot,directory)
 var file:=FileAccess.open(target+".tmp",FileAccess.WRITE)
 if file==null:return FileAccess.get_open_error()
 file.store_string(JSON.stringify(data,"  "))
 file.flush()
 result=file.get_error()
 file.close()
 if result!=OK:return result
 return DirAccess.rename_absolute(target+".tmp",target)

static func capture(controller: Node, inventory: Dictionary, stats: Dictionary) -> Dictionary:
 var pos: Vector2=controller.map.to_local(controller.player.global_position)
 var context: Dictionary={}
 for key in ["completed_meals","meal_slot","meal_taken","bed_visit_rest_used","teaching_restroom_return_floor","dorm_wet_return_room"]:context[key]=controller.get(key)
 for key in ["dorm_small_room_return","dorm_wet_return_position"]:
  var vector: Vector2=controller.get(key)
  context[key]={"x":vector.x,"y":vector.y}
 context.laundry=controller.map.dorm_small_room_is_laundry
 return {"night_music":controller.night_music.snapshot(),"supplies":{"cash":controller.game_menu.features.cash,"wallet_day":controller.game_menu.features.wallet_day,"table_deployed":controller.dorm_table_deployed},"version":3,"story":controller.story.snapshot(),"saved_at":Time.get_datetime_string_from_system(false,true),"place":controller.place,"position":{"x":pos.x,"y":pos.y},"day":controller.day_cycle.day,"period":controller.day_cycle.period,"inventory":inventory.duplicate(true),"stats":stats.duplicate(true),"context":context,"facing":controller.player.facing}

static func summary(data: Dictionary) -> String:
 if data.is_empty():return "暂无有效存档"
 var periods: Array=["早上","中午","下午","晚上"]
 return "第%d天 · %s · %s\n%s" % [int(data.day),periods[clampi(int(data.period),0,3)],str(data.place),str(data.get("saved_at",""))]
