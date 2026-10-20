@tool
extends Node2D

@export_enum(
	"校园 G0",
	"教学楼前平台",
	"休息区",
	"教学楼 F2",
	"教学楼 F3",
	"教学楼 F4",
	"教学楼 F5",
	"教学楼男厕",
	"教学楼一楼内走廊",
	"二层第一教室",
	"一楼办公室",
	"食堂内部",
	"二号空房间",
	"会议室内部",
	"小食堂内部",
	"小卖部内部",
	"白房内部",
	"宿舍一楼小房间",
	"宿舍洗澡间", "宿舍厕所",
	"男生宿舍内部",
	"男生宿舍 F2",
	"男生宿舍 F3",
	"宿舍尽头房间一",
	"宿舍尽头房间二"
)
var place: String = "校园 G0":
	set(value):
		place = value
		if is_node_ready():
			configure(place)

const PARK_SHEET = preload("res://assets/tilesets/rasak/park.png")
const FOREST_PLANTS_SHEET = preload("res://assets/tilesets/rasak/forest_plants.png")
const PRISON_SHEET = preload("res://assets/tilesets/rasak/prison.png")
const SHOPPING_SHEET = preload("res://assets/tilesets/rasak/shopping_inside.png")
const CLASSROOM_CLOCK_SHEET = preload("res://assets/tilesets/rasak/classroom_clock.png")
const CLASSROOM_FURNITURE_SHEET = preload("res://assets/tilesets/rasak/classroom_furniture.png")
const CLASSROOM_SURFACE_SHEET = preload("res://assets/tilesets/rasak/classroom_surfaces.png")
const SCHOOL_SHEET = preload("res://assets/tilesets/rasak/school.png")
const NIGHT_LIGHTING = preload("res://scripts/night_lighting.gd")
const CLIMBABLE_LADDER = preload("res://scripts/climbable_ladder.gd")
const BEDROOM_SHEET = preload("res://assets/tilesets/rasak/bedroom.png")
const OFFICE_SHEET = preload("res://assets/tilesets/rasak/office.png")
const HOUSE_ANIMATIONS_SHEET = preload("res://assets/tilesets/rasak/house_animations.png")
const OFFICE_TABLE_SHEET = preload("res://assets/tilesets/rasak/office_tables.png")
const LIVINGROOM_SHEET = preload("res://assets/tilesets/rasak/livingroom.png")
const PUBLIC_BUILDING_SHEET = preload("res://assets/tilesets/rasak/public_building.png")
const WINDOW_LIGHT_SHEET = preload("res://assets/tilesets/rasak/window_light.png")

var map_size := Vector2(3072, 2240)
var map_origin := Vector2.ZERO
var points: Array[Dictionary] = []
var auto_transitions: Array[Dictionary] = []
var classroom_daylight_strength: float = 1.0:
	set(value):
		classroom_daylight_strength = clampf(value, 0.0, 1.0)
		queue_redraw()

var dorm_occluder: Node2D
var night_lighting: Node2D
var night_light_strength: float = 0.0:
	set(value):
		night_light_strength = clampf(value, 0.0, 1.0)
		if is_instance_valid(night_lighting):
			night_lighting.set_strength(night_light_strength)

var dorm_small_room_is_laundry: bool = false
var dorm_cabinet_revealed: bool = false
var revealed_bed_number: int = 0
var bed_ladders: Array[Node2D] = []
var restroom_doors_open: Array[bool] = []
var restroom_door_bodies: Array[StaticBody2D] = []

# 外景把与楼上一致的180像素楼层压缩到原有教学楼范围，一楼门脚固定在1150。
const TEACHING_DOOR_POSITIONS: Array[int] = [870, 660, 510, 290, 80]
const TEACHING_WINDOW_POSITIONS: Array[int] = [162, 562]
const WHITE_HOUSE_INTERIOR_SIZE := Vector2(780,1200)
const DORM_WET_ROOM_SCALE: float = 0.6
const DORM_EXTRA_WIDTH: float = 512.0
const SIDE_STAIR_EXTRA: float = 260.0
const SIDE_STAIR_WIDTH: float = 200.0 + SIDE_STAIR_EXTRA
const CAMPUS_RIGHT: float = 3152.0 + DORM_EXTRA_WIDTH + SIDE_STAIR_EXTRA
const OUTDOOR_COURT_SCALE: float = 0.75
const COURT_OFFSET := Vector2(300,100)
const FRONT_PLAZA_SHIFT := Vector2(-480,0)
const GATE_LEFT: float = 350.0
const GATE_WIDTH: float = 460.0
const GATEHOUSE := Rect2(270,1459,210,140)
const GATEHOUSE_TABLE := Rect2(310,1619,110,55)
const PLAZA_WEST_WALL := Rect2(230,1430,20,660)
const EXTERIOR_TEACHING_SCALE: float = 700.0 / 824.0

var school := Rect2(-200, 450, 1640, 700)
var platform := Rect2(-200, 1150, 1640, 280)
var dorm := Rect2(1942+SIDE_STAIR_EXTRA,670,728+DORM_EXTRA_WIDTH,495)
var white_house := Rect2(1465,230,300,550)
var canteen := Rect2(880,1440,1080,650)
var second_room := Rect2(2340+SIDE_STAIR_EXTRA,1440,812+DORM_EXTRA_WIDTH,650)
var meeting_room := Rect2(2300,1640,590,440)
var small_canteen := Rect2(3100,1700,620,380)
var shop := Rect2(2980+DORM_EXTRA_WIDTH+SIDE_STAIR_EXTRA,800,172,430)
var playground := Rect2(1590, 80, 1440, 470)
var badminton_court := Rect2(1590, 80, 600, 470)
var basketball_court := Rect2(2230, 80, 800, 470)
var noticeboard := Rect2(760,1380,520,26)

@onready var walls: Node2D = $Walls


func _ready() -> void:
	dorm_occluder=load("res://scripts/dorm_exterior_occluder.gd").new()
	dorm_occluder.source_map=self
	dorm_occluder.z_index=20
	dorm_occluder.visible=false
	add_child(dorm_occluder)
	configure(place)


func configure(next_place: String) -> void:
	if place != next_place:
		place = next_place
		return

	map_origin = Vector2.ZERO
	points.clear()
	dorm_cabinet_revealed = false
	revealed_bed_number = 0
	auto_transitions.clear()
	for ladder in bed_ladders:
		if is_instance_valid(ladder):
			ladder.free()
	bed_ladders.clear()
	restroom_doors_open.clear()
	restroom_door_bodies.clear()

	for child in walls.get_children():
		child.free()

	var outside: bool = (
		place == "校园 G0"
		or place == "教学楼前平台"
		or place == "休息区"
	)

	if outside:
		map_origin = Vector2(-1800, 0)
		map_size = Vector2(CAMPUS_RIGHT+1960, 2240)
		if place == "校园 G0":
			_block(Rect2(-1800, 0, 1600, 1430))
			_block(Rect2(-1800,1430,1550,810))

		_school_collision()
		_campus_barriers()
		_gatehouse_collision()
		_block(dorm_exterior_footprint())
		_block(white_house)
		for part in canteen_exterior_solids():
			_block(part)
		for edge in canteen_platform_edges():
			_block(edge)
		_block(canteen_recycling_counter())
		_block(shop)
		_block(meeting_room)
		_block(small_canteen)
		_block(noticeboard)
		for planter in platform_planters():
			_block(planter)
		_point(Vector2(400,1458),"查看立仁教育","education_sign_view",75.0)

		if place == "校园 G0":
			_block(platform)
			_stair_rails()

			_point(Vector2(160, 1460), "左梯上到平台", "left_up", 32.0)
			_point(Vector2(640, 1460), "右梯上到平台", "right_up", 32.0)
			_point(Vector2(1465, 1290), "侧楼梯上到平台", "side_up", 32.0)
			_point(campus_entrance_position("white_house_enter"), "进入白房", "white_house_enter", 45.0)
			_point(campus_entrance_position("dorm_female"), "女生宿舍入口", "dorm_female", 45.0)
			_point(campus_entrance_position("dorm_male_enter"), "进入男生宿舍", "dorm_male_enter", 45.0)
			_point(campus_entrance_position("canteen_from_left"), "从左门进入食堂", "canteen_from_left", 55.0)
			_point(campus_entrance_position("canteen_from_upper"), "从平台出口进入食堂", "canteen_from_upper", 55.0)
			_point(campus_entrance_position("meeting_room_enter"),"进入会议室","meeting_room_enter",45.0)
			_point(campus_entrance_position("small_canteen_enter"),"进入小食堂","small_canteen_enter",45.0)
			_point(campus_entrance_position("shop_enter"), "进入小卖部", "shop_enter", 45.0)

		else:
			_block(Rect2(1440, 0, CAMPUS_RIGHT+160-1440, 2240))
			_block(Rect2(-200, 1430, 1640, 810))

			_point(Vector2(160, 1400), "左梯下到 G0", "left_down", 48.0)
			_point(Vector2(640, 1400), "右梯下到 G0", "right_down", 48.0)
			_point(Vector2(1400, 1290), "侧楼梯下到右侧 G0", "side_down", 48.0)

			_point(Vector2(-100, exterior_teaching_top(1)+36.0*EXTERIOR_TEACHING_SCALE), "沿左侧楼梯上二层", "teaching_west_up", 20.0)
			_classroom_points(1, 1180.0)
			_teaching_utility_points(1, 1180.0)
			_point(Vector2(noticeboard.get_center().x,1335), "查看布告板", "noticeboard", 45.0)
			points[-1]["interaction_rect"] = Rect2(noticeboard.position.x,1300,noticeboard.size.x,65)

			_point(
				Vector2(1000, exterior_teaching_top(1)+36.0*EXTERIOR_TEACHING_SCALE),
				"沿楼内楼梯上二层",
				"upstairs",
				20.0
			)

			auto_transitions.append({"rect": Rect2(1090, exterior_teaching_top(1)+30.0*EXTERIOR_TEACHING_SCALE, 60, 32), "target": "教学楼一楼内走廊", "spawn": Vector2(320, 970)})

			# 平台和休息区共用碰撞与互动点，台阶可直接双向步行。
			_configure_rest_area()

	elif place in ["教学楼 F2", "教学楼 F3", "教学楼 F4", "教学楼 F5"]:
		_configure_teaching_floor()

	elif place == "教学楼男厕":
		_configure_teaching_restroom()
	elif place == "教学楼一楼内走廊":
		_configure_teaching_inner_hall()

	elif place in ["男生宿舍内部", "男生宿舍 F2", "男生宿舍 F3"]:
		_configure_dorm_floor()

	elif place in ["宿舍尽头房间一", "宿舍尽头房间二"]:
		_configure_six_bed_room()

	elif place in ["宿舍洗澡间", "宿舍厕所"]:
		_configure_dorm_wet_room()
	elif place == "白房内部":
		map_size = WHITE_HOUSE_INTERIOR_SIZE
		_block(Rect2(0,0,map_size.x,60))
		_block(Rect2(0,map_size.y-60,map_size.x,60))
		_block(Rect2(0,60,60,map_size.y-120))
		_block(Rect2(map_size.x-60,60,60,map_size.y-120))
		_point(white_house_indoor_exit_position(),"离开白房","white_house_exit",45.0)
		_configure_white_house_furniture()
	elif place == "宿舍一楼小房间":
		map_size = Vector2(700, 560)
		_empty_room_walls()
		if dorm_small_room_is_laundry:
			for machine in dorm_laundry_machines():
				_block(machine["rect"])
		_point(Vector2(350, 440), "返回宿舍一楼楼梯间", "dorm_small_room_exit", 45.0)
	
	
	elif place == "一楼办公室":
		map_size = Vector2(900, 700)
		_empty_room_walls()
		for item in _office_furniture():
			_block(item["collision"])
		_point(Vector2(450, 590), "返回教学楼一楼平台", "office_exit", 45.0)

	elif place in ["会议室内部","小食堂内部"]:
		map_size=Vector2(1000,800) if place=="会议室内部" else Vector2(1100,760)
		_empty_room_walls()
		var action:String="meeting_room_exit" if place=="会议室内部" else "small_canteen_exit"
		_point(Vector2(map_size.x*0.5,125),"出口：返回右侧广场",action,45.0)

	elif place == "二号空房间":
		map_size = Vector2(1000, 900)
		_empty_room_walls()
		_point(Vector2(160, 110), "从上侧左端出口返回广场", "second_room_exit", 45.0)

	elif place == "小卖部内部":
		map_size = Vector2(600, 1000)
		_empty_room_walls()
		_point(Vector2(110, 500), "从左侧出口返回广场", "shop_exit", 45.0)
		for item in _shop_furniture():
			_block(item["collision"] )
		_point(Vector2(300, 390), "与商户对话", "shop_merchant", 45.0)
		points[-1]["show_ring"] = false
		points[-1]["interaction_rect"] = Rect2(285, 330, 30, 120)

	elif place == "食堂内部":
		map_size = Vector2(1400, 900)

		_block(Rect2(0, 0, 1400, 80))
		_block(Rect2(0, 820, 1400, 80))
		_block(Rect2(0, 80, 80, 740))
		_block(Rect2(1320, 80, 80, 740))

		for table in _canteen_tables():
			_block(table)
		for stool in _canteen_stools():
			_block(stool)
		_block(Rect2(960, 410, 360, 410))

		_point(Vector2(110, 500), "左门：返回校门广场", "canteen_exit_left", 45.0)
		_point(Vector2(1150, 110), "出口：前往室外平台", "canteen_exit_upper", 45.0)
		_point(Vector2(920, 500), "取饭", "canteen_take_meal", 45.0)
		_point(Vector2(560, 295), "坐下吃饭", "canteen_eat_meal", 65.0)

	else:
		# cb 教室：五排，每排四组课桌。
		map_size = Vector2(1280, 1320)

		_block(Rect2(0, 0, 1280, 80))
		_block(Rect2(0, 1240, 1280, 80))
		_block(Rect2(0, 80, 80, 1160))
		_block(Rect2(1200, 80, 80, 1160))

		for item in _classroom_furniture():
			_block(item["collision"] )

		_point(
			Vector2(1160, 280),
			"右侧前门：返回走廊",
			"exit_classroom_front",
			42.0
		)

		_point(
			Vector2(1160, 1100),
			"右侧后门：返回走廊",
			"exit_classroom_back",
			42.0
		)
		_point(Vector2(735, 1069), "上课推进时段", "time_classroom", 65.0)
		points[-1]["enabled"] = false
		points[-1]["show_ring"] = false

	_block(Rect2(map_origin + Vector2(-32, -32), Vector2(map_size.x + 64, 32)))
	_block(Rect2(map_origin + Vector2(-32, map_size.y), Vector2(map_size.x + 64, 32)))
	_block(Rect2(map_origin + Vector2(-32, 0), Vector2(32, map_size.y)))
	_block(Rect2(map_origin + Vector2(map_size.x, 0), Vector2(32, map_size.y)))

	_configure_night_lighting()
	if is_instance_valid(dorm_occluder):
		dorm_occluder.hide()
		dorm_occluder.queue_redraw()
	queue_redraw()


