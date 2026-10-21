extends RefCounted
## 剧情节点只响应完成事件，完全不读取或推算游戏天数。
signal changed
const NODES := ["arrival_reception","go_to_class","attend_class","dorm_organize","onboarding_complete","afternoon_class","night_sleep","next_morning"]
# 事件所属时段只供调试跳转同步使用，正常推进不受日历驱动。
const NODE_PERIODS := {"arrival_reception":0,"go_to_class":0,"attend_class":0,"dorm_organize":1,"onboarding_complete":1,"afternoon_class":2,"night_sleep":3,"next_morning":0}
const NODE_NAMES := {"arrival_reception":"门口接应","go_to_class":"前往1班","attend_class":"早上上课","dorm_organize":"宿舍整理物品","onboarding_complete":"午间整理完成","afternoon_class":"下午上课","night_sleep":"晚上回宿舍睡觉","next_morning":"次日早上"}
var node_id: String = "arrival_reception"
var belongings_stored: bool = false

func advance(event_id: String) -> bool:
 var transitions := {
  "arrival_reception":{"reception_finished":"go_to_class"},
  "go_to_class":{"classroom_entered":"attend_class"},
  "attend_class":{"class_finished":"dorm_organize"},
  "dorm_organize":{"items_organized":"onboarding_complete"},
  "onboarding_complete":{"noon_rest_finished":"afternoon_class","afternoon_started":"afternoon_class"},
  "afternoon_class":{"afternoon_class_finished":"night_sleep"},
  "night_sleep":{"night_sleep_finished":"next_morning"}
 }
 var next: String = str(transitions.get(node_id,{}).get(event_id,""))
 if next.is_empty(): return false
 node_id=next
 changed.emit()
 return true

func waiting_at_gate() -> bool:
 return node_id in ["arrival_reception","go_to_class"]

func cb_can_talk() -> bool:
 return node_id=="next_morning"

func objective() -> String:
 match node_id:
  "arrival_reception": return "到门口和 llx 见面"
  "go_to_class": return "前往教学楼二楼的 1 班教室"
  "attend_class": return "在 1 班上课，熟悉校园生活"
  "dorm_organize": return "中午回男生宿舍 301，把物品放进最右下方的柜子"
  "onboarding_complete": return "午间物品已放好，午休后去一班上下午的课"
  "afternoon_class": return "回到教学楼二楼 1 班，上完下午的课"
  "night_sleep": return "晚上回301，在自己的1号上铺睡到明早"
  _: return "入学首日已结束 · 新的一天开始了"

func snapshot() -> Dictionary:
 return {"node_id":node_id,"belongings_stored":belongings_stored}

func restore(data: Dictionary) -> void:
 var candidate: String=str(data.get("node_id","arrival_reception"))
 node_id=candidate if candidate in NODES else "arrival_reception"
 # 旧存档只继承“已经放过物品”的结果，不继续管理柜内物品。
 belongings_stored=bool(data.get("belongings_stored",NODES.find(node_id)>=NODES.find("onboarding_complete")))
 changed.emit()

func next_node_id() -> String:
 var index:int=NODES.find(node_id)
 return NODES[index+1] if index>=0 and index+1<NODES.size() else ""

func node_period(id:String) -> int:
 return clampi(int(NODE_PERIODS.get(id,0)),0,3)

func node_name(id:String) -> String:
 return str(NODE_NAMES.get(id,id))
