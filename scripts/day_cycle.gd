extends RefCounted
## 手动推进的校园时段；不读取系统时钟，不会自动随等待流逝。
signal changed
const PERIOD_NAMES := ["早上", "中午", "下午", "晚上"]
enum Period { MORNING, NOON, AFTERNOON, NIGHT }
var day: int = 1
var period: int = Period.MORNING

func display_text() -> String:
	return "第%d天 · %s" % [day, PERIOD_NAMES[period]]

func can_advance(source: String) -> bool:
	if source == "classroom":
		return period in [Period.MORNING, Period.AFTERNOON]
	if source == "rest":
		return period in [Period.NOON, Period.NIGHT]
	return false

func next_period_text(source: String) -> String:
	if not can_advance(source): return ""
	if source == "classroom":
		return "中午" if period == Period.MORNING else "晚上"
	return "下午" if period == Period.NOON else "第%d天早上" % (day + 1)

func advance(source: String) -> bool:
	if not can_advance(source): return false
	if source == "classroom":
		period = Period.NOON if period == Period.MORNING else Period.NIGHT
	elif period == Period.NOON:
		period = Period.AFTERNOON
	else:
		day += 1
		period = Period.MORNING
	changed.emit()
	return true


func debug_step(direction: int) -> bool:
	var current: int = (day - 1) * 4 + period
	var target: int = maxi(0, current + signi(direction))
	if target == current: return false
	day = floori(float(target) / 4.0) + 1
	period = target % 4
	changed.emit()
	return true