func _classroom_points(floor_number: int, y: float) -> void:
	# 从楼梯附近开始，由右往左数。
	# 第1门：独立房间。
	# 第2、3门：同一间房的前门、后门。
	# 第4、5门：另一间房的前门、后门。
	var positions: Array[int] = TEACHING_DOOR_POSITIONS
	var rooms: Array[int] = [1, 2, 2, 3, 3]

	for index in range(5):
		var title: String = "%d层 · 第%d间房" % [
			floor_number,
			rooms[index]
		]
		if index > 0:
			var class_number: int = teaching_class_number(floor_number, index >= 3)
			title = "%d班" % class_number
		var action: String = "room_closed"

		if floor_number == 1 and index == 0:
			title = "进入一楼办公室"
			action = "office_enter"

		elif floor_number == 2 and index == 1:
			title = "1班 · cb 教室 · 前门"
			action = "classroom_front"

		elif floor_number == 2 and index == 2:
			title = "1班 · cb 教室 · 后门"
			action = "classroom_back"

		elif index > 0:
			title += " · " + (
				"前门" if index % 2 == 1 else "后门"
			)

		_point(Vector2(positions[index], y), title, action, 42.0)
		points[-1]["show_ring"] = false


func _point(
	pos: Vector2,
	title: String,
	action: String,
	radius: float = 80.0
) -> void:
	points.append({
		"pos": pos,
		"title": title,
		"action": action,
		"radius": radius
	})


func _block(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()

	shape.size = rect.size
	collision.shape = shape

	body.add_child(collision)
	walls.add_child(body)
	return body


func exterior_teaching_top(floor_number: int) -> float:
	return 1150.0 - (104.0+(floor_number-1)*180.0)*EXTERIOR_TEACHING_SCALE

func _school_collision() -> void:
	# 墙脚、楼梯井和外景绘制共用同一高度，避免旧外墙碰撞残留。
	var stair_head: float = exterior_teaching_top(1)+16.0*EXTERIOR_TEACHING_SCALE
	_block(Rect2(-200,450,1640,stair_head-450.0))
	_block(Rect2(-200,stair_head,60,1150.0-stair_head))
	_block(Rect2(-60,stair_head,1020,1150.0-stair_head))
	_block(Rect2(1040,stair_head,50,1150.0-stair_head))
	_block(Rect2(1150,stair_head,290,1150.0-stair_head))

func _campus_barriers() -> void:
	_block(Rect2(CAMPUS_RIGHT, 0, 160, 2240))
	_block(Rect2(-250, 2090, CAMPUS_RIGHT+410, 150))
	_block(Rect2(1440, 0, 20, 1150))


func _gatehouse_collision() -> void:
	_block(Rect2(PLAZA_WEST_WALL.position+FRONT_PLAZA_SHIFT,PLAZA_WEST_WALL.size))
	_block(Rect2(GATEHOUSE.position+FRONT_PLAZA_SHIFT,GATEHOUSE.size))
	_block(Rect2(GATEHOUSE_TABLE.position+FRONT_PLAZA_SHIFT,GATEHOUSE_TABLE.size))
	_block(Rect2(Vector2(GATE_LEFT,2060)+FRONT_PLAZA_SHIFT,Vector2(40,100)))
	_block(Rect2(Vector2(GATE_LEFT+GATE_WIDTH-40,2060)+FRONT_PLAZA_SHIFT,Vector2(40,100)))


func _front_stair_rails() -> Array[Rect2]:
	var shifted: Array[Rect2]=[]
	for rail in _front_stair_rails_unshifted():
		shifted.append(Rect2(rail.position+FRONT_PLAZA_SHIFT,rail.size))
	return shifted

func _front_stair_rails_unshifted() -> Array[Rect2]:
	# 竖梯与横梯统一为 70 宽，两组楼梯整体向右移动 80。
	return [
		Rect2(585,1430,20,265), Rect2(675,1430,20,175),
		Rect2(675,1585,135,20), Rect2(585,1675,225,20),
		Rect2(1155,1430,20,265), Rect2(1065,1430,20,175),
		Rect2(950,1585,135,20), Rect2(950,1675,225,20)
	]

func _stair_rails() -> void:
	for rail in _front_stair_rails():
		_block(rail)
	_block(Rect2(1440,1130,SIDE_STAIR_WIDTH,20))
	for rail in side_stair_bottom_rails():
		_block(rail)


func _text(pos: Vector2, value: String, size: int = 22) -> void:
	draw_string(
		ThemeDB.fallback_font,
		pos,
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		Color.WHITE
	)


func _building(rect: Rect2, title: String, floors: int) -> void:
	draw_rect(rect, Color("#747e8c"))
	draw_rect(
		Rect2(rect.position, Vector2(rect.size.x, 50)),
		Color("#465468")
	)

	var band_height: float = (rect.size.y - 70.0) / floors

	for floor_index in range(floors):
		var y: float = rect.position.y + 65 + floor_index * band_height

		var window_count: int = int(rect.size.x / 100.0) - 1
		if rect == dorm:
			window_count = int((rect.size.x - 82.0) / 100.0) + 1
		for column in range(window_count):
			if rect == school and column >= 10:
				continue
			draw_rect(
				Rect2(rect.position.x + 30 + column * 100, y, 52, 38),
				Color("#b5dae5")
			)

		draw_line(
			Vector2(rect.position.x, y + band_height - 12),
			Vector2(rect.end.x, y + band_height - 12),
			Color("#d1d5d9"),
			5
		)

	_text(rect.position + Vector2(24, 35), title, 26)


func _stairs(rect: Rect2, horizontal: bool = false, steps: int = 10, canvas: Node2D = null) -> void:
	var target:Node2D=self if canvas==null else canvas
	target.draw_rect(rect, Color("#b8afa0"))

	for index in range(1,steps):
		var ratio: float = float(index)/float(steps)

		if horizontal:
			var x: float = rect.position.x + rect.size.x * ratio
			target.draw_line(
				Vector2(x, rect.position.y),
				Vector2(x, rect.end.y),
				Color("#655f59"),
				3
			)
		else:
			var y: float = rect.position.y + rect.size.y * ratio
			target.draw_line(
				Vector2(rect.position.x, y),
				Vector2(rect.end.x, y),
				Color("#655f59"),
				3
			)


func _draw_l_stairs() -> void:
	draw_set_transform(FRONT_PLAZA_SHIFT)
	_draw_l_stairs_unshifted()
	draw_set_transform(Vector2.ZERO)

func _draw_l_stairs_unshifted() -> void:
	_stairs(Rect2(675,1605,135,70),true)
	draw_rect(Rect2(605,1605,70,70),Color("#b8afa0"))
	_stairs(Rect2(605,1430,70,175))
	_stairs(Rect2(950,1605,135,70),true)
	draw_rect(Rect2(1085,1605,70,70),Color("#b8afa0"))
	_stairs(Rect2(1085,1430,70,175))
	for rail in _front_stair_rails_unshifted():
		draw_rect(rail,Color("#626974"))
	_text(Vector2(660,1735),"左梯入口",20)
	_text(Vector2(980,1735),"右梯入口",20)


func _draw() -> void:
	if place in ["校园 G0", "教学楼前平台", "休息区"]:
		_draw_campus()

	elif place in ["教学楼 F2", "教学楼 F3", "教学楼 F4", "教学楼 F5"]:
		_draw_corridor()
	elif place == "教学楼男厕":
		_draw_teaching_restroom()
	elif place == "教学楼一楼内走廊":
		_draw_teaching_inner_hall()
	elif place in ["男生宿舍内部", "男生宿舍 F2", "男生宿舍 F3"]:
		_draw_dorm_interior()
	elif place in ["宿舍尽头房间一", "宿舍尽头房间二"]:
		_draw_dorm_room()
	elif place in ["宿舍洗澡间", "宿舍厕所"]:
		_draw_dorm_wet_room()
	elif place == "白房内部":
		_draw_white_house_interior()
	elif place == "一楼办公室":
		_draw_office()
	elif place == "小卖部内部":
		_draw_shop_interior()
	elif place in ["二号空房间", "宿舍一楼小房间", "会议室内部", "小食堂内部"]:
		_draw_empty_zone()
	elif place == "食堂内部":
		_draw_canteen_interior()
	else:
		_draw_classroom()

	for point in points:
		if not point.get("show_ring", true):
			continue
		var pos: Vector2 = point["pos"]
		draw_arc(pos, 23, 0, TAU, 32, Color.GOLD, 3)


func _draw_campus() -> void:
	draw_rect(Rect2(map_origin-Vector2(4096,4096),map_size+Vector2(8192,8192)),Color("#557b50"))
	draw_rect(Rect2(-240, 1440, CAMPUS_RIGHT+240, 650), Color("#b3b1a4"))
	draw_rect(Rect2(1460, 570, CAMPUS_RIGHT-1460, 1520), Color("#b3b1a4"))

	_text(Vector2(170, 1870), "校门内广场 G0", 28)
	_text(Vector2(2470+DORM_EXTRA_WIDTH*0.5+SIDE_STAIR_EXTRA,1320), "右侧广场 G0", 28)

	draw_rect(Rect2(-200, 1430, 1640, 22), Color("#575a60"))
	draw_rect(platform, Color("#c6c1b4"))

	for x in range(-200, 1441, 80):
		draw_line(
			Vector2(x, 1150), Vector2(x, 1430),
			Color("#aaa699"), 1
		)

	for y in range(1150, 1431, 70):
		draw_line(
			Vector2(-200, y), Vector2(1440, y),
			Color("#aaa699"), 1
		)

	_text(Vector2(650, 1210), "教学楼一层开放平台", 28)

	draw_line(Vector2(-200, 1430), Vector2(125, 1430), Color("#414a55"), 7)
	draw_line(Vector2(195, 1430), Vector2(605, 1430), Color("#414a55"), 7)
	draw_line(Vector2(675, 1430), Vector2(1440, 1430), Color("#414a55"), 7)

	_draw_exterior_teaching_building()
	_draw_dorm_exterior()

	_draw_white_house()
	_draw_canteen_exterior()
	_draw_shop()
	_draw_south_annex(meeting_room,"会议室")
	_draw_south_annex(small_canteen,"小食堂")
	draw_rect(Rect2(canteen.position.x,1730,20,100), Color("#584736"))
	draw_rect(Rect2(canteen.position.x+3,1734,14,92), Color("#b8d3d7"))

	_text(Vector2(canteen.position.x+30,1800), "左门", 20)

	draw_rect(Rect2(1440, 0, 20, 1150), Color("#50595b"))
	draw_line(Vector2(CAMPUS_RIGHT, 0), Vector2(CAMPUS_RIGHT, 2090), Color("#50595b"), 10)
	draw_line(Vector2(0, 0), Vector2(CAMPUS_RIGHT, 0), Color("#50595b"), 10)
	draw_line(Vector2(-250, 2090), Vector2(GATE_LEFT+FRONT_PLAZA_SHIFT.x, 2090), Color("#50595b"), 10)
	draw_line(Vector2(GATE_LEFT+GATE_WIDTH+FRONT_PLAZA_SHIFT.x, 2090), Vector2(CAMPUS_RIGHT, 2090), Color("#50595b"), 10)

	_draw_platform_planters()
	_draw_noticeboard()
	_draw_l_stairs()
	_draw_education_sign_edges()

	_stairs(Rect2(1440,1150,SIDE_STAIR_WIDTH,280),true,23)
	draw_rect(Rect2(1440,1130,SIDE_STAIR_WIDTH,20), Color("#626974"))
	for rail in side_stair_bottom_rails():
		draw_rect(rail,Color("#626974"))
	_text(Vector2(1465, 1110), "平台 ↔ G0", 20)

	_draw_rest_area()

	_draw_blue_sports_courts()

	_draw_gatehouse()
	draw_set_transform(FRONT_PLAZA_SHIFT)
	draw_rect(Rect2(GATE_LEFT,2090,GATE_WIDTH,35),Color("#48515f"))
	draw_rect(Rect2(GATE_LEFT,2060,40,100),Color("#767f8b"))
	draw_rect(Rect2(GATE_LEFT+GATE_WIDTH-40,2060,40,100),Color("#767f8b"))
	_text(Vector2(GATE_LEFT+155,2120),"校门",28)
	draw_set_transform(Vector2.ZERO)


func education_sign_blocks() -> Array[Rect2]:
	var blocks: Array[Rect2]=[]
	for i in range(5):
		blocks.append(Rect2(269+i*55,1454,42,8))
	return blocks

func _draw_education_sign_edges() -> void:
	# 俯视只看到四个字和中间校徽的五个扁红色边缘，夜间同样不加发光效果。
	for block in education_sign_blocks():
		draw_rect(Rect2(block.position+Vector2(0,2),block.size),Color("#792c2b"))
		draw_rect(block,Color("#bd3530"))
		draw_rect(Rect2(block.position,Vector2(block.size.x,2)),Color("#db5b4e"))


func _draw_gatehouse() -> void:
	draw_set_transform(FRONT_PLAZA_SHIFT)
	_draw_gatehouse_unshifted()
	draw_set_transform(Vector2.ZERO)

func _draw_gatehouse_unshifted() -> void:
	# 左侧实墙连续接住平台和南边界，封住通向草地的路。
	draw_rect(PLAZA_WEST_WALL,Color("#7f897d"))
	draw_rect(Rect2(230,1430,6,660),Color("#aeb6a3"))
	for y in range(1450,2090,70):
		draw_line(Vector2(236,y),Vector2(250,y),Color("#6e7b70"),1)
	# 门卫室外观：封闭墙体、房檐、原版窗户和关闭的侧门。
	draw_rect(Rect2(GATEHOUSE.position+Vector2(5,6),GATEHOUSE.size),Color(0.15,0.19,0.16,0.18))
	draw_rect(GATEHOUSE,Color("#dfd9c1"))
	draw_rect(Rect2(270,1477,210,5),Color("#b8b59d"))
	draw_rect(Rect2(263,1452,224,26),Color("#657c70"))
	_text(Vector2(315,1473),"保安厅",20)
	draw_texture_rect_region(CLASSROOM_CLOCK_SHEET,Rect2(291,1490,82,96),Rect2(0,64,48,56))
	draw_rect(Rect2(421,1510,43,89),Color("#8a907c"))
	draw_rect(Rect2(426,1515,33,84),Color("#c6d1c4"))
	draw_rect(Rect2(431,1522,23,28),Color("#a8c8c9"))
	draw_circle(Vector2(452,1563),2,Color("#626d5e"))
	draw_rect(Rect2(270,1593,151,6),Color("#aaa68f"))
	# 使用原版完整木桌，桌腿和桌面一起呈现。
	draw_texture_rect_region(OFFICE_SHEET,GATEHOUSE_TABLE,Rect2(0,504,96,72))



func _draw_exterior_teaching_building() -> void:
	var roof_top: float = exterior_teaching_top(5)
	var building_bottom: float = exterior_teaching_top(1)+180.0*EXTERIOR_TEACHING_SCALE
	draw_rect(Rect2(-212,roof_top-4,1664,building_bottom-roof_top+8),Color("#24272c"))
	for floor_number in range(5,0,-1):
		draw_set_transform(Vector2(0,exterior_teaching_top(floor_number)),0,Vector2(1,EXTERIOR_TEACHING_SCALE))
		_facade_floor(0.0,floor_number,true)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-212,roof_top-12,1664,12),Color("#596066"))
	draw_rect(Rect2(-212,roof_top,12,building_bottom-roof_top),Color("#bbbcb4"))
	draw_rect(Rect2(1440,roof_top,12,building_bottom-roof_top),Color("#9c9f99"))
	draw_line(Vector2(-212,roof_top),Vector2(1452,roof_top),Color("#e6e3da"),2)
	_text(Vector2(1040,roof_top-20),"教学楼 · 五层开放式外走廊",20)
	_text(Vector2(-155,1205),"上二层",20)
	_text(Vector2(1065,1205),"上二层",20)

func _draw_corridor() -> void:
	draw_rect(Rect2(map_origin, map_size), Color("#30343a"))
	var visible_floors: PackedInt32Array = teaching_visible_floors()
	var floor_count: int = visible_floors.size()
	var show_plaza: bool = _teaching_floor_number() <= 3
	var building_bottom: float = 100.0 + floor_count * 180.0
	draw_rect(Rect2(-146, 96, 1692, building_bottom - 80.0), Color("#24272c"))
	if show_plaza:
		draw_rect(Rect2(-120, 564, 1640, 256), Color("#aaa9a0"))
		for y in range(590, 821, 38):
			draw_line(Vector2(-120, y), Vector2(1520, y), Color("#a2a197"), 1)
		for x in range(-120, 1521, 120):
			draw_line(Vector2(x, 564), Vector2(x, 820), Color("#a2a197"), 1)
	for index in range(floor_count):
		_facade_floor(100.0 + index * 180.0, visible_floors[index])
	draw_rect(Rect2(-132, 88, 1664, 12), Color("#596066"))
	draw_rect(Rect2(-132, 100, 12, building_bottom - 100.0), Color("#bbbcb4"))
	draw_rect(Rect2(1520, 100, 12, building_bottom - 100.0), Color("#9c9f99"))
	draw_line(Vector2(-132, 100), Vector2(1532, 100), Color("#e6e3da"), 2)
	if show_plaza:
		_text(Vector2(100, 790), "教学楼前广场", 20)

func _facade_floor(top: float, floor_number: int, exterior: bool = false) -> void:
	var facade_left: float = -200.0 if exterior else -120.0
	var facade_right: float = 1440.0 if exterior else 1520.0
	var facade_width: float = facade_right-facade_left
	var west_x: float = -100.0 if exterior else -20.0
	var current_floor: int = _teaching_floor_number()
	var wall_color := Color("#c8c7bd")
	var floor_color := Color("#939690")

	if floor_number == current_floor:
		wall_color = Color("#d3d1c5")
		floor_color = Color("#aaa9a0")

	if floor_number == 1:
		floor_color = Color("#aaa9a0")

	draw_rect(Rect2(facade_left, top, facade_width, 104), wall_color)
	draw_rect(Rect2(facade_left, top, facade_width, 7), Color("#676d70"))
	draw_rect(Rect2(facade_left, top + 7, facade_width, 4), Color("#e2e1d8"))
	draw_rect(Rect2(facade_left, top + 98, facade_width, 6), Color("#5b615e"))

	for y_offset in [38, 70]:
		draw_line(
			Vector2(facade_left+2, top + y_offset),
			Vector2(facade_right-2, top + y_offset),
			Color("#babbb2"),
			1
		)

	draw_rect(Rect2(facade_right-22, top + 11, 5, 93), Color("#969e9c"))

	var door_positions: Array[int] = TEACHING_DOOR_POSITIONS

	for door_x in door_positions:
		draw_rect(Rect2(door_x - 30, top + 22, 60, 82), Color("#5e5145"))
		draw_rect(Rect2(door_x - 26, top + 26, 52, 78), Color("#dddcd1"))
		draw_rect(Rect2(door_x - 22, top + 30, 44, 28), Color("#aac7cc"))
		draw_rect(Rect2(door_x - 26, top + 94, 52, 10), Color("#6c989e"))
		draw_circle(Vector2(door_x + 18, top + 76), 2, Color("#4b4b47"))

	for window_x in TEACHING_WINDOW_POSITIONS:
		draw_rect(Rect2(window_x, top + 35, 46, 43), Color("#7a8a90"))
		draw_rect(Rect2(window_x + 3, top + 38, 40, 37), Color("#b9dce5"))
		draw_line(
			Vector2(window_x + 23, top + 38),
			Vector2(window_x + 23, top + 75),
			Color("#ecebe2"),
			2
		)

	draw_rect(Rect2(facade_left, top + 104, facade_width, 76), floor_color)
	draw_line(
		Vector2(facade_left, top + 105), Vector2(facade_right, top + 105),
		Color("#737973"), 2
	)

	draw_rect(Rect2(956, top + 10, 88, 122), Color("#444c4d"))
	draw_rect(Rect2(960, top + 14, 80, 116), Color("#687171"))
	_stairs(Rect2(962, top + 20, 76, 84))
	draw_rect(Rect2(956, top + 10, 6, 122), Color("#a7aba4"))
	draw_rect(Rect2(1038, top + 10, 6, 122), Color("#909991"))

	if floor_number > 1:
		draw_rect(Rect2(facade_left, top + 164, facade_width, 16), Color("#bdb8a5"))
		draw_rect(Rect2(facade_left, top + 164, facade_width, 3), Color("#e5e0ce"))
		draw_rect(Rect2(facade_left, top + 177, facade_width, 3), Color("#636967"))

		for seam_x in range(int(facade_left)+20, int(facade_right), 52):
			draw_line(
				Vector2(seam_x, top + 168),
				Vector2(seam_x, top + 176),
				Color("#a49f91"),
				1
			)

		draw_line(
			Vector2(facade_left, top + 156),
			Vector2(facade_right, top + 156),
			Color("#343d40"),
			2
		)

		for post_x in range(int(facade_left)+8, int(facade_right), 22):
			draw_line(
				Vector2(post_x, top + 156),
				Vector2(post_x, top + 164),
				Color("#434d4f"),
				1
			)

	if floor_number == 1:
		# 一楼楼梯右侧是无门的敞口，地坪连续通向楼内。
		draw_rect(Rect2(1090, top + 22, 60, 82), Color("#9da79f"))
		draw_rect(Rect2(1090, top + 22, 60, 8), Color("#66746f"))
		draw_line(Vector2(1090, top + 30), Vector2(1090, top + 104), Color("#b9c5ba"), 3)
		draw_line(Vector2(1150, top + 30), Vector2(1150, top + 104), Color("#b9c5ba"), 3)
		_text(Vector2(1088, top + 17), "楼内通道", 14)

	# 复制右侧楼梯的画法和尺寸到左端。
	draw_rect(Rect2(west_x-44, top + 10, 88, 122), Color("#444c4d"))
	draw_rect(Rect2(west_x-40, top + 14, 80, 116), Color("#687171"))
	_stairs(Rect2(west_x-38, top + 20, 76, 84))
	draw_rect(Rect2(west_x-44, top + 10, 6, 122), Color("#a7aba4"))
	draw_rect(Rect2(west_x+38, top + 10, 6, 122), Color("#909991"))
	_draw_floor_utilities(top, floor_number, 1385.0 if exterior else 1460.0)
	_text(Vector2(facade_left+20, top + 75), "%dF" % floor_number, 18)

	for left_class in [true, false]:
		var door_x: float = TEACHING_DOOR_POSITIONS[3] if left_class else TEACHING_DOOR_POSITIONS[1]
		var class_number: int = teaching_class_number(floor_number, left_class)
		var caption: String = "%d班" % class_number
		if class_number == 1:
			caption += " · cb"
		draw_rect(Rect2(door_x - 46, top + 3, 92, 18), Color("#566763"))
		_text(Vector2(door_x - 34, top + 17), caption, 15)


func _draw_classroom() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_draw_classroom_shell()
	_draw_classroom_windows()
	# 新图集中的完整黑板和教学家具，保留五排四组、每组两席。
	draw_texture_rect_region(CLASSROOM_FURNITURE_SHEET,Rect2(520,82,240,120),Rect2(630,1941,84,69))
	_text(Vector2(850,58),"二层 · 1班（cb 所在教室）",20)
	# 时钟位于黑板中线上方，标题避开钟面。
	draw_texture_rect_region(CLASSROOM_CLOCK_SHEET,Rect2(618,24,44,46),Rect2(396,438,23,24))
	for item in _classroom_furniture():
		draw_texture_rect_region(item.get("texture",CLASSROOM_FURNITURE_SHEET),item["rect"],item["region"])
	draw_rect(Rect2(1186,230,32,100),Color("#785139"))
	draw_rect(Rect2(1186,1050,32,100),Color("#785139"))
	_text(Vector2(1035,265),"前门 →",20)
	_text(Vector2(1035,1085),"后门 →",20)

func _draw_classroom_shell() -> void:
	draw_rect(Rect2(Vector2.ZERO,map_size),Color("#50566c"))
	# 第二张图的浅灰地砖；按同一格尺寸铺满，避免整张拉伸。
	for y in range(80,1240,80):
		for x in range(80,1200,80):
			var height: int = mini(80,1240-y)
			draw_texture_rect_region(CLASSROOM_SURFACE_SHEET,Rect2(x,y,80,height),Rect2(528,528,48,48*height/80.0))
	# 浅色墙面、蓝绿色护墙板和墙脚。
	for x in range(80,1200,80):
		draw_texture_rect_region(CLASSROOM_SURFACE_SHEET,Rect2(x,0,80,80),Rect2(192,432,144,96))
	draw_rect(Rect2(0,80,80,1160),Color("#b8d0ce"))
	draw_rect(Rect2(1200,80,80,1160),Color("#b8d0ce"))
	draw_rect(Rect2(80,1240,1120,80),Color("#b8d0ce"))
	draw_rect(Rect2(74,80,6,1160),Color("#586877"))
	draw_rect(Rect2(1200,80,6,1160),Color("#586877"))
	draw_rect(Rect2(80,1234,1120,6),Color("#586877"))

func _classroom_furniture() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	items.append({"kind":"teacher_desk","region":Rect2(246,1749,84,75),"rect":Rect2(568,150,144,72),"collision":Rect2(568,174,144,48)})
	for row in range(5):
		for column in range(4):
			var at := Vector2(260+column*200,300+row*170)
			for seat in range(2):
				var desk := Rect2(at+Vector2(seat*50,0),Vector2(50,60))
				items.append({"kind":"student_desk","region":Rect2(96,1743,48,57),"rect":desk,"collision":desk})
				var chair := Rect2(at+Vector2(5+seat*50,66),Vector2(40,46))
				items.append({"kind":"student_chair","region":Rect2(51,1851,42,48),"rect":chair,"collision":chair})
	items.append({"kind":"bookcase","region":Rect2(480,3282,96,94),"rect":Rect2(1000,110,130,128),"collision":Rect2(1000,150,130,88)})
	items.append({"kind":"globe","region":Rect2(627,1731,39,63),"rect":Rect2(160,1138,52,84),"collision":Rect2(172,1202,28,20)})
	items.append({"kind":"plant","region":Rect2(501,2139,54,93),"rect":Rect2(170,110,54,93),"collision":Rect2(182,181,30,22)})
	items.append({"kind":"plant","region":Rect2(501,2139,54,93),"rect":Rect2(1110,1138,54,93),"collision":Rect2(1122,1209,30,22)})
	# 图三左下角的蓝色双层柜；左右两段之间留出上课光圈和通行位置。
	for index in range(7):
		var x: float = 260+index*96 if index < 4 else 800+(index-4)*96
		var cabinet := Rect2(x,1158,96,80)
		items.append({"kind":"rear_locker","texture":SCHOOL_SHEET,"region":Rect2(0,696,48,40),"rect":cabinet,"collision":cabinet})
	return items

# 外部轮廓由左侧主体和凹口下方主体拼成，凹口留给室外平台与回收区。
func canteen_notch() -> Rect2:
	return Rect2(canteen.end.x-360,canteen.position.y,360,220)

func canteen_exterior_solids() -> Array[Rect2]:
	var notch:Rect2=canteen_notch()
	return [Rect2(canteen.position,Vector2(canteen.size.x-360,canteen.size.y)),Rect2(notch.position.x,notch.end.y,360,canteen.size.y-220)]

func canteen_platform_rail() -> Rect2:
	return Rect2(canteen_notch().position.x+255,1430,16,230)

func canteen_recycling_counter() -> Rect2:
	return Rect2(canteen_notch().position+Vector2(155,-5),Vector2(90,220))

func canteen_platform_edges() -> Array[Rect2]:
	return [canteen_platform_rail(),Rect2(canteen_platform_rail().position.x,1430,canteen.end.x-canteen_platform_rail().position.x,12)]

func side_stair_bottom_rails() -> Array[Rect2]:
	# 楼梯南侧在平台正上方留出连续通道，其余边缘保留护栏。
	return [Rect2(1440,1430,canteen_notch().position.x-1440,20)]

func _draw_canteen_exterior() -> void:
	_building(canteen,"食堂",1)
	var notch:Rect2=canteen_notch()
	# 遮去右上角建筑与窗户，改为可以走入的凹形室外区域。
	draw_rect(notch,Color("#b3b1a4"))
	var landing:=Rect2(notch.position-Vector2(0,10),Vector2(255,230))
	draw_rect(landing,Color("#ccc8b8"))
	for y in range(int(landing.position.y)+40,int(landing.end.y),40):
		draw_line(Vector2(landing.position.x,y),Vector2(landing.end.x,y),Color("#b0ae9f"),1)
	for x in range(int(landing.position.x)+42,int(landing.end.x),42):
		draw_line(Vector2(x,landing.position.y),Vector2(x,landing.end.y),Color("#b0ae9f"),1)
	draw_line(notch.position,Vector2(notch.position.x,notch.end.y),Color("#465468"),7)
	draw_line(Vector2(notch.position.x,notch.end.y),notch.end,Color("#465468"),8)
	# 平台高于右侧广场，立面和完整护栏阻止直接横穿。
	draw_rect(Rect2(canteen_platform_rail().end.x,1440,12,220),Color("#67706c"))
	for edge in canteen_platform_edges():
		draw_rect(edge,Color("#515b59"))
		draw_line(edge.position,Vector2(edge.position.x,edge.end.y),Color("#d4d9ce"),2)
	_text(landing.position+Vector2(44,55),"平台",21)
	# 出口位于凹口底部，对应室内原上门。
	var door_x:float=landing.position.x+85
	draw_rect(Rect2(door_x-38,notch.end.y-9,76,18),Color("#584736"))
	draw_rect(Rect2(door_x-32,notch.end.y-6,64,12),Color("#b8d3d7"))
	_text(Vector2(door_x-22,notch.end.y+37),"出口",20)
	_draw_canteen_recycling()

func _draw_canteen_recycling() -> void:
	var counter:Rect2=canteen_recycling_counter()
	draw_rect(Rect2(counter.position+Vector2(4,5),counter.size),Color(0,0,0,0.14))
	draw_rect(counter,Color("#687e7c"))
	draw_rect(counter.grow(-5),Color("#c1ccc5"))
	# 回收槽沿墙纵向排列，左侧保留楼梯到出口的通道。
	for i in range(2):
		var hole:=Rect2(counter.position+Vector2(12,17+i*105),Vector2(44,72))
		draw_rect(hole,Color("#71877e"))
		draw_rect(hole.grow(-5),Color("#354e46"))
		for n in range(3):
			draw_circle(hole.position+Vector2(14+(n%2)*13,20+n*15),4,Color("#a8a66f"))
	for i in range(4):
		_text(counter.position+Vector2(63,40+i*43),"饭菜回收"[i],17)


func _draw_canteen_interior() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("#64665f"))
	draw_rect(Rect2(80, 80, 1240, 740), Color("#c5c0b0"))
	for tile_y in range(80, 821, 80):
		draw_line(Vector2(80, tile_y), Vector2(1320, tile_y), Color("#b8b4a5"), 1)
	for tile_x in range(80, 1321, 80):
		draw_line(Vector2(tile_x, 80), Vector2(tile_x, 820), Color("#b8b4a5"), 1)
	draw_rect(Rect2(80, 80, 1240, 740), Color("#e5dfd0"), false, 4)

	for table in _canteen_tables():
		draw_rect(Rect2(table.position + Vector2(4, 6), table.size), Color(0, 0, 0, 0.14))
		draw_rect(table, Color("#636f70"))
		draw_rect(table.grow(-5), Color("#aebfba"))
		draw_line(table.position + Vector2(10, 12), Vector2(table.end.x - 10, table.position.y + 12), Color("#d6dfd3"), 3)
	for stool in _canteen_stools():
		draw_rect(Rect2(stool.position + Vector2(2, 3), stool.size), Color("#566463"))
		draw_rect(stool, Color("#8daca2"))
		draw_rect(stool.grow(-4), Color("#b5c8b9"))

	# 右下档口封闭，顾客从左侧柜台前取餐。
	draw_rect(Rect2(960, 410, 360, 410), Color("#7c8b84"))
	draw_rect(Rect2(960, 410, 44, 410), Color("#d6d9cd"))
	draw_line(Vector2(960, 410), Vector2(960, 820), Color("#65766c"), 5)
	for tray_y in [460, 550, 640, 730]:
		draw_rect(Rect2(968, tray_y, 28, 58), Color("#8fa5a0"))
		draw_rect(Rect2(973, tray_y + 6, 18, 46), Color("#bdb78c"))
	draw_rect(Rect2(1020, 430, 280, 38), Color("#506f61"))
	_text(Vector2(1050, 458), "装饭档口", 24)

	# 左门保留，上门移到右上方。
	draw_rect(Rect2(65, 455, 30, 90), Color("#72533d"))
	draw_rect(Rect2(1115, 65, 70, 30), Color("#72533d"))
	_text(Vector2(145, 510), "左门 · 校门广场", 20)
	_text(Vector2(1080, 140), "出口 · 室外平台", 18)

func _white_house_door_y() -> float:
	return white_house.position.y+white_house.size.y*(160.0/260.0)

func _draw_white_house() -> void:
	draw_rect(white_house,Color("#727c7b"),false,6)
	draw_rect(white_house,Color("#f0efea"))
	draw_rect(Rect2(white_house.position,Vector2(white_house.size.x,26)),Color("#d7dddc"))
	var door_y: float = _white_house_door_y()
	draw_rect(Rect2(white_house.end.x-26,door_y-35,26,70),Color("#65716c"))
	draw_rect(Rect2(white_house.end.x-20,door_y-29,20,58),Color("#a4bebc"))
	_text(white_house.position+Vector2(20,65),"白房",22)


func white_house_indoor_exit_position() -> Vector2:
	return Vector2(WHITE_HOUSE_INTERIOR_SIZE.x-100,WHITE_HOUSE_INTERIOR_SIZE.y*0.75)

func white_house_partitions() -> Array[Rect2]:
	return [Rect2(60,510,260,22),Rect2(460,510,260,22)]

func white_house_office_furniture() -> Array[Dictionary]:
	var items:Array[Dictionary]=[]
	for x in [120.0,490.0]:
		items.append({"texture":OFFICE_SHEET,"source":Rect2(144,384,96,72),"rect":Rect2(x,200,160,120)})
		items.append({"texture":OFFICE_SHEET,"source":Rect2(0,288,48,48),"rect":Rect2(x+56,330,48,48)})
	items.append({"texture":OFFICE_SHEET,"source":Rect2(576,96,144,72),"rect":Rect2(300,100,180,90)})
	items.append({"texture":OFFICE_SHEET,"source":Rect2(336,112,48,72),"rect":Rect2(110,400,48,72)})
	items.append({"texture":LIVINGROOM_SHEET,"source":Rect2(272,640,80,64),"rect":Rect2(560,395,120,96)})
	return items

func white_house_meeting_table() -> Dictionary:
	return {"center":Vector2(390,860),"size":Vector2(192,240),"angle":PI/4.0,"source":Rect2(424,600,112,128)}

func white_house_tv() -> Rect2:
	return Rect2(575,1025,125,100)

func _configure_white_house_furniture() -> void:
	for wall in white_house_partitions():_block(wall)
	for item in white_house_office_furniture():_block(item["rect"])
	var table:Dictionary=white_house_meeting_table()
	var table_body:StaticBody2D=_block(Rect2(table["center"]-table["size"]*0.5,table["size"]))
	table_body.rotation=table["angle"]
	_block(white_house_tv())

func _draw_white_house_interior() -> void:
	draw_rect(Rect2(Vector2.ZERO,map_size),Color("#e8e6df"))
	var floor_rect:=Rect2(Vector2(60,60),map_size-Vector2(120,120))
	draw_rect(floor_rect,Color("#c9c5b8"))
	draw_rect(floor_rect,Color("#faf9f4"),false,4)
	# 上部办公室与下部会议区由墙分隔，中间140宽通道直接贯通。
	draw_rect(Rect2(60,60,660,450),Color("#d4d3c6"))
	for wall in white_house_partitions():
		draw_rect(Rect2(wall.position+Vector2(0,4),wall.size),Color("#92988c"))
		draw_rect(wall,Color("#e6e6d8"))
		draw_line(wall.position,Vector2(wall.end.x,wall.position.y),Color("#faf9ef"),3)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for item in white_house_office_furniture():
		draw_texture_rect_region(item["texture"],item["rect"],item["source"])
	var table:Dictionary=white_house_meeting_table()
	draw_set_transform(table["center"],table["angle"])
	draw_texture_rect_region(LIVINGROOM_SHEET,Rect2(-table["size"]*0.5,table["size"]),table["source"])
	draw_set_transform(Vector2.ZERO)
	var tv:Rect2=white_house_tv()
	draw_texture_rect_region(LIVINGROOM_SHEET,Rect2(tv.position+Vector2(0,55),Vector2(125,45)),Rect2(248,270,128,48))
	draw_texture_rect_region(LIVINGROOM_SHEET,Rect2(tv.position+Vector2(8,0),Vector2(108,54)),Rect2(144,96,96,48))
	draw_rect(Rect2(map_size.x-60,white_house_indoor_exit_position().y-35,18,70),Color("#65716c"))
	_text(Vector2(map_size.x-155,white_house_indoor_exit_position().y-50),"出口 →",20)

func _dorm_floor_number() -> int:
	if place == "男生宿舍 F3":
		return 3
	if place == "男生宿舍 F2":
		return 2
	return 1


func _configure_dorm_floor() -> void:
	var floor_number: int = _dorm_floor_number()
	map_origin = Vector2(-360, 0)
	map_size = Vector2(5160, 760)
	_block(Rect2(map_origin.x, 0, map_size.x, 80))
	_block(Rect2(map_origin.x, 700, map_size.x, 60))
	_block(Rect2(map_origin.x, 80, 80, 620))
	_block(Rect2(4740, 80, 60, 620))
	# 三层共用长走廊，一二楼所有房门暂不开放。
	_block(Rect2(80, 80, 4300, 180))
	_block(Rect2(80, 480, 4300, 220))
	for index in range(12):
		var door_x: float = 260.0 + index * 340.0
		var action: String = "dorm_room_closed"
		var title: String = "别人的宿舍"
		if floor_number == 3 and index == 0:
			action = "dorm_room_one"
			title = "进入走廊尽头房间一"
		elif floor_number == 3 and index == 1:
			action = "dorm_room_two"
			title = "进入走廊尽头房间二"
		_point(Vector2(door_x, 440), title, action, 45.0)

	if floor_number < 3:
		var up_x: float = 4620.0 if floor_number == 1 else 4500.0
		_block(Rect2(up_x - 20, 80, 20, 280))
		_block(Rect2(up_x + 100, 80, 20, 280))
		auto_transitions.append({"rect": Rect2(up_x, 120, 100, 80), "step": 1})
	if floor_number == 3:
		# 上四楼的楼梯存在，但复用一楼左端的完整铁门封住，不设自动换层。
		_block(Rect2(4480,80,20,280))
		_block(Rect2(4600,80,20,280))
		_block(Rect2(4500,135,100,225))
		_point(Vector2(4550,395),"查看通往四楼的锁闭铁门","dorm_fourth_stairs_locked",45.0)
	if floor_number > 1:
		_block(Rect2(4620, 80, 20, 280))
		auto_transitions.append({"rect": Rect2(4640, 120, 100, 80), "step": -1})
	if floor_number == 1:
		_block(Rect2(4400, 80, 170, 180))
		_point(Vector2(4480, 295), "进入一楼小房间", "dorm_small_room_enter", 45.0)
		_block(Rect2(4400, 620, 90, 58))
		_point(Vector2(4690, 640), "离开宿舍，返回广场", "dorm_male_exit", 45.0)
		# 左端楼梯间：无自动换层触发，铁门实体封住楼梯。
		_block(Rect2(-260, 80, 170, 180))
		_point(Vector2(-180, 295), "进入左侧小房间", "dorm_left_small_room_enter", 45.0)
		_block(Rect2(-60, 80, 20, 280))
		_block(Rect2(60, 80, 20, 280))
		_block(Rect2(-40, 135, 100, 225))
		_point(Vector2(10, 395), "查看锁着的铁门", "dorm_left_stairs_locked", 45.0)
	if floor_number > 1:
		# 只锁住走廊通往左侧楼梯间的侧入口，楼梯本身不放铁栏杆。
		_block(Rect2(-280,80,20,280))
		_block(Rect2(40,80,20,280))
		_block(dorm_upper_left_gate())
		_point(Vector2(125,370),"查看锁着的楼梯间铁门","dorm_left_stairs_locked",55.0)

func dorm_upper_left_gate() -> Rect2:
	return Rect2(60,260,20,220)



func _draw_dorm_interior() -> void:
	var floor_number: int = _dorm_floor_number()
	draw_rect(Rect2(map_origin, map_size), Color("#777c79"))
	draw_rect(Rect2(80, 260, 4300, 220), Color("#c6c2b6"))
	for tile_x in range(80, 4380, 100):
		draw_line(Vector2(tile_x, 260), Vector2(tile_x, 480), Color("#b3afa3"), 1)
	draw_line(Vector2(80, 370), Vector2(4380, 370), Color("#b3afa3"), 1)
	draw_rect(Rect2(80, 480, 4300, 220), Color("#e0ddd1"))
	for index in range(12):
		var door_x: float = 260.0 + index * 340.0
		draw_rect(Rect2(door_x - 42, 480, 84, 14), Color("#4d5956"))
		_text(Vector2(door_x - 20, 530), str(floor_number * 100 + 1 + index), 20)
	_draw_dorm_court_view()
	_draw_dorm_soft_railing(Rect2(80, -300, 4300, 560))
	# 名牌独立衬底，避免栏杆影响文字辨识。
	draw_rect(Rect2(108, 195, 370, 48), Color("#505d5b"))
	_text(Vector2(120, 230), "男生宿舍 %d 楼 · 长走廊" % floor_number, 26)

	draw_rect(Rect2(4380, 80, 360, 620), Color("#c6c2b6"))
	_text(Vector2(4400, 510), "走上楼梯自动换层", 20)
	_text(Vector2(4400, 460), "%d 楼楼梯间" % floor_number, 24)
	if floor_number < 3:
		var up_x: float = 4620.0 if floor_number == 1 else 4500.0
		_stairs(Rect2(up_x, 120, 100, 240))
		_text(Vector2(up_x - 10, 105), "上楼", 20)
		draw_rect(Rect2(up_x - 20, 80, 20, 280), Color("#626c68"))
		draw_rect(Rect2(up_x + 100, 80, 20, 280), Color("#626c68"))
	if floor_number == 3:
		_stairs(Rect2(4500,120,100,240))
		draw_rect(Rect2(4480,80,20,280),Color("#626c68"))
		draw_rect(Rect2(4600,80,20,280),Color("#626c68"))
		_text(Vector2(4490,105),"上四楼",20)
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		draw_texture_rect_region(PRISON_SHEET,Rect2(4500,135,100,225),Rect2(392,24,32,72))
	if floor_number == 1:
		# 左上小房间的外墙和朝下的入口。
		draw_rect(Rect2(4400, 80, 170, 180), Color("#ded9cb"))
		draw_rect(Rect2(4400, 80, 170, 28), Color("#65756f"))
		_text(Vector2(4420, 103), "小房间", 20)
		draw_rect(Rect2(4445, 205, 70, 55), Color("#596b65"))
		draw_rect(Rect2(4450, 210, 60, 50), Color("#b9d0cc"))
		# 完整壁挂电话：左侧听筒与右侧数字按键，取自原始电子设备素材。
		draw_rect(Rect2(4400, 590, 90, 88), Color("#a7aca5"))
		draw_rect(Rect2(4400, 590, 90, 88), Color("#66736c"), false, 3)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_texture_rect_region(HOUSE_ANIMATIONS_SHEET, Rect2(4385, 555, 120, 120), Rect2(432, 192, 48, 48))
		# 左侧参照右端布局，不复制电话或广场出口。
		draw_rect(Rect2(-280, 80, 360, 620), Color("#c6c2b6"))
		draw_rect(Rect2(-260, 80, 170, 180), Color("#ded9cb"))
		draw_rect(Rect2(-260, 80, 170, 28), Color("#65756f"))
		_text(Vector2(-240, 103), "小房间", 20)
		draw_rect(Rect2(-215, 205, 70, 55), Color("#596b65"))
		draw_rect(Rect2(-210, 210, 60, 50), Color("#b9d0cc"))
		_stairs(Rect2(-40, 120, 100, 240))
		draw_rect(Rect2(-60, 80, 20, 280), Color("#626c68"))
		draw_rect(Rect2(60, 80, 20, 280), Color("#626c68"))
		# 原图独立的完整高铁门，保留门框、横梁和全部竖杆。
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_texture_rect_region(PRISON_SHEET, Rect2(-40, 135, 100, 225), Rect2(392, 24, 32, 72))
		_text(Vector2(-75, 105), "楼梯 · 铁门锁闭", 19)
		_text(Vector2(-250, 460), "一楼左侧楼梯间", 24)
	if floor_number > 1:
		_stairs(Rect2(4640, 120, 100, 240))
		_text(Vector2(4640, 105), "下楼", 20)
		draw_rect(Rect2(4620, 80, 20, 280), Color("#626c68"))
		_draw_upper_left_dorm_stairs(floor_number)

func _draw_upper_left_dorm_stairs(floor_number:int) -> void:
	draw_rect(Rect2(-280,80,360,620),Color("#c6c2b6"))
	_stairs(Rect2(-245,120,110,240))
	_stairs(Rect2(-95,120,110,240))
	draw_rect(Rect2(-280,80,20,280),Color("#626c68"))
	draw_rect(Rect2(40,80,20,280),Color("#626c68"))
	_text(Vector2(-248,106),"上楼",20)
	_text(Vector2(-92,106),"下楼",20)
	# 只取原素材的竖向侧柱，沿走廊与楼梯间分界放置侧面铁门。
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	draw_texture_rect_region(PRISON_SHEET,dorm_upper_left_gate(),Rect2(476,96,8,144))
	_text(Vector2(-250,468),"%d楼左侧楼梯间" % floor_number,23)
	_text(Vector2(-245,505),"铁门锁闭",20)



func _dorm_beds() -> Array[Rect2]:
	return [Rect2(140, 280, 180, 300), Rect2(140, 650, 180, 300), Rect2(780, 650, 180, 300)]


func _dorm_partitions() -> Array[Rect2]:
	return [Rect2(80, 1010, 310, 55), Rect2(710, 1010, 310, 55)]

func _configure_six_bed_room() -> void:
	map_size = Vector2(1100, 1800)
	_block(Rect2(0, 0, 1100, 80))
	_block(Rect2(0, 1720, 1100, 80))
	_block(Rect2(0, 80, 80, 1640))
	_block(Rect2(1020, 80, 80, 1640))
	var beds := _dorm_beds()
	for index in range(beds.size()):
		var bed: Rect2 = beds[index]
		_block(bed)
		var ladder = CLIMBABLE_LADDER.new()
		ladder.name = "BedLadder%d" % (index + 1)
		ladder.bed_number = index + 1
		ladder.use_rasak_steps = true
		ladder.horizontal_side_ladder = true
		ladder.horizontal_length = 70.0
		ladder.lean_direction = -1 if index == 2 else 1
		ladder.angle_from_vertical = 12.0
		ladder.upper_side_distance = 52.0
		ladder.top_hook_length = 0.0
		ladder.position = Vector2(bed.position.x if index == 2 else bed.end.x, bed.position.y + 70)
		add_child(ladder)
		bed_ladders.append(ladder)
		_point(to_local(ladder.get_landing_position()), "沿梯子上%d号上铺" % (index + 1), "bed_ladder_up", 48.0)
		points[-1]["ladder"] = ladder
	_block(Rect2(790, 80, 230, 430))
	_point(Vector2(735, 290), "查看柜子和台面", "dorm_cabinet_reveal", 55.0)
	for wall in _dorm_partitions():
		_block(wall)
	for fixture in [Rect2(140, 1130, 180, 160), Rect2(140, 1380, 180, 120), Rect2(140, 1540, 180, 120), Rect2(760, 1140, 260, 210), Rect2(760, 1450, 260, 210)]:
		_block(fixture)
	_point(Vector2(715, 1245), "进入洗澡间", "dorm_shower_enter", 45.0)
	_point(Vector2(715, 1555), "进入厕所", "dorm_toilet_enter", 45.0)
	if place == "宿舍尽头房间一":
		_block(Rect2(634, 174, 32, 32))
	if place == "宿舍尽头房间一":
		var noon_rest_position := to_local(bed_ladders[0].get_upper_position())
		_point(noon_rest_position, "午休到下午", "time_rest_noon", 22.0)
		points[-1]["rest_period"] = 1
		points[-1]["enabled"] = false
		points[-1]["show_ring"] = false
		_point(noon_rest_position - Vector2(65, 0), "夜间睡觉", "time_rest_night", 22.0)
		points[-1]["rest_period"] = 3
		points[-1]["enabled"] = false
		points[-1]["show_ring"] = false
	var exit_action: String = "dorm_room_one_exit" if place == "宿舍尽头房间一" else "dorm_room_two_exit"
	_point(Vector2(550, 120), "返回三楼走廊", exit_action, 45.0)


func set_bed_roof_revealed(number: int) -> void:
	revealed_bed_number = number
	queue_redraw()

func _draw_bunk_bed(rect: Rect2, number: int) -> void:
	# 上下铺完全重合，只绘制可见的上铺；不再露出下铺边缘。
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var blue := Color(1.25, 1.55, 1.75)
	var upper := rect.grow(-6)
	draw_texture_rect_region(BEDROOM_SHEET, upper, Rect2(240, 48, 48, 144), blue)
	# 顶板四角与床身完全对齐，保持竖直、无透视斜角。
	var alpha: float = 0.14 if revealed_bed_number == number else 1.0
	var roof := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_colored_polygon(roof, Color(0.81, 0.55, 0.22, alpha))
	draw_polyline(PackedVector2Array([roof[0],roof[1],roof[2],roof[3],roof[0]]), Color(0.61,0.37,0.13,alpha), 4, true)
	for index in range(1, 7):
		var grain := PackedVector2Array()
		for step in range(13):
			var y: float = 8 + step * (rect.size.y - 48) / 12.0
			var x: float = index * (rect.size.x - 14) / 7.0 + sin(step * 0.65 + index) * 2.4
			grain.append(rect.position + Vector2(x, y))
		draw_polyline(grain, Color(0.59,0.35,0.12,alpha * 0.55), 1.5, true)
	for post in [rect.position, rect.position + Vector2(rect.size.x - 6, 0)]:
		draw_rect(Rect2(post, Vector2(6, rect.size.y)), Color(0.69,0.43,0.16,alpha))
	_text(rect.position + Vector2(0, -20), "%d号上下铺 · 2人" % number, 18)

func _draw_dorm_room() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("#e0ddd1"))
	draw_rect(Rect2(80, 80, 940, 1640), Color("#c6c2b6"))
	draw_rect(Rect2(80, 1140, 940, 580), Color("#bfc9c6"))
	for tile_y in range(1140, 1721, 80):
		draw_line(Vector2(80, tile_y), Vector2(1020, tile_y), Color("#a4b2af"), 1)
	for tile_x in range(80, 1021, 80):
		draw_line(Vector2(tile_x, 1140), Vector2(tile_x, 1720), Color("#a4b2af"), 1)
	# 顶部中央房门。
	draw_rect(Rect2(480, 62, 140, 18), Color("#4d5956"))
	_text(Vector2(640, 120), "返回走廊", 20)
	var beds: Array[Rect2] = _dorm_beds()
	for index in range(beds.size()):
		_draw_bunk_bed(beds[index], index + 1)
	_draw_dorm_cabinet_stack()
	for wall in _dorm_partitions():
		draw_rect(wall, Color("#e3e0d1"))
		draw_line(wall.position, Vector2(wall.end.x, wall.position.y), Color("#faf7ea"), 5)
		draw_line(Vector2(wall.position.x, wall.end.y), wall.end, Color("#939e96"), 4)
	_draw_dorm_basin(Rect2(140, 1130, 180, 160), true)
	_text(Vector2(140, 1110), "洗衣池", 21)
	for y in [1380, 1540]:
		_draw_dorm_basin(Rect2(140, y, 180, 120), false)
	_text(Vector2(140, 1360), "洗漱台", 21)
	for item in [{"rect": Rect2(760, 1140, 260, 210), "title": "洗澡间"}, {"rect": Rect2(760, 1450, 260, 210), "title": "厕所"}]:
		var room: Rect2 = item.rect
		draw_rect(room, Color("#d6dfd8"))
		draw_rect(room, Color("#7d928a"), false, 9)
		_text(room.position + Vector2(65, 40), item.title, 24)
		var door := Rect2(room.position + Vector2(-8, 65), Vector2(20, 80))
		draw_rect(door, Color("#7c6653"))
		draw_rect(door.grow(-3), Color("#e6e2d3"))
		draw_circle(door.position + Vector2(5, 58), 2, Color("#78684b"))
	if place == "宿舍尽头房间一":
		# 足球仅在当前这一间出现，不复制到其他宿舍。
		var ball := Vector2(650, 190)
		draw_circle(ball + Vector2(3, 5), 18, Color(0, 0, 0, 0.16))
		draw_circle(ball, 16, Color("#f3f0e4"))
		var patch := PackedVector2Array()
		for corner in range(5):
			var angle: float = -PI / 2.0 + corner * TAU / 5.0
			patch.append(ball + Vector2(cos(angle), sin(angle)) * 7.0)
		draw_colored_polygon(patch, Color("#303b40"))
		for seam in range(5):
			var angle: float = -PI / 2.0 + seam * TAU / 5.0
			draw_line(ball + Vector2(cos(angle), sin(angle)) * 7.0, ball + Vector2(cos(angle), sin(angle)) * 15.0, Color("#566263"), 1.5)
func platform_planters() -> Array[Rect2]:
	return [Rect2(-180,1380,280,32),Rect2(225,1380,365,32)]

func platform_planter_plants() -> Array[Dictionary]:
	var plants:Array[Dictionary]=[]
	var rng:=RandomNumberGenerator.new()
	rng.seed=20261020
	for planter in platform_planters():
		var count:int=int(planter.size.x/44)
		for i in range(count):
			var variant:int=rng.randi_range(0,3)
			var center_x:float=planter.position.x+(i+0.5)*planter.size.x/count
			plants.append({"rect":Rect2(center_x-18,planter.position.y-25,36,48),"source":Rect2(variant*48,112,48,64),"variant":variant})
	return plants

func _draw_platform_planters() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for planter in platform_planters():
		draw_rect(Rect2(planter.position+Vector2(3,4),planter.size),Color(0,0,0,0.14))
		var x:float=planter.position.x
		while x<planter.end.x:
			var width:float=minf(32,planter.end.x-x)
			draw_texture_rect_region(PARK_SHEET,Rect2(x,planter.position.y,width,32),Rect2(672,528,width*1.5,48))
			x+=width
	for plant in platform_planter_plants():
		draw_texture_rect_region(FOREST_PLANTS_SHEET,plant["rect"],plant["source"])

func _draw_noticeboard() -> void:
	# 空白展示面，内容由后续制作时补充。
	draw_rect(Rect2(noticeboard.position + Vector2(8,6),noticeboard.size), Color(0, 0, 0, 0.16))
	draw_rect(noticeboard, Color("#675347"))
	draw_rect(noticeboard.grow(-5), Color("#d9d3bb"))
	draw_line(noticeboard.position, Vector2(noticeboard.end.x, noticeboard.position.y), Color("#9a8870"), 3)

func _empty_room_walls() -> void:
	_block(Rect2(0, 0, map_size.x, 80))
	_block(Rect2(0, map_size.y - 80, map_size.x, 80))
	_block(Rect2(0, 80, 80, map_size.y - 160))
	_block(Rect2(map_size.x - 80, 80, 80, map_size.y - 160))


func dorm_laundry_machines() -> Array[Dictionary]:
	var sources:Array[Rect2]=[Rect2(384,672,48,96),Rect2(432,672,48,96),Rect2(480,672,48,96)]
	var positions:Array[Vector2]=[Vector2(110,100),Vector2(314,100),Vector2(518,100),Vector2(110,290),Vector2(518,290)]
	var types:Array[int]=[0,1,2,1,2]
	var machines:Array[Dictionary]=[]
	for i in range(5):
		var source:Rect2=sources[types[i]]
		machines.append({"rect":Rect2(positions[i],source.size*1.5),"source":source,"type":types[i]})
	return machines

func _draw_dorm_laundry() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for machine in dorm_laundry_machines():
		var rect:Rect2=machine["rect"]
		draw_rect(Rect2(rect.position+Vector2(3,4),rect.size),Color(0,0,0,0.12))
		draw_texture_rect_region(PRISON_SHEET,rect,machine["source"])

func _draw_empty_zone() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("#747c78"))
	var floor_rect := Rect2(Vector2(80, 80), map_size - Vector2(160, 160))
	draw_rect(floor_rect, Color("#c6c2b6"))
	draw_rect(floor_rect, Color("#e4e2d7"), false, 3)
	if place=="宿舍一楼小房间" and dorm_small_room_is_laundry:
		_draw_dorm_laundry()
	if place in ["会议室内部","小食堂内部"]:
		draw_rect(Rect2(map_size.x*0.5-38,65,76,20),Color("#6d7976"))
		_text(Vector2(map_size.x*0.5+65,132),"出口 · 返回广场",20)
	elif place == "宿舍一楼小房间":
		draw_rect(Rect2(315, 465, 70, 15), Color("#6d7976"))
		_text(Vector2(395, 440), "出口 · 返回一楼", 20)
	elif place == "一楼办公室":
		draw_rect(Rect2(415, 615, 70, 20), Color("#6d7976"))
		_text(Vector2(495, 590), "出口 · 返回一楼平台", 20)
	elif place == "二号空房间":
		draw_rect(Rect2(125, 65, 70, 20), Color("#6d7976"))
		_text(Vector2(230, 120), "出口 · 返回广场", 20)
	else:
		draw_rect(Rect2(65, 465, 20, 70), Color("#6d7976"))
		_text(Vector2(145, 510), "出口 · 返回广场", 20)


func _draw_south_annex(rect:Rect2,title:String) -> void:
	draw_rect(Rect2(rect.position+Vector2(5,7),rect.size),Color("#74756e"))
	_building(rect,title,1)
	var door_x:float=rect.get_center().x
	draw_rect(Rect2(door_x-42,rect.position.y,84,22),Color("#584736"))
	draw_rect(Rect2(door_x-36,rect.position.y+3,72,15),Color("#b8d3d7"))

func _draw_shop() -> void:
	draw_rect(shop, Color("#e0ddd1"))
	draw_rect(shop, Color("#596761"), false, 5)
	draw_rect(Rect2(shop.position, Vector2(shop.size.x, 46)), Color("#5d7b6a"))
	_text(shop.position + Vector2(20, 32), "小卖部", 24)
	for window_y in [shop.position.y+90, shop.position.y+300]:
		draw_rect(Rect2(shop.position.x+40, window_y, 85, 54), Color("#a8ccd2"))
	draw_rect(Rect2(shop.position.x, shop.position.y+180, 20, 70), Color("#667b76"))
func _teaching_floor_number() -> int:
	if place.begins_with("教学楼 F"):
		return int(place.trim_prefix("教学楼 F"))
	return 1


func teaching_visible_floors() -> PackedInt32Array:
	var floor_number: int = _teaching_floor_number()
	if floor_number == 5:
		return PackedInt32Array([5, 4, 3, 2])
	if floor_number == 4:
		return PackedInt32Array([4, 3, 2, 1])
	return PackedInt32Array([3, 2, 1])


func teaching_top_for_floor(floor_number: int) -> float:
	return 100.0 + (maxi(3, floor_number) - floor_number) * 180.0


func _configure_teaching_floor() -> void:
	map_origin = Vector2(-200, 0)
	map_size = Vector2(1800, 820)
	var floor_number: int = _teaching_floor_number()
	var top: float = teaching_top_for_floor(floor_number)
	var walk_top: float = top + 104.0
	var rail_top: float = top + 164.0
	# 左右两端分别留出同尺寸的楼梯井。
	_block(Rect2(-200, 0, 140, walk_top))
	_block(Rect2(20, 0, 940, walk_top))
	_block(Rect2(1040, 0, 560, walk_top))
	_block(Rect2(-60, 0, 80, top + 16))
	_block(Rect2(960, 0, 80, top + 16))
	_block(Rect2(-200, rail_top, 1800, 820 - rail_top))
	_block(Rect2(-200, walk_top, 80, rail_top - walk_top))
	_block(Rect2(1520, walk_top, 80, rail_top - walk_top))
	if floor_number < 5:
		_point(Vector2(1000, top + 36), "上到%d楼" % (floor_number + 1), "teaching_up", 20.0)
		_point(Vector2(-20, top + 36), "左侧楼梯：上到%d楼" % (floor_number + 1), "teaching_west_up", 20.0)
	_point(Vector2(1000, top + 136), "下到%d楼" % (floor_number - 1), "teaching_down", 24.0)
	_point(Vector2(-20, top + 136), "左侧楼梯：下到%d楼" % (floor_number - 1), "teaching_west_down", 24.0)
	_classroom_points(floor_number, top + 130.0)
	_teaching_utility_points(floor_number, top + 130.0)

func _teaching_utility_points(floor_number: int, y: float) -> void:
	var restroom_title: String = "进入男厕所" if floor_number % 2 == 1 else "女厕所 · 仅限女生"
	_point(Vector2(1240, y), restroom_title, "teaching_restroom", 40.0)
	points[-1]["show_ring"] = false
	points[-1]["floor"] = floor_number
	_point(Vector2(1460 if floor_number > 1 else 1385, y), "饮水机 · 装水处", "teaching_water", 38.0)
	points[-1]["floor"] = floor_number


func _draw_floor_utilities(top: float, floor_number: int, water_x: float = 1460.0) -> void:
	var sign_color := Color("#476f91") if floor_number % 2 == 1 else Color("#95647c")
	draw_rect(Rect2(1210, top + 22, 64, 82), Color("#536360"))
	draw_rect(Rect2(1216, top + 28, 52, 76), Color("#d9ddd2"))
	draw_rect(Rect2(1210, top + 8, 64, 18), sign_color)
	_text(Vector2(1222, top + 22), "男厕" if floor_number % 2 == 1 else "女厕", 13)
	_draw_water_dispenser(Rect2(water_x-20, top + 42, 38, 62))


func _draw_water_dispenser(rect: Rect2) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 使用用户标出的灰色饮水机与桶装水组合，底部对齐原位置。
	var target := Rect2(rect.get_center().x - 32, rect.end.y - 64, 64, 64)
	draw_texture_rect_region(PUBLIC_BUILDING_SHEET, target, Rect2(144, 408, 48, 48))

func _draw_teaching_restroom() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("#cdd8d4"))
	draw_rect(Rect2(80, 80, 1440, 600), Color("#bac9c5"))
	for tile_y in range(80, 681, 40):
		draw_line(Vector2(80, tile_y), Vector2(1520, tile_y), Color("#9eafac"), 1)
	for tile_x in range(80, 1521, 40):
		draw_line(Vector2(tile_x, 80), Vector2(tile_x, 680), Color("#9eafac"), 1)
	# 原图上完整的 48×96 隔间单元，分别使用完整开门/关门状态。
	for index in range(3):
		var x: float = 140 + index * 180
		var source_y: float = 384.0 if restroom_doors_open[index] else 480.0
		draw_texture_rect_region(PUBLIC_BUILDING_SHEET, Rect2(x, 150, 160, 320), Rect2(432, source_y, 48, 96))
		_text(Vector2(x + 52, 130), "隔间 %d" % (index + 1), 18)
	# 两个完整小便池；完整的三盆长镜洗手台，不再只取其中一半。
	draw_texture_rect_region(PUBLIC_BUILDING_SHEET, Rect2(760, 210, 192, 96), Rect2(384, 576, 96, 48))
	draw_texture_rect_region(PUBLIC_BUILDING_SHEET, Rect2(1110, 180, 288, 192), Rect2(576, 480, 144, 96))
	_text(Vector2(740, 120), "男厕所", 26)
	_text(Vector2(1050, 620), "出口 · 返回本层走廊 →", 22)
	draw_rect(Rect2(1504, 550, 16, 100), Color("#5b716e"))

func _canteen_tables() -> Array[Rect2]:
	var tables: Array[Rect2] = []
	for column in range(5):
		tables.append(Rect2(200 + column * 190, 140, 80, 210))
	for column in range(4):
		tables.append(Rect2(200 + column * 190, 560, 80, 210))
	return tables


func _canteen_stools() -> Array[Rect2]:
	var stools: Array[Rect2] = []
	for table in _canteen_tables():
		for offset_y in [45, 145]:
			stools.append(Rect2(table.position.x - 30, table.position.y + offset_y, 20, 20))
			stools.append(Rect2(table.end.x + 10, table.position.y + offset_y, 20, 20))
	return stools
func _rest_bike_positions() -> Array[Vector2]:
	# 原地踏车器沿最右侧竖直等距排列，止于平台入口上方。
	return [Vector2(-60,560),Vector2(-60,680),Vector2(-60,800),Vector2(-60,920),Vector2(-60,1040)]

func _configure_rest_area_layout() -> void:
	_block(Rect2(-1120,480,20,1320))
	_block(Rect2(-1100,480,1140,20))
	_block(Rect2(-1100,1780,1140,20))
	_block(Rect2(40,500,20,650))
	_block(Rect2(40,1430,20,350))
	_block(Rect2(-1100,780,650,842))
	_block(Rect2(-930,580,240,120))
	for at in _rest_bike_positions():
		_block(Rect2(at,Vector2(90,60)))
	_point(Vector2(-410,1105),"查看左侧宿舍","rest_dorm_locked",45.0)
	_point(Vector2(-980,1665),"休息区教室一","room_closed",40.0)
	_point(Vector2(-760,1665),"休息区教室二","room_closed",40.0)
	_point(Vector2(-540,1665),"休息区办公室","room_closed",40.0)


func _draw_rest_steps() -> void:
	# 休息区直接紧邻这条 50 像素宽的两级台阶，不再留连接段。
	draw_rect(Rect2(-250, 1150, 50, 280), Color("#aaa99d"))
	for x in [-233, -216]:
		draw_line(Vector2(x, 1150), Vector2(x, 1430), Color("#686f68"), 2)
	draw_line(Vector2(-250, 1150), Vector2(-200, 1150), Color("#d6d5c6"), 3)
	draw_line(Vector2(-250, 1430), Vector2(-200, 1430), Color("#676f67"), 3)

func _draw_rest_area_layout() -> void:
	draw_rect(Rect2(-1100,500,1140,1280),Color("#b9b7a7"))
	draw_rect(Rect2(-1100,500,1140,280),Color("#8b9d83"))
	_text(Vector2(-1050,540),"休息区 · 乒乓球活动区",24)
	draw_rect(Rect2(-1120,480,20,1320),Color("#7c8680"))
	draw_rect(Rect2(-1100,480,1140,20),Color("#7c8680"))
	draw_line(Vector2(-1110,490),Vector2(-1110,1780),Color("#d6d8c9"),4)
	# 乒乓球桌与上边界一同向上移动 320。
	draw_rect(Rect2(-925,588,240,120),Color(0,0,0,0.18))
	draw_rect(Rect2(-930,580,240,120),Color("#3a737c"))
	draw_rect(Rect2(-930,580,240,120),Color("#d9e4da"),false,4)
	draw_line(Vector2(-930,640),Vector2(-690,640),Color("#d9e4da"),2)
	draw_line(Vector2(-810,576),Vector2(-810,704),Color("#edf0dd"),6)
	# 方形封闭宿舍，不增加楼层；下方既有三扇门仍然保持关闭。
	var closed_dorm:=Rect2(-1100,780,650,650)
	draw_rect(Rect2(closed_dorm.position+Vector2(6,8),closed_dorm.size),Color("#69746f"))
	draw_rect(closed_dorm,Color("#89959c"))
	draw_rect(Rect2(-1100,780,650,50),Color("#48596a"))
	_text(Vector2(-1075,815),"宿舍 · 暂不开放",26)
	draw_rect(Rect2(-1100,1420,650,20),Color("#68787c"))
	draw_rect(Rect2(-470,1070,20,70),Color("#aab8af"))
	for at in _rest_bike_positions():
		_draw_exercise_bike(at)
	_text(Vector2(-115,535),"原地踏车器",22)
	draw_rect(Rect2(-1100,1440,650,90),Color("#747e8c"))
	draw_rect(Rect2(-1100,1530,650,92),Color("#c9c5b8"))
	draw_rect(Rect2(-1100,1530,650,14),Color("#6e7a73"))
	for door_x in [-980,-760,-540]:
		draw_rect(Rect2(door_x-32,1544,64,78),Color("#606c66"))
		draw_rect(Rect2(door_x-26,1550,52,72),Color("#aebfb5"))
		draw_circle(Vector2(door_x+15,1592),3,Color("#5b6962"))
	draw_rect(Rect2(40,500,20,650),Color("#777e73"))
	draw_rect(Rect2(40,1430,20,350),Color("#777e73"))
	_text(Vector2(-390,1740),"开放式休息区",24)


func _draw_exercise_bike(pos: Vector2) -> void:
	draw_rect(Rect2(pos, Vector2(90, 60)), Color("#8e9d92"))
	draw_circle(pos + Vector2(45, 35), 19, Color("#596f75"))
	draw_circle(pos + Vector2(45, 35), 8, Color("#b8c8bb"))
	draw_line(pos + Vector2(20, 52), pos + Vector2(63, 15), Color("#536972"), 6)
	draw_line(pos + Vector2(25, 20), pos + Vector2(45, 35), Color("#536972"), 6)
	draw_line(pos + Vector2(15, 18), pos + Vector2(35, 18), Color("#d3d5c0"), 6)
	draw_line(pos + Vector2(63, 15), pos + Vector2(80, 10), Color("#536972"), 5)
	draw_line(pos + Vector2(15, 55), pos + Vector2(75, 55), Color("#536972"), 5)
func _configure_rest_area() -> void:
	var first_wall: int = walls.get_child_count()
	var first_point: int = points.size()
	_configure_rest_area_layout()
	var shift := Vector2(-290, 0)
	for index in range(first_wall, walls.get_child_count()):
		walls.get_child(index).position += shift
	for index in range(first_point, points.size()):
		points[index]["pos"] += shift
	map_origin = Vector2(-1800, 0)
	map_size = Vector2(CAMPUS_RIGHT+1960, 2240)


func _draw_rest_area() -> void:
	draw_set_transform(Vector2(-290, 0))
	_draw_rest_area_layout()
	draw_set_transform(Vector2.ZERO)
	_draw_rest_steps()


func _office_furniture() -> Array[Dictionary]:
	# 草图：上部两列各两张电脑桌；左下沙发，右侧竖桌。
	var items: Array[Dictionary] = []
	for y in [120.0, 300.0]:
		for x in [180.0, 570.0]:
			items.append({
				"texture": OFFICE_SHEET, "region": Rect2(144, 384, 96, 72),
				"rect": Rect2(x, y, 160, 120),
				"collision": Rect2(x, y + 24, 160, 96)
			})
			items.append({
				"texture": OFFICE_SHEET, "region": Rect2(0, 288, 48, 48),
				"rect": Rect2(x + 56, y + 120, 48, 48),
				"collision": Rect2(x + 62, y + 126, 36, 36)
			})
	items.append({
		"texture": LIVINGROOM_SHEET, "region": Rect2(672, 64, 48, 128),
		"rect": Rect2(120, 420, 72, 192),
		"collision": Rect2(120, 430, 72, 170)
	})
	items.append({
		"texture": OFFICE_TABLE_SHEET, "region": Rect2(616, 480, 56, 144),
		"rect": Rect2(320, 440, 65.3333, 168),
		"collision": Rect2(320, 450, 65, 150)
	})
	return items


func _draw_office() -> void:
	_draw_empty_zone()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for y in range(80, 621, 60):
		draw_line(Vector2(80, y), Vector2(820, y), Color("#b9b5a9"), 1)
	for x in range(80, 821, 60):
		draw_line(Vector2(x, 80), Vector2(x, 620), Color("#b9b5a9"), 1)
	for item in _office_furniture():
		draw_texture_rect_region(item["texture"], item["rect"], item["region"])
func _draw_classroom_windows() -> void:
	# 窗户位于左墙；日光画在家具下方，避免遮挡人物与桌椅。
	for y in [180.0, 380.0, 580.0, 780.0, 980.0]:
		var beam := PackedVector2Array([
			Vector2(138, y + 26), Vector2(138, y + 110),
			Vector2(470, y + 182), Vector2(470, y + 62)
		])
		draw_polygon(beam, PackedColorArray([
			Color(1.0, 0.94, 0.70, 0.24 * classroom_daylight_strength), Color(1.0, 0.94, 0.70, 0.24 * classroom_daylight_strength),
			Color(1.0, 0.94, 0.70, 0.0), Color(1.0, 0.94, 0.70, 0.0)
		]))
		# 使用素材内的窗格投影，低透明度保留地板纹理。
		draw_texture_rect_region(
			WINDOW_LIGHT_SHEET, Rect2(140, y + 48, 280, 100),
			Rect2(10, 189, 38, 27), Color(1.0, 0.96, 0.76, 0.18 * classroom_daylight_strength)
		)
		draw_rect(Rect2(80, y + 8, 60, 112), Color("#69756e"))
		draw_texture_rect_region(
			PUBLIC_BUILDING_SHEET, Rect2(82, y + 8, 56, 112), Rect2(384, 12, 48, 60),
			Color(0.90, 0.96, 1.0)
		)
		draw_rect(Rect2(83, y + 120, 58, 8), Color("#d4d4bf"))

func _restroom_door_rect(index: int) -> Rect2:
	return Rect2(156 + index * 180, 430, 128, 16)


func _configure_teaching_restroom() -> void:
	map_size = Vector2(1600, 760)
	_empty_room_walls()
	for index in range(3):
		var x: float = 140 + index * 180
		_block(Rect2(x, 150, 160, 16))
		_block(Rect2(x, 150, 16, 320))
		_block(Rect2(x + 144, 150, 16, 320))
		_block(Rect2(x + 48, 220, 64, 120))
		restroom_doors_open.append(false)
		restroom_door_bodies.append(_block(_restroom_door_rect(index)))
		_point(Vector2(x + 80, 505), "打开隔间门", "restroom_stall_toggle", 48.0)
		points[-1]["stall_index"] = index
		points[-1]["interaction_rect"] = Rect2(x + 20, 365, 120, 160)
	for x in [784, 880]:
		_block(Rect2(x, 225, 48, 70))
	_block(Rect2(1110, 305, 288, 65))
	_point(Vector2(1460, 600), "返回本层走廊", "teaching_restroom_exit", 45.0)


func toggle_restroom_stall(index: int, local_player: Vector2) -> bool:
	if place != "教学楼男厕" or index < 0 or index >= restroom_doors_open.size():
		return false
	# 关闭前确认玩家已离开门扇，避免实体门在人物脚下生成。
	if restroom_doors_open[index] and _restroom_door_rect(index).grow(18).has_point(local_player):
		return false
	restroom_doors_open[index] = not restroom_doors_open[index]
	var collision: CollisionShape2D = restroom_door_bodies[index].get_child(0)
	collision.set_deferred("disabled", restroom_doors_open[index])
	for point in points:
		if point.get("stall_index", -1) == index:
			point["title"] = "关闭隔间门" if restroom_doors_open[index] else "打开隔间门"
	queue_redraw()
	return true

func _dorm_cabinets() -> Array[Rect2]:
	return [Rect2(780, 130, 72, 156), Rect2(860, 130, 72, 156), Rect2(940, 130, 72, 156)]

func _configure_night_lighting() -> void:
	if is_instance_valid(night_lighting):
		night_lighting.free()
	night_lighting = NIGHT_LIGHTING.new()
	night_lighting.name = "NightLighting"
	add_child(night_lighting)
	night_lighting.configure(self)
	night_lighting.set_strength(night_light_strength)

func _shop_furniture() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	# 1号：原素材中朝侧面的整张木柜台。
	items.append({"texture": OFFICE_TABLE_SHEET, "region": Rect2(616,480,56,144),
		"rect": Rect2(335,285,100,205), "collision": Rect2(335,300,100,190)})
	# 同规格货架排成对称布局：上下各四组，两侧各三组，间隔统一为16。
	# 素材格中的透明留白单独排除，让可见柜体边缘也严格对齐。
	for index in range(4):
		var top := Rect2(116+index*96,100,80,80)
		items.append({"texture":SHOPPING_SHEET,"region":_shop_goods_region(index%3,304),"rect":top,"collision":top})
		var bottom := Rect2(116+index*96,820,80,80)
		items.append({"texture":SHOPPING_SHEET,"region":_shop_goods_region(index%3,400,624),"rect":bottom,"collision":bottom})
	for index in range(3):
		var left := Rect2(116,532+index*96,80,80)
		items.append({"texture":SHOPPING_SHEET,"region":_shop_goods_region(index,400),"rect":left,"collision":left})
		var right := Rect2(404,532+index*96,80,80)
		items.append({"texture":SHOPPING_SHEET,"region":_shop_goods_region(index,496),"rect":right,"collision":right})
	return items

func _shop_goods_region(column: int, row: int, base_x: int = 480) -> Rect2:
	var padding_left: int = 5 if column == 0 else 0
	var width: int = 43 if column == 0 else (48 if column == 1 else 44)
	return Rect2(base_x+column*48+padding_left,row,width,48)

func _draw_shop_interior() -> void:
	_draw_empty_zone()
	for x in range(80,521,64):
		draw_line(Vector2(x,80),Vector2(x,920),Color("#b5b1a3"),1)
	for y in range(80,921,64):
		draw_line(Vector2(80,y),Vector2(520,y),Color("#b5b1a3"),1)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for item in _shop_furniture():
		draw_texture_rect_region(item["texture"],item["rect"],item["region"])

func campus_entrance_position(action: String) -> Vector2:
	match action:
		"white_house_enter": return Vector2(white_house.end.x+40,_white_house_door_y())
		"dorm_female": return Vector2(dorm.position.x-40,dorm.end.y-40)
		"dorm_male_enter": return Vector2(dorm.end.x+40,dorm.end.y-40)
		"meeting_room_enter": return Vector2(meeting_room.get_center().x,meeting_room.position.y-45)
		"small_canteen_enter": return Vector2(small_canteen.get_center().x,small_canteen.position.y-45)
		"shop_enter": return Vector2(shop.position.x-40,shop.position.y+215)
		"canteen_from_left": return Vector2(canteen.position.x-40,1780)
		"canteen_from_upper": return Vector2(canteen_notch().position.x+85,canteen_notch().end.y-40)
		"second_room_enter": return Vector2(second_room.position.x+100,second_room.position.y-40)
	return Vector2.ZERO

func dorm_exterior_footprint() -> Rect2:
	# 下方两层为建筑实体，上方三层是遮挡后方地面的立面。
	var pitch:float=(dorm.size.y-28.0)/5.0
	var top:float=dorm.position.y+28.0+pitch*3.0
	return Rect2(dorm.position.x,top,dorm.size.x,dorm.end.y-top)

func update_dorm_occlusion(player_at:Vector2) -> void:
	if not is_instance_valid(dorm_occluder):return
	var outside:bool=place in ["校园 G0","教学楼前平台","休息区"]
	dorm_occluder.visible=outside and player_at.y<dorm.end.y and dorm.grow(150).has_point(player_at)

func _draw_dorm_exterior(canvas:Node2D=null) -> void:
	var target:Node2D=self if canvas==null else canvas
	# 米黄色外墙，五层开敞走廊；窗户、栏杆和楼梯井按同一层高排布。
	target.draw_rect(Rect2(dorm.position+Vector2(6,8),dorm.size),Color("#69695e"))
	target.draw_rect(dorm,Color("#e8ddc0"))
	target.draw_rect(Rect2(dorm.position,Vector2(dorm.size.x,28)),Color("#9b8c6c"))
	target.draw_rect(Rect2(dorm.position+Vector2(0,28),Vector2(dorm.size.x,5)),Color("#fbf1d9"))
	target.draw_string(ThemeDB.fallback_font,dorm.position+Vector2(22,22),"宿舍 · 五层",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
	var pitch: float = (dorm.size.y-28)/5.0
	var stair_x: float = dorm.end.x-90
	for index in range(5):
		var top: float = dorm.position.y+28+index*pitch
		var wall_height: float = pitch*0.68
		target.draw_rect(Rect2(dorm.position.x+8,top,dorm.size.x-16,wall_height),Color("#eee3c7"))
		target.draw_line(Vector2(dorm.position.x+8,top+wall_height),Vector2(dorm.end.x-8,top+wall_height),Color("#a89b7b"),3)
		var window_count: int = maxi(1,int((dorm.size.x-207.0)/98.0)+1)
		for column in range(window_count):
			var x: float = dorm.position.x+35+column*98
			var window := Rect2(x,top+14,62,32)
			target.draw_rect(window.grow(3),Color("#8b8979"))
			target.draw_rect(window,Color("#b3d4dc"))
			target.draw_line(Vector2(x+31,top+14),Vector2(x+31,top+46),Color("#f3f2df"),2)
			target.draw_line(Vector2(x+3,top+17),Vector2(x+26,top+17),Color("#d5eef0"),2)
			target.draw_rect(Rect2(x-5,top+48,72,4),Color("#faf0d5"))
		target.draw_rect(Rect2(dorm.position.x+8,top+wall_height,dorm.size.x-16,pitch-wall_height),Color("#c9bd9d"))
		_stairs(Rect2(stair_x,top+7,66,wall_height+7),false,10,target)
		target.draw_rect(Rect2(stair_x-4,top+7,4,wall_height+7),Color("#827e6e"))
		target.draw_rect(Rect2(stair_x+66,top+7,4,wall_height+7),Color("#827e6e"))
		var rail_y: float = top+pitch-12
		target.draw_line(Vector2(dorm.position.x+10,rail_y),Vector2(dorm.end.x-10,rail_y),Color("#76766a"),2)
		for x in range(int(dorm.position.x)+16,int(dorm.end.x)-10,22):
			target.draw_line(Vector2(x,rail_y),Vector2(x,top+pitch-3),Color("#868476"),1)
		target.draw_rect(Rect2(dorm.position.x,top+pitch-4,dorm.size.x,4),Color("#f4e9ce"))
	for x in [dorm.position.x+4,dorm.end.x-8]:
		target.draw_rect(Rect2(x,dorm.position.y+28,4,dorm.size.y-28),Color("#b4a687"))
	# 两侧入口保留光圈，不增加门扇。
	target.draw_rect(Rect2(dorm.position.x-16,dorm.end.y-55,16,9),Color("#9f8d69"))
	target.draw_rect(Rect2(dorm.end.x,dorm.end.y-55,16,9),Color("#9f8d69"))

func _draw_rubber_surface(rect: Rect2, title: String) -> void:
	draw_rect(rect,Color("#276d9d"))
	draw_rect(rect.grow(-6),Color("#3289b6"))
	for y in range(int(rect.position.y)+12,int(rect.end.y)-6,16):
		draw_line(Vector2(rect.position.x+6,y),Vector2(rect.end.x-6,y),Color(0.6,0.85,0.95,0.07),1)
	_text(Vector2(rect.get_center().x-55,rect.position.y+30),title,22)

func outdoor_court_transform() -> Transform2D:
	# 整组以原羽毛球场左上角为锚点缩放，间隔、场线和球网一并缩小。
	return Transform2D(Vector2(OUTDOOR_COURT_SCALE,0),Vector2(0,OUTDOOR_COURT_SCALE),badminton_court.position*(1.0-OUTDOOR_COURT_SCALE)+Vector2(SIDE_STAIR_EXTRA,0)+COURT_OFFSET)

func _draw_blue_sports_courts(show_titles: bool = true) -> void:
	var court_transform: Transform2D = outdoor_court_transform()
	draw_set_transform(court_transform.origin,0,Vector2.ONE*OUTDOOR_COURT_SCALE)
	_draw_badminton_court(show_titles)
	_draw_basketball_court(show_titles)
	draw_set_transform(Vector2.ZERO)

func _draw_badminton_court(show_title: bool = true) -> void:
	_draw_rubber_surface(badminton_court, "羽毛球场" if show_title else "")
	var white := Color("#f3f9f9")
	var badminton := Rect2(1630,197,520,236)
	draw_rect(badminton,Color("#247daa"))
	draw_rect(badminton,white,false,3)
	var mid: Vector2 = badminton.get_center()
	for y in [badminton.position.y+18,badminton.end.y-18]:
		draw_line(Vector2(badminton.position.x,y),Vector2(badminton.end.x,y),white,2)
	for x in [badminton.position.x+30,mid.x-77,mid.x+77,badminton.end.x-30]:
		draw_line(Vector2(x,badminton.position.y),Vector2(x,badminton.end.y),white,2)
	draw_line(Vector2(badminton.position.x,mid.y),Vector2(mid.x-77,mid.y),white,2)
	draw_line(Vector2(mid.x+77,mid.y),Vector2(badminton.end.x,mid.y),white,2)
	# 网柱、网带和网眼，仅作场地装饰，可直接步行进入场地。
	draw_line(Vector2(mid.x,badminton.position.y-8),Vector2(mid.x,badminton.end.y+8),Color("#d9e3e4"),4)
	for y in range(int(badminton.position.y),int(badminton.end.y),12):
		draw_line(Vector2(mid.x-4,y),Vector2(mid.x+4,y+5),Color("#647e8c"),1)
	for y in [badminton.position.y-8,badminton.end.y+8]:
		draw_circle(Vector2(mid.x,y),5,Color("#687881"))
func _draw_basketball_court(show_title: bool = true) -> void:
	_draw_rubber_surface(basketball_court, "篮球场" if show_title else "")
	var white := Color("#f3f9f9")
	var basketball := Rect2(2270,120,720,390)
	draw_rect(basketball,Color("#287fae"))
	draw_rect(basketball,white,false,3)
	var center: Vector2 = basketball.get_center()
	draw_line(Vector2(center.x,basketball.position.y),Vector2(center.x,basketball.end.y),white,3)
	draw_arc(center,47,0,TAU,64,white,3)
	for left in [true,false]:
		var baseline: float = basketball.position.x if left else basketball.end.x
		var direction: float = 1.0 if left else -1.0
		var key_x: float = baseline if left else baseline-150
		draw_rect(Rect2(key_x,center.y-64,150,128),Color("#3794bc"))
		draw_rect(Rect2(key_x,center.y-64,150,128),white,false,3)
		var free_throw := Vector2(baseline+direction*150,center.y)
		draw_arc(free_throw,47,0,TAU,48,white,2)
		var basket := Vector2(baseline+direction*30,center.y)
		draw_arc(basket,174,-PI/2.0 if left else PI/2.0,PI/2.0 if left else 3.0*PI/2.0,64,white,3)
		for y in [center.y-174,center.y+174]:
			draw_line(Vector2(baseline,y),Vector2(basket.x,y),white,3)
		# 球架置于底线外，篮圈朝场内。
		var board_x: float = baseline-direction*13
		draw_line(Vector2(board_x,center.y-28),Vector2(board_x,center.y+28),Color("#edf3ee"),6)
		draw_line(Vector2(board_x,center.y),Vector2(baseline+direction*14,center.y),Color("#9ba9aa"),4)
		draw_arc(Vector2(baseline+direction*18,center.y),10,0,TAU,24,Color("#ef9e46"),3)

const DORM_RAIL_PITCH: float = 26.0
const DORM_RAIL_WIDTH: float = 3.0

func _dorm_scenery_transform() -> Transform2D:
	# 每升一层，围绕同一景观中心再缩小15%；三楼是原始大小的72.25%。
	var factor: float = pow(0.85, _dorm_floor_number() - 1)
	var center := Vector2(2230, -20)
	return Transform2D(0.0, Vector2.ONE * factor, 0.0, center * (1.0 - factor))

func _dorm_court_view_transform(court_index: int = 0) -> Transform2D:
	# 沿走廊视野依次为羽毛球场1290、篮球场1720、空地1290像素，即3:4:3。
	var court: Rect2 = badminton_court if court_index == 0 else basketball_court
	var target_width: float = 1290.0 if court_index == 0 else 1720.0
	var target_x: float = 80.0 if court_index == 0 else 1370.0
	var view_scale := Vector2(target_width / court.size.x, 480.0 / court.size.y)
	return _dorm_scenery_transform() * Transform2D(0.0, view_scale, 0.0, Vector2(target_x, -260) - court.position * view_scale)

func _draw_dorm_court_view() -> void:
	var scenery := Rect2(80, -300, 4300, 560)
	draw_rect(scenery, Color("#9dbb87") if _dorm_floor_number() == 1 else Color("#cbd0bd"))
	# 远处的灌木带和两侧草地，给蓝色场地留出柔和的绿色边缘。
	draw_rect(Rect2(80, -300, 4300, 28), Color("#82a575"))
	for x in range(110, 4380, 92):
		draw_circle(Vector2(x, -280), 20, Color("#8caf7c"))
	for index in range(2):
		var court: Rect2 = badminton_court if index == 0 else basketball_court
		var view_transform := _dorm_court_view_transform(index)
		draw_set_transform_matrix(view_transform)
		if index == 0:
			_draw_badminton_court(false)
		else:
			_draw_basketball_court(false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# 地面采用远景投影，文字保持正常比例。
		var label_at: Vector2 = view_transform * Vector2(court.get_center().x, court.position.y + 36)
		_text(label_at - Vector2(60, 0), "羽毛球场" if index == 0 else "篮球场", 24)
	# 右侧三成留作空白地，不放置球场或设施。
	draw_rect(_dorm_scenery_transform() * Rect2(3090, -260, 1290, 480), Color("#cbd0bd"))
	if _dorm_floor_number() == 3:
		_draw_dorm_white_house_quarter()
	# 栏外步道和矮花带，不占用室内走廊的可行走空间。
	draw_rect(Rect2(80, 220, 4300, 40), Color("#d9d9bc"))
	draw_line(Vector2(80, 221), Vector2(4380, 221), Color("#f3eed9"), 3)
	for x in range(105, 4380, 160):
		draw_line(Vector2(x, 225), Vector2(x + 12, 254), Color("#c3c9ae"), 1)
	# 室内夜晚仍明亮，栏外景色单独随时段变暗。
	var night: float = 1.0 - clampf(classroom_daylight_strength / 0.7, 0.0, 1.0)
	if night > 0.0:
		draw_rect(scenery, Color(0.07, 0.12, 0.22, night * 0.64))

func _dorm_soft_wall_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position + Vector2(0, rect.size.y * 2.0 / 3.0), Vector2(rect.size.x, rect.size.y / 3.0))

func _draw_dorm_soft_railing(rect: Rect2) -> void:
	# 下方三分之一是白墙；上方三分之二由细杆完整封闭。
	var wall := _dorm_soft_wall_rect(rect)
	var bar := Color("#e8e6d8")
	var shade := Color("#b1b8ab")
	var count: int = ceili(rect.size.x / DORM_RAIL_PITCH)
	for index in range(count + 1):
		var x: float = minf(rect.position.x + index * DORM_RAIL_PITCH, rect.end.x)
		draw_line(Vector2(x + 2, rect.position.y + 4), Vector2(x + 2, wall.position.y), shade, 2)
		draw_line(Vector2(x, rect.position.y + 4), Vector2(x, wall.position.y), bar, DORM_RAIL_WIDTH)
	draw_style_box(_dorm_rail_surface(), Rect2(rect.position, Vector2(rect.size.x, 7)))
	draw_rect(wall, Color("#f1f0e8"))
	draw_rect(Rect2(wall.position, Vector2(wall.size.x, 7)), Color("#fcfbf4"))
	draw_line(Vector2(wall.position.x, wall.position.y + 7), Vector2(wall.end.x, wall.position.y + 7), Color("#d6d8cc"), 2)
	draw_rect(Rect2(wall.position.x, wall.end.y - 8, wall.size.x, 8), Color("#deded1"))

func _dorm_rail_surface() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ede8d7")
	style.set_corner_radius_all(3)
	return style
func _dorm_visible_white_house() -> Rect2:
	# 白房在广场左上方；三楼视野只露出屋顶右上角的四分之一。
	var full_roof := Rect2(-120, 110, 400, 220)
	return full_roof.intersection(Rect2(80, -300, 4300, 520))

func _draw_dorm_white_house_quarter() -> void:
	var roof := _dorm_visible_white_house()
	draw_rect(roof, Color("#e3e9e5"))
	draw_rect(Rect2(roof.position, Vector2(roof.size.x, 9)), Color("#f7faf3"))
	draw_rect(Rect2(roof.end.x - 9, roof.position.y, 9, roof.size.y), Color("#adbcb7"))
	draw_line(roof.position, Vector2(roof.end.x, roof.position.y), Color("#7e908b"), 3)
	draw_line(Vector2(roof.end.x, roof.position.y), roof.end, Color("#7e908b"), 3)
	# 小型屋顶通风口帮助辨识建筑，不新增入口或碰撞。
	draw_rect(Rect2(225, 135, 30, 22), Color("#bccac5"))
	for y in range(139, 155, 4):
		draw_line(Vector2(229, y), Vector2(251, y), Color("#8d9e98"), 1)
	_text(Vector2(115, 180), "白房", 22)
func _teaching_inner_hall_floors() -> Array[Rect2]:
	return [Rect2(200, 520, 240, 500), Rect2(400, 180, 360, 520), Rect2(290, 1020, 60, 60)]

func _configure_teaching_inner_hall() -> void:
	map_size = Vector2(900, 1120)
	# 按草图围出下方窄走道和右上方空间，转角保持180像素宽的连接面。
	for wall in [Rect2(0, 0, 900, 180), Rect2(0, 180, 400, 340),
		Rect2(0, 520, 200, 600), Rect2(760, 180, 140, 940),
		Rect2(440, 700, 320, 420), Rect2(200, 1020, 90, 100),
		Rect2(350, 1020, 90, 100), Rect2(290, 1080, 60, 40)]:
		_block(wall)
	_block(Rect2(214, 840, 56, 80))
	for door in [{"pos": Vector2(450, 210), "title": "上侧左门 · 暂不开放"},
		{"pos": Vector2(670, 210), "title": "上侧右门 · 暂不开放"},
		{"pos": Vector2(725, 370), "title": "右侧门 · 暂不开放"}]:
		_point(door.pos, door.title, "room_closed", 42.0)
		points[-1]["show_ring"] = false
	_point(Vector2(300, 880), "查看电话", "teaching_hall_phone", 42.0)
	points[-1]["show_ring"] = false
	auto_transitions.append({"rect": Rect2(290, 1030, 60, 45), "target": "教学楼前平台", "spawn": Vector2(1120, 1200)})

func _draw_teaching_inner_hall() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("#cbd0c6"))
	for floor_rect in _teaching_inner_hall_floors():
		draw_rect(floor_rect, Color("#d9d4c5"))
		for x in range(int(floor_rect.position.x), int(floor_rect.end.x), 60):
			draw_line(Vector2(x, floor_rect.position.y), Vector2(x, floor_rect.end.y), Color("#c2c0b1"), 1)
		for y in range(int(floor_rect.position.y), int(floor_rect.end.y), 60):
			draw_line(Vector2(floor_rect.position.x, y), Vector2(floor_rect.end.x, y), Color("#c2c0b1"), 1)
	# 浅色墙面与踢脚线顺着折角连续绘制。
	draw_rect(Rect2(400, 100, 360, 80), Color("#eeeee2"))
	for edge in [[Vector2(200, 1020), Vector2(200, 520)],
		[Vector2(200, 520), Vector2(400, 520)], [Vector2(400, 520), Vector2(400, 180)],
		[Vector2(400, 180), Vector2(760, 180)], [Vector2(760, 180), Vector2(760, 700)],
		[Vector2(760, 700), Vector2(440, 700)], [Vector2(440, 700), Vector2(440, 1020)],
		[Vector2(200, 1020), Vector2(290, 1020)], [Vector2(350, 1020), Vector2(440, 1020)]]:
		draw_line(edge[0], edge[1], Color("#8c9c91"), 7)
	for x in [450.0, 670.0]:
		draw_rect(Rect2(x - 30, 98, 60, 82), Color("#66574a"))
		draw_rect(Rect2(x - 26, 102, 52, 78), Color("#dddcd1"))
		draw_rect(Rect2(x - 22, 108, 44, 27), Color("#aac7cc"))
		draw_rect(Rect2(x - 26, 170, 52, 10), Color("#6c989e"))
		draw_circle(Vector2(x + 18, 153), 2, Color("#4b4b47"))
	# 右墙的门沿侧墙放置，封闭状态与上侧两门一致。
	draw_rect(Rect2(754, 330, 20, 80), Color("#66574a"))
	draw_rect(Rect2(758, 334, 12, 72), Color("#dddcd1"))
	draw_rect(Rect2(758, 338, 12, 24), Color("#aac7cc"))
	draw_circle(Vector2(760, 391), 2, Color("#4b4b47"))
	# 与宿舍同款完整壁挂电话，放在入口左侧。
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	draw_rect(Rect2(214, 840, 56, 80), Color("#b5bdb4"))
	draw_texture_rect_region(HOUSE_ANIMATIONS_SHEET, Rect2(202, 826, 88, 88), Rect2(432, 192, 48, 48))
	_text(Vector2(215, 940), "电话", 20)
	_text(Vector2(445, 260), "教学楼一楼 · 楼内走廊", 20)
	_text(Vector2(372, 1055), "↓ 返回一楼平台", 18)
func teaching_class_number(floor_number: int, left_class: bool) -> int:
	var right_class: int = 9 if floor_number == 1 else (floor_number - 2) * 2 + 1
	return right_class + (1 if left_class else 0)

func toggle_dorm_cabinet() -> void:
	dorm_cabinet_revealed = not dorm_cabinet_revealed
	for point in points:
		if point.action == "dorm_cabinet_reveal":
			point.title = "恢复柜子上层" if dorm_cabinet_revealed else "查看柜子和台面"
	queue_redraw()

func _draw_cabinet_doors(rect: Rect2, count: int, color: Color) -> void:
	draw_rect(rect, color.darkened(0.15))
	var width: float = rect.size.x / count
	for index in range(count):
		var door := Rect2(rect.position + Vector2(index * width + 3, 3), Vector2(width - 6, rect.size.y - 6))
		draw_rect(door, color)
		draw_rect(door, color.lightened(0.15), false, 2)
		draw_line(door.position + Vector2(door.size.x - 9, door.size.y * 0.45), door.position + Vector2(door.size.x - 9, door.size.y * 0.65), Color(0.35, 0.38, 0.34, color.a), 3)

func _dorm_cabinet_stack_rect() -> Rect2:
	return Rect2(790, 80, 230, 430)

func _draw_dorm_cabinet_stack() -> void:
	var footprint := _dorm_cabinet_stack_rect()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	draw_rect(Rect2(footprint.position + Vector2(3,5), footprint.size), Color(0.2,0.20,0.15,0.13))
	# 左面朝向人物，但画面只展示柜体侧板，不绘制门、抽屉或把手。
	# 内部结构在正常状态下被侧板遮挡；透视上两层后露出台面。
	draw_rect(Rect2(800,88,210,260), Color("#dfcfb2"))
	draw_rect(Rect2(800,90,210,45), Color("#b79b75"))
	draw_rect(Rect2(800,300,210,48), Color("#b79b75"))
	draw_rect(Rect2(802,260,202,35), Color("#f1dfbc"))
	draw_line(Vector2(802,260), Vector2(1004,260), Color("#997746"), 3)
	# 原版卧室图中完整的无把手侧柜，双份并排，形成两层厚度。
	var source := Rect2(672,384,24,224)
	var panel_width: float = footprint.size.x / 2.0
	for index in range(2):
		var x: float = footprint.position.x + index * panel_width
		if dorm_cabinet_revealed:
			var split: float = 270.0 / footprint.size.y
			draw_texture_rect_region(preload("res://scripts/cabinet_palette.gd").texture(), Rect2(x,80,panel_width,270), Rect2(source.position,Vector2(source.size.x,source.size.y*split)), Color(1,1,1,0.14))
			draw_texture_rect_region(preload("res://scripts/cabinet_palette.gd").texture(), Rect2(x,350,panel_width,160), Rect2(source.position+Vector2(0,source.size.y*split),Vector2(source.size.x,source.size.y*(1.0-split))))
		else:
			draw_texture_rect_region(preload("res://scripts/cabinet_palette.gd").texture(), Rect2(x,80,panel_width,430), source)
	# 三层接缝在侧面也清楚可见，避免将上、中两层画成一整块。
	for y in [200,350]:
		draw_line(Vector2(790,y), Vector2(1020,y), Color("#8d8063"), 3)
		draw_line(Vector2(790,y+3), Vector2(1020,y+3), Color("#ded0ac"), 2)
	_text(Vector2(800,66), "柜子堆 · 中层透视" if dorm_cabinet_revealed else "三层柜子堆", 20)

func _draw_dorm_basin(rect: Rect2, laundry: bool) -> void:
	draw_rect(rect, Color("#829c9b"))
	draw_rect(rect.grow(-12), Color("#edf1e9"))
	var bowl := rect.grow(-27)
	draw_rect(bowl, Color("#adcfd2"))
	draw_circle(bowl.get_center(), 6, Color("#718e92"))
	var faucet := rect.position + Vector2(rect.size.x * 0.55, 14)
	draw_line(faucet, faucet + Vector2(-8, 22), Color("#71868c"), 6)
	if laundry:
		for index in range(5):
			draw_line(rect.position + Vector2(16, 39 + index * 16), rect.position + Vector2(38, 45 + index * 16), Color("#c6d5cf"), 3)

func _configure_dorm_wet_room() -> void:
	# 保留原镜头取景尺寸，将房间实际几何居中缩为六成。
	map_size = Vector2(780, 700)
	var first_wall:int=walls.get_child_count()
	var first_point:int=points.size()
	_empty_room_walls()
	_point(Vector2(390, 580), "开门返回宿舍", "dorm_wet_exit", 48.0)
	if place == "宿舍厕所":
		_block(Rect2(300, 245, 180, 230))
	else:
		_block(Rect2(100, 100, 95, 75))

	var room_transform:Transform2D=dorm_wet_room_transform()
	for i in range(first_wall,walls.get_child_count()):
		var body:StaticBody2D=walls.get_child(i)
		body.position=room_transform*body.position
		var collision:CollisionShape2D=body.get_child(0)
		collision.shape.size*=DORM_WET_ROOM_SCALE
	for i in range(first_point,points.size()):
		points[i]["pos"]=room_transform*points[i]["pos"]
		points[i]["radius"]*=DORM_WET_ROOM_SCALE

func dorm_wet_room_transform() -> Transform2D:
	return Transform2D(Vector2(DORM_WET_ROOM_SCALE,0),Vector2(0,DORM_WET_ROOM_SCALE),Vector2(780,700)*(1.0-DORM_WET_ROOM_SCALE)*0.5)

func dorm_wet_room_spawn() -> Vector2:
	return dorm_wet_room_transform()*Vector2(390,530)


func _draw_dorm_wet_room() -> void:
	var room_transform:Transform2D=dorm_wet_room_transform()
	draw_set_transform(room_transform.origin,0,Vector2.ONE*DORM_WET_ROOM_SCALE)
	_draw_dorm_wet_room_unscaled()
	draw_set_transform(Vector2.ZERO)

func _draw_dorm_wet_room_unscaled() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("#dce3dc"))
	draw_rect(Rect2(80, 80, 620, 540), Color("#bfceca"))
	for x in range(80, 701, 60):
		draw_line(Vector2(x, 80), Vector2(x, 620), Color("#a6b9b4"), 1)
	for y in range(80, 621, 60):
		draw_line(Vector2(80, y), Vector2(700, y), Color("#a6b9b4"), 1)
	draw_rect(Rect2(350, 602, 80, 36), Color("#766b59"))
	draw_rect(Rect2(354, 606, 72, 28), Color("#dfddcb"))
	draw_circle(Vector2(416, 619), 3, Color("#7e735b"))
	_text(Vector2(460, 600), "门 · 返回宿舍", 21)
	if place == "宿舍洗澡间":
		_text(Vector2(310, 60), "洗澡间", 25)
		draw_rect(Rect2(100, 100, 95, 75), Color("#af9e83"))
		_text(Vector2(108, 93), "衣架", 19)
		for x in [120, 146, 172]:
			draw_arc(Vector2(x, 132), 10, 0, PI, 12, Color("#6d7a76"), 3)
		draw_line(Vector2(585, 120), Vector2(585, 160), Color("#718a8f"), 8)
		draw_line(Vector2(585, 160), Vector2(550, 185), Color("#718a8f"), 8)
		draw_circle(Vector2(545, 190), 17, Color("#94afb5"))
		for index in range(5):
			draw_line(Vector2(520 + index * 14, 216), Vector2(510 + index * 14, 248), Color("#8dbac9"), 2)
	else:
		_text(Vector2(310, 60), "厕所", 25)
		draw_rect(Rect2(600, 95, 85, 60), Color("#82969a"))
		draw_rect(Rect2(606, 101, 73, 48), Color("#bddfe2"))
		draw_line(Vector2(642, 101), Vector2(642, 149), Color("#f4f3e9"), 3)
		# 蹲便器：两侧踏板，中间纵向便槽。
		draw_rect(Rect2(300, 245, 180, 230), Color("#f2f3e9"))
		draw_style_box(_dorm_rail_surface(), Rect2(351, 272, 78, 170))
		draw_rect(Rect2(366, 285, 48, 140), Color("#9bbab9"))
		for y in range(270, 455, 25):
			draw_line(Vector2(315, y), Vector2(340, y), Color("#c2cdc5"), 3)
			draw_line(Vector2(440, y), Vector2(465, y), Color("#c2cdc5"), 3)
