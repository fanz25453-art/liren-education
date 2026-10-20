extends Node2D

@export var cb_portrait: Texture2D

# 室外总面积倍率；长宽分别乘以平方根，人物大小不变。
@export_range(1.0, 4.0, 0.05) var outdoor_area_multiplier: float = 1.25
@export_range(0.5, 3.0, 0.05) var outdoor_zoom_multiplier: float = 1.25

@onready var map = $Map
@onready var player = $Player
@onready var player_sprite_base_scale: Vector2 = $Player/AnimatedSprite2D.scale
@onready var player_sprite_base_position: Vector2 = $Player/AnimatedSprite2D.position
@onready var player_name_base_position: Vector2 = $Player/NameLabel.position
@onready var npc = $NPC
@onready var office_npc = $LLX
@onready var shop_merchant = $ShopMerchant
var dialogue_speaker: String = ""
@onready var camera: Camera2D = $Player/Camera2D
@onready var hud: Label = $HUD/StatusLabel

const TIME_TINTS := [Color(0.98, 0.99, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 0.88, 0.68), Color(0.30, 0.33, 0.40)]
# 夜间室内使用暖白灯光，保留充足亮度；开放平台、外走廊仍使用室外夜色。
const INDOOR_NIGHT_TINT := Color(0.96, 0.91, 0.82)
const INDOOR_PLACES := [
	"教学楼男厕", "二层第一教室", "一楼办公室", "教学楼一楼内走廊", "食堂内部",
	"二号空房间", "小卖部内部", "白房内部", "宿舍一楼小房间",
	"男生宿舍内部", "男生宿舍 F2", "男生宿舍 F3",
	"宿舍尽头房间一", "宿舍尽头房间二", "宿舍洗澡间", "宿舍厕所"
]
const TIME_DAYLIGHT := [0.9, 1.0, 0.7, 0.0]
var world_time_tint: CanvasModulate
var time_tint_tween: Tween
var day_cycle = preload("res://scripts/day_cycle.gd").new()
var time_label: Label
var bed_visit_rest_used: bool = false
var active_bed_ladder: Node2D
var bed_transition_busy: bool = false
var bed_ladder_tween: Tween
var bed_saved_z_index: int = 0
var game_menu: CanvasLayer
var debug_panel: CanvasLayer
var cabinet_view: CanvasLayer
var football_invite: CanvasLayer
var football_game: CanvasLayer
var wqy: StaticBody2D
var place: String = ""
var dorm_transition_cooldown: float = 0.0
var dorm_small_room_return := Vector2(4480, 310)
var dorm_wet_return_room: String = "宿舍尽头房间一"
var dorm_wet_return_position := Vector2(715, 1245)
var teaching_restroom_return_floor: int = 1
var message: String = ""
# 饭票按日期和时段记录，切换地图不会重置。
var meal_slot: String = ""
var meal_taken: bool = false
var completed_meals: Dictionary = {}
var meal_seated: bool = false
var meal_dialogue_active: bool = false
var meal_return_position: Vector2
var meal_saved_sprite_position: Vector2
var meal_saved_facing: String

var dialogue_lines: PackedStringArray = []
var dialogue_index: int = 0

var dialogue_box: PanelContainer
var dialogue_text: Label
var dialogue_footer: Label
var dialogue_height: float = 280.0

var noticeboard_view: Control
var portrait_frame: PanelContainer
var portrait_image: TextureRect


func _ready() -> void:
	_setup_dialogue()
	_setup_noticeboard()
	_setup_time_ui()
	_setup_meal_seat_animation()
	_setup_time_tint()
	day_cycle.changed.connect(_sync_time_points)
	game_menu = load("res://scripts/rpg_menu.gd").new()
	add_child(game_menu)
	game_menu.menu_state_changed.connect(_sync_player_controls)
	debug_panel = load("res://scripts/debug_panel.gd").new()
	add_child(debug_panel)
	debug_panel.panel_state_changed.connect(_sync_player_controls)
	cabinet_view = load("res://scripts/cabinet_view.gd").new()
	add_child(cabinet_view)
	cabinet_view.view_state_changed.connect(_sync_player_controls)
	wqy = load("res://scenes/characters/npc.tscn").instantiate()
	wqy.name = "WQY"
	wqy.display_name = "wqy"
	wqy.idle_animation = &"idle_down"
	add_child(wqy)
	football_invite = load("res://scripts/football_invite.gd").new()
	add_child(football_invite)
	football_invite.state_changed.connect(_sync_player_controls)
	football_invite.answered.connect(_on_football_invite_answered)
	football_game = load("res://scripts/dorm_football.gd").new()
	add_child(football_game)
	football_game.state_changed.connect(_sync_player_controls)
	_load_place("校园 G0", Vector2(580, 2020))


func _process(_delta: float) -> void:
	dorm_transition_cooldown = maxf(dorm_transition_cooldown - _delta, 0.0)
	_update_dorm_stairs()
	_update_teaching_passage()
	_update_dialogue()
	_update_time_ui()

	if place in ["教学楼 F2", "教学楼 F3", "教学楼 F4", "教学楼 F5", "教学楼男厕", "食堂内部", "二号空房间", "小卖部内部", "白房内部", "宿舍一楼小房间", "宿舍洗澡间", "宿舍厕所", "二层第一教室", "一楼办公室"]:
		_frame_area()

	_sync_player_controls()

	var hint := "靠近门或可交互物品，按 E 互动"
	if place in ["男生宿舍内部", "男生宿舍 F2", "男生宿舍 F3"]:
		hint = "走上右端楼梯自动换层，房门按 E 互动"
	var nearby := _nearest_point()

	if not nearby.is_empty():
		hint = "E：" + str(nearby["title"])

	if not message.is_empty():
		hint = "对话中，按 E 继续"

	if noticeboard_view.visible:
		hint = "查看布告板中，按 E 关闭"
	if bed_transition_busy:
		hint = "正在沿梯子上下床……"

	var area_name: String = place
	if place == "男生宿舍内部":
		area_name = "男生宿舍 F1 · 长走廊"

	if place in ["教学楼前平台", "休息区"]:
		area_name = "休息区" if map.to_local(player.global_position).x < -225.0 else "教学楼 F1 · 开放平台"
	elif place == "二层第一教室":
		area_name = "二层 · cb 教室"

	hud.text = (
		player.display_name
		+ "  |  "
		+ area_name
		+ "\n方向键 / WASD 移动，E 互动\nX 菜单 · G 手表 · = 调试\n"
		+ hint
	)


func _setup_dialogue() -> void:
	# 优先使用检查器指定的头像，否则读取默认文件。
	if cb_portrait == null:
		if ResourceLoader.exists("res://assets/portraits/cb.jpg"):
			cb_portrait = load(
				"res://assets/portraits/cb.jpg"
			) as Texture2D

	dialogue_box = PanelContainer.new()
	dialogue_box.name = "DialogueBox"
	$HUD.add_child(dialogue_box)

	dialogue_box.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_WIDE
	)
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.97)
	style.border_color = Color("#aebdb5")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	dialogue_box.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)

	dialogue_box.add_child(margin)

	# 左侧头像，右侧台词。
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)

	portrait_frame = PanelContainer.new()
	portrait_frame.name = "Portrait"
	portrait_frame.custom_minimum_size = Vector2(200, 0)

	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color("#202a31")
	portrait_style.border_color = Color("#71857b")
	portrait_style.set_border_width_all(2)

	portrait_frame.add_theme_stylebox_override(
		"panel",
		portrait_style
	)
	row.add_child(portrait_frame)

	portrait_image = TextureRect.new()
	portrait_image.texture = cb_portrait
	portrait_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait_image)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	row.add_child(column)

	dialogue_text = Label.new()
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_text.add_theme_font_size_override("font_size", 32)
	column.add_child(dialogue_text)

	dialogue_footer = Label.new()
	dialogue_footer.text = "E  关闭对话"
	dialogue_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialogue_footer.add_theme_font_size_override("font_size", 22)
	dialogue_footer.add_theme_color_override(
		"font_color",
		Color("#b8c7be")
	)
	column.add_child(dialogue_footer)

	dialogue_box.hide()


func _update_dialogue() -> void:
	dialogue_height = clampf(
		get_viewport_rect().size.y * 0.23,
		180.0,
		340.0
	)

	dialogue_box.offset_left = 36.0
	dialogue_box.offset_right = -36.0
	dialogue_box.offset_top = -dialogue_height - 24.0
	dialogue_box.offset_bottom = -24.0

	dialogue_box.visible = not message.is_empty()
	dialogue_text.text = message

	portrait_image.texture = cb_portrait
	portrait_frame.custom_minimum_size.x = maxf(
		(dialogue_height - 48.0) * 0.75,
		90.0
	)

	portrait_frame.visible = (
		not message.is_empty()
		and message.begins_with(npc.display_name + "：")
		and cb_portrait != null
	)

	if dialogue_lines.is_empty():
		dialogue_footer.text = "E  关闭对话"
	elif dialogue_index + 1 < dialogue_lines.size():
		dialogue_footer.text = "E  继续  （%d / %d）" % [
			dialogue_index + 1,
			dialogue_lines.size()
		]
	else:
		dialogue_footer.text = "E  结束对话  （%d / %d）" % [
			dialogue_index + 1,
			dialogue_lines.size()
		]


func _start_cb_dialogue() -> void:
	_start_npc_dialogue(npc)


func _start_npc_dialogue(speaker: Node) -> void:
	dialogue_lines.clear()
	dialogue_index = 0

	# Dialogue 中每个实际换行代表下一段，空行会跳过。
	dialogue_speaker = speaker.display_name
	for line in speaker.dialogue.split("\n"):
		var text: String = line.strip_edges()

		if not text.is_empty():
			dialogue_lines.append(text)

	if dialogue_lines.is_empty():
		dialogue_lines.append("……")

	message = dialogue_speaker + "：" + dialogue_lines[0]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			_interact()
		elif event.physical_keycode == KEY_Q and is_instance_valid(active_bed_ladder) and message.is_empty() and not noticeboard_view.visible:
			_start_bed_climb(active_bed_ladder, false)


func _nearest_point() -> Dictionary:
	if bed_transition_busy:
		return {}
	if is_instance_valid(active_bed_ladder):
		var rest_point := _current_bed_rest_point()
		if not rest_point.is_empty():
			rest_point = rest_point.duplicate()
			rest_point["title"] += "（Q 下床）"
			return rest_point
		return {"title": "沿梯子下床", "action": "bed_ladder_down"}
	var result: Dictionary = {}
	var best_distance: float = INF
	var candidates: Array[Dictionary] = map.points.duplicate()

	if npc.visible:
		candidates.append({
			"pos": npc.global_position,
			"title": "与 " + npc.display_name + " 对话",
			"action": "cb",
			"radius": 80.0
		})

	if office_npc.visible:
		candidates.append({
			"pos": office_npc.global_position,
			"title": "与 llx 对话", "action": "llx", "radius": 85.0
		})

	if wqy != null and wqy.visible:
		candidates.append({"pos": wqy.global_position, "title": "与 wqy 对话", "action": "wqy", "radius": 85.0})

	for point in candidates:
		if not point.get("enabled", true):
			continue
		var target: Vector2 = point["pos"]
		var radius: float = float(point.get("radius", 80.0))
		if str(point["action"]) not in ["cb", "llx", "wqy"]:
			if point.has("interaction_rect"):
				var area: Rect2 = point["interaction_rect"]
				var local_player: Vector2 = map.to_local(player.global_position)
				target = Vector2(
					clampf(local_player.x, area.position.x, area.end.x),
					clampf(local_player.y, area.position.y, area.end.y)
				)
			target = map.to_global(target)
			radius *= map.global_scale.x
		var distance: float = player.global_position.distance_to(target)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			result = point
	return result


func _interact() -> void:
	if bed_transition_busy or (debug_panel != null and debug_panel.is_open()):
		return
	if noticeboard_view.visible:
		noticeboard_view.hide()
		player.movement_enabled = true
		return
	# 正在对话时，E 优先推进台词。
	if not message.is_empty():
		if (
			not dialogue_lines.is_empty()
			and dialogue_index + 1 < dialogue_lines.size()
		):
			dialogue_index += 1
			message = (
				dialogue_speaker
				+ "："
				+ dialogue_lines[dialogue_index]
			)
		else:
			message = ""
			dialogue_lines.clear()
			dialogue_index = 0
			_end_meal_seating()
			meal_dialogue_active = false

		_sync_player_controls()
		_update_dialogue()
		return

	var point := _nearest_point()

	if point.is_empty():
		return

	var action: String = point["action"]

	match action:
		"canteen_take_meal", "canteen_eat_meal":
			_use_canteen_meal(action)

		"time_classroom":
			_advance_day_period("classroom")

		"time_rest_noon":
			_advance_day_period("rest", 1)

		"time_rest_night":
			_advance_day_period("rest", 3)
		"bed_ladder_up":
			_start_bed_climb(point["ladder"], true)

		"bed_ladder_down":
			_start_bed_climb(active_bed_ladder, false)
		"rest_dorm_locked":
			message = "这边是宿舍，暂时不能进入。"

		"noticeboard":
			noticeboard_view.show()

		"left_up":
			_load_place("教学楼前平台", Vector2(640, 1355))

		"right_up":
			_load_place("教学楼前平台", Vector2(1120, 1355))

		"left_down":
			_load_place("校园 G0", Vector2(640, 1515))

		"right_down":
			_load_place("校园 G0", Vector2(1120, 1515))

		"side_up":
			_load_place("教学楼前平台", Vector2(1360, 1290))

		"side_down":
			_load_place("校园 G0",Vector2(1690+map.SIDE_STAIR_EXTRA,1290))

		"teaching_west_up":
			_enter_teaching_west_floor(map._teaching_floor_number() + 1)

		"teaching_west_down":
			_enter_teaching_west_floor(map._teaching_floor_number() - 1)

		"teaching_up":
			_enter_teaching_floor(map._teaching_floor_number() + 1)

		"teaching_down":
			_enter_teaching_floor(map._teaching_floor_number() - 1)

		"teaching_restroom":
			var floor_number: int = int(point["floor"])
			if floor_number % 2 == 0:
				message = "这是女厕所，仅限女生进入。"
			else:
				teaching_restroom_return_floor = floor_number
				_load_place("教学楼男厕", Vector2(1430, 600))

		"restroom_stall_toggle":
			if not map.toggle_restroom_stall(int(point["stall_index"]), map.to_local(player.global_position)):
				message = "请先离开门口，再关闭隔间门。"

		"teaching_restroom_exit":
			if teaching_restroom_return_floor == 1:
				_load_place("教学楼前平台", Vector2(1240, 1200))
			else:
				var top: float = map.teaching_top_for_floor(teaching_restroom_return_floor)
				_load_place("教学楼 F%d" % teaching_restroom_return_floor, Vector2(1240, top + 130))

		"teaching_water":
			message = "这里可以装水。"

		"upstairs":
			_load_place("教学楼 F2", Vector2(1000, 416))

		"up_to_f3":
			_load_place("教学楼 F3", Vector2(1000, 236))

		"down_to_f2":
			_load_place("教学楼 F2", Vector2(1000, 416))

		"downstairs":
			_load_place("教学楼前平台", Vector2(1000, 1200))

		"classroom_front":
			_load_place("二层第一教室", Vector2(1120, 280))

		"classroom_back":
			_load_place("二层第一教室", Vector2(1120, 1100))

		"exit_classroom_front":
			_load_place("教学楼 F2", Vector2(660, 410))

		"exit_classroom_back":
			_load_place("教学楼 F2", Vector2(510, 410))

		"office_enter":
			_load_place("一楼办公室", Vector2(450, 530))

		"office_exit":
			_load_place("教学楼前平台", Vector2(870, 1225))

		"teaching_hall_phone":
			message = "电话功能暂未开放。"

		"room_closed":
			message = str(point["title"]) + "暂未开放。"

		"shop_merchant":
			_start_npc_dialogue(shop_merchant)

		"wqy":
			football_invite.open()

		"llx":
			_start_npc_dialogue(office_npc)

		"cb":
			_start_cb_dialogue()

		"white_house_enter":
			_load_place("白房内部", Vector2(770, 350))

		"white_house_exit":
			_load_place("校园 G0",map.campus_entrance_position("white_house_enter")+Vector2(20,0))

		"dorm_female":
			message = "此入口仅限女生进入，请从右侧男生宿舍入口进入。"

		"dorm_small_room_enter":
			dorm_small_room_return = Vector2(4480, 310)
			_load_place("宿舍一楼小房间", Vector2(350, 390))

		"dorm_left_small_room_enter":
			dorm_small_room_return = Vector2(-180, 310)
			_load_place("宿舍一楼小房间", Vector2(350, 390))

		"dorm_small_room_exit":
			_load_place("男生宿舍内部", dorm_small_room_return)

		"dorm_left_stairs_locked":
			message = "铁门锁着，楼梯暂不开放。"

		"dorm_male_enter":
			_load_place("男生宿舍内部", Vector2(4690, 560))

		"dorm_male_exit":
			_load_place("校园 G0", map.campus_entrance_position("dorm_male_enter")+Vector2(20,0))

		"dorm_cabinet_reveal":
			cabinet_view.open()

		"dorm_shower_enter", "dorm_toilet_enter":
			dorm_wet_return_room = place
			dorm_wet_return_position = Vector2(715, 1245) if action == "dorm_shower_enter" else Vector2(715, 1555)
			_load_place("宿舍洗澡间" if action == "dorm_shower_enter" else "宿舍厕所", Vector2(390, 530))

		"dorm_wet_exit":
			_load_place(dorm_wet_return_room, dorm_wet_return_position)

		"dorm_room_one":
			_load_place("宿舍尽头房间一", Vector2(550, 200))

		"dorm_room_two":
			_load_place("宿舍尽头房间二", Vector2(550, 200))

		"dorm_room_one_exit":
			_load_place("男生宿舍 F3", Vector2(260, 410))

		"dorm_room_two_exit":
			_load_place("男生宿舍 F3", Vector2(600, 410))

		"dorm_room_closed":
			message = "这是别人的宿舍，不能进入。"

		"second_room_enter":
			_load_place("二号空房间", Vector2(160, 190))

		"second_room_exit":
			_load_place("校园 G0", map.campus_entrance_position("second_room_enter")+Vector2(0,-20))

		"shop_enter":
			_load_place("小卖部内部", Vector2(190, 500))

		"shop_exit":
			_load_place("校园 G0", map.campus_entrance_position("shop_enter")+Vector2(-20,0))

		"canteen_from_left":
			_load_place("食堂内部", Vector2(180, 500))

		"canteen_from_upper":
			_load_place("食堂内部", Vector2(1150, 180))

		"canteen_exit_left":
			_load_place("校园 G0", Vector2(1370, 1780))

		"canteen_exit_upper":
			_load_place("校园 G0", map.campus_entrance_position("canteen_from_upper")+Vector2(0,-20))


	_sync_player_controls()
	_update_dialogue()


func _load_place(next_place: String, spawn: Vector2) -> void:
	if cabinet_view != null: cabinet_view.close()
	if football_invite != null: football_invite.close()
	if football_game != null: football_game.close()
	_end_meal_seating()
	meal_dialogue_active = false
	_reset_bed_climb()
	if next_place == "教学楼 F1":
		next_place = "教学楼前平台"

	noticeboard_view.hide()
	place = next_place
	dorm_transition_cooldown = 0.6
	message = ""
	dialogue_lines.clear()
	dialogue_index = 0

	map.configure(place)
	npc.set_active(place == "二层第一教室")
	office_npc.set_active(place == "一楼办公室")
	shop_merchant.set_active(place == "小卖部内部")
	wqy.set_active(place == "宿舍尽头房间一")

	var outside: bool = place in ["校园 G0", "教学楼前平台", "休息区"]
	var world_scale: float = sqrt(outdoor_area_multiplier) if outside else 1.0
	map.scale = Vector2.ONE * world_scale
	npc.global_position = map.to_global(Vector2(935, 1120))
	office_npc.global_position = map.to_global(Vector2(260, 274))
	shop_merchant.global_position = map.to_global(Vector2(480, 390))
	wqy.global_position = map.to_global(Vector2(590, 235))
	_apply_player_place_size()
	player.position = spawn * world_scale
	player.velocity = Vector2.ZERO
	player.movement_enabled = true

	camera.zoom = Vector2.ONE * (0.75 * outdoor_zoom_multiplier if outside else 1.0)
	if outside:
		# 室外始终以主角为镜头中心，地图边缘不再把镜头卡住。
		camera.limit_left = -100000
		camera.limit_top = -100000
		camera.limit_right = 100000
		camera.limit_bottom = 100000
	else:
		camera.limit_left = floori(map.map_origin.x * world_scale)
		camera.limit_top = floori(map.map_origin.y * world_scale)
		camera.limit_right = ceili((map.map_origin.x + map.map_size.x) * world_scale)
		camera.limit_bottom = ceili((map.map_origin.y + map.map_size.y) * world_scale)
	camera.position = Vector2.ZERO

	_update_dialogue()
	_update_time_ui()

	if place in ["教学楼 F2", "教学楼 F3", "教学楼 F4", "教学楼 F5", "教学楼男厕", "食堂内部", "二号空房间", "小卖部内部", "白房内部", "宿舍一楼小房间", "宿舍洗澡间", "宿舍厕所", "二层第一教室", "一楼办公室"]:
		_frame_area()

	camera.reset_smoothing()
	camera.force_update_scroll()
	_apply_time_tint(true)
	_sync_time_points()


func _frame_area() -> void:
	var view_size: Vector2 = get_viewport_rect().size

	var reserved: float = (
		dialogue_height + 60.0
		if not message.is_empty()
		else 0.0
	)

	var available_height: float = maxf(
		view_size.y - reserved,
		100.0
	)

	var fit: float = minf(
		view_size.x / map.map_size.x,
		available_height / map.map_size.y
	) * 0.94

	fit = maxf(fit, 0.1)

	camera.zoom = Vector2.ONE * fit
	camera.position = (
		map.map_origin + map.map_size * 0.5
		- player.position
		+ Vector2(0, reserved / (2.0 * fit))
	)

	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000

func _update_dorm_stairs() -> void:
	if (debug_panel != null and debug_panel.is_open()) or dorm_transition_cooldown > 0.0 or not message.is_empty() or noticeboard_view.visible or (game_menu != null and game_menu.is_open()):
		return
	if place not in ["男生宿舍内部", "男生宿舍 F2", "男生宿舍 F3"]:
		return
	for transition in map.auto_transitions:
		var trigger: Rect2 = transition["rect"]
		if trigger.has_point(player.position):
			var floor_number: int = map._dorm_floor_number() + int(transition["step"])
			var next_place: String = "男生宿舍内部" if floor_number == 1 else "男生宿舍 F%d" % floor_number
			var arrival_x: float = 4550.0 if int(transition["step"]) > 0 else (4670.0 if floor_number == 1 else 4690.0)
			_load_place(next_place, Vector2(arrival_x, 410))
			return

func _setup_noticeboard() -> void:
	noticeboard_view = Control.new()
	noticeboard_view.name = "NoticeboardView"
	$HUD.add_child(noticeboard_view)
	noticeboard_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	noticeboard_view.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.04, 0.82)
	noticeboard_view.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var board := Panel.new()
	board.name = "BlankBoard"
	noticeboard_view.add_child(board)
	board.anchor_left = 0.15
	board.anchor_top = 0.18
	board.anchor_right = 0.85
	board.anchor_bottom = 0.78
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#d9d3bb")
	style.border_color = Color("#675347")
	style.set_border_width_all(14)
	board.add_theme_stylebox_override("panel", style)
	# 只显示关闭操作，不添加任何布告内容。
	var close_hint := Label.new()
	close_hint.text = "E  关闭"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_hint.add_theme_font_size_override("font_size", 26)
	noticeboard_view.add_child(close_hint)
	close_hint.anchor_left = 0.15
	close_hint.anchor_right = 0.85
	close_hint.anchor_top = 0.82
	close_hint.anchor_bottom = 0.9
	noticeboard_view.hide()

func _enter_teaching_floor(floor_number: int) -> void:
	if floor_number <= 1:
		_load_place("教学楼前平台", Vector2(1000, 1200))
		return
	if floor_number > 5:
		return
	var top: float = map.teaching_top_for_floor(floor_number)
	_load_place("教学楼 F%d" % floor_number, Vector2(1000, top + 136))
func _enter_teaching_west_floor(floor_number: int) -> void:
	if floor_number <= 1:
		_load_place("教学楼前平台", Vector2(-100, 1200))
		return
	if floor_number > 5:
		return
	var top: float = map.teaching_top_for_floor(floor_number)
	_load_place("教学楼 F%d" % floor_number, Vector2(-20, top + 136))

func _sync_player_controls() -> void:
	player.movement_enabled = (football_game == null or not football_game.is_open()) and (football_invite == null or not football_invite.is_open()) and (cabinet_view == null or not cabinet_view.is_open()) and (debug_panel == null or not debug_panel.is_open()) and message.is_empty() and not noticeboard_view.visible and (game_menu == null or not game_menu.is_open()) and not meal_seated and not bed_transition_busy and not is_instance_valid(active_bed_ladder)

func _bed_landing_is_clear(ladder: Node2D) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $Player/CollisionShape2D.shape
	query.transform = Transform2D(0.0, ladder.get_landing_position())
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _start_bed_climb(ladder: Node2D, going_up: bool) -> void:
	if bed_transition_busy or not is_instance_valid(ladder):
		return
	if not _bed_landing_is_clear(ladder):
		message = "梯子下方被挡住了，暂时不能上下床。"
		return
	bed_transition_busy = true
	if going_up:
		bed_visit_rest_used = false
		bed_saved_z_index = player.z_index
		active_bed_ladder = ladder
	player.velocity = Vector2.ZERO
	player.z_index = 2
	$Player/CollisionShape2D.set_deferred("disabled", true)
	_sync_player_controls()
	player.facing = "up" if going_up else "down"
	player.sprite.play("idle_" + player.facing)
	bed_ladder_tween = create_tween()
	bed_ladder_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if going_up:
		bed_ladder_tween.tween_property(player, "global_position", ladder.get_landing_position(), 0.12)
		bed_ladder_tween.tween_property(player, "global_position", ladder.get_foot_position(), 0.12)
		bed_ladder_tween.tween_property(player, "global_position", ladder.global_position, 0.65)
		bed_ladder_tween.tween_property(player, "global_position", _bed_upper_arrival(ladder), 0.15)
	else:
		bed_ladder_tween.tween_property(player, "global_position", ladder.global_position, 0.15)
		bed_ladder_tween.tween_property(player, "global_position", ladder.get_foot_position(), 0.65)
		bed_ladder_tween.tween_property(player, "global_position", ladder.get_landing_position(), 0.12)
	await bed_ladder_tween.finished
	map.set_bed_roof_revealed(ladder.bed_number if going_up else 0)
	bed_transition_busy = false
	if not going_up:
		active_bed_ladder = null
		player.z_index = bed_saved_z_index
		$Player/CollisionShape2D.set_deferred("disabled", false)
	player.velocity = Vector2.ZERO
	_sync_player_controls()
	_sync_time_points()


func _reset_bed_climb() -> void:
	map.set_bed_roof_revealed(0)
	if is_instance_valid(bed_ladder_tween):
		bed_ladder_tween.kill()
	if is_instance_valid(active_bed_ladder):
		player.z_index = bed_saved_z_index
	active_bed_ladder = null
	bed_visit_rest_used = false
	bed_transition_busy = false
	$Player/CollisionShape2D.set_deferred("disabled", false)
func _setup_time_ui() -> void:
	var badge := PanelContainer.new()
	badge.name = "DayPeriodBadge"
	$HUD.add_child(badge)
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -280.0
	badge.offset_right = -24.0
	badge.offset_top = 20.0
	badge.offset_bottom = 78.0
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.12, 0.94)
	style.border_color = Color("#a9b9b4")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	badge.add_theme_stylebox_override("panel", style)
	time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 24)
	badge.add_child(time_label)
	_update_time_ui()


func _update_time_ui() -> void:
	if time_label != null:
		time_label.text = day_cycle.display_text()


func _can_rest_on_bed() -> bool:
	return place == "宿舍尽头房间一" and is_instance_valid(active_bed_ladder) and active_bed_ladder.bed_number == 1 and not bed_transition_busy and not bed_visit_rest_used and day_cycle.can_advance("rest")


func _sync_time_points() -> void:
	_sync_meal_points()
	for point in map.points:
		if point["action"] == "time_classroom":
			var available: bool = place == "二层第一教室" and day_cycle.can_advance("classroom")
			point["enabled"] = available
			point["show_ring"] = available
			point["title"] = "上课到" + day_cycle.next_period_text("classroom")
		elif point["action"] in ["time_rest_noon", "time_rest_night"]:
			# 两个独立光圈，夜间光圈在左；只显示当前时段允许使用的一个。
			point["enabled"] = false
			point["show_ring"] = place == "宿舍尽头房间一" and day_cycle.period == point["rest_period"] and not bed_visit_rest_used
			point["title"] = "午休到下午" if point["rest_period"] == 1 else "睡到第%d天早上" % (day_cycle.day + 1)
	map.queue_redraw()
	_update_time_ui()


func _advance_day_period(source: String, expected_period: int = -1) -> void:
	if source == "classroom":
		if place != "二层第一教室" or is_instance_valid(active_bed_ladder): return
	elif source == "rest":
		if expected_period not in [1, 3] or day_cycle.period != expected_period: return
		var rest_point := _current_bed_rest_point()
		if rest_point.is_empty() or rest_point.get("rest_period", -1) != expected_period: return
		bed_visit_rest_used = true
	else:
		return
	if day_cycle.advance(source):
		message = ("课程结束，" if source == "classroom" else "休息结束，") + "现在是" + day_cycle.display_text() + "。"
		_sync_player_controls()
		_update_dialogue()
func _setup_time_tint() -> void:
	# 世界与 HUD 分属不同 Canvas，菜单和对白不受夜间变暗影响。
	world_time_tint = CanvasModulate.new()
	world_time_tint.name = "WorldTimeTint"
	add_child(world_time_tint)
	world_time_tint.color = _time_tint_for_place()
	map.classroom_daylight_strength = TIME_DAYLIGHT[day_cycle.period]
	map.night_light_strength = 1.0 if day_cycle.period == 3 else 0.0
	day_cycle.changed.connect(_apply_time_tint)


func _time_tint_for_place() -> Color:
	if day_cycle.period == 3 and place in INDOOR_PLACES:
		return INDOOR_NIGHT_TINT
	return TIME_TINTS[day_cycle.period]


func _apply_time_tint(immediate: bool = false) -> void:
	if is_instance_valid(time_tint_tween):
		time_tint_tween.kill()
	if immediate:
		world_time_tint.color = _time_tint_for_place()
		map.classroom_daylight_strength = TIME_DAYLIGHT[day_cycle.period]
		map.night_light_strength = 1.0 if day_cycle.period == 3 else 0.0
		return
	time_tint_tween = create_tween().set_parallel(true)
	time_tint_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	time_tint_tween.tween_property(world_time_tint, "color", _time_tint_for_place(), 0.6)
	time_tint_tween.tween_property(map, "classroom_daylight_strength", TIME_DAYLIGHT[day_cycle.period], 0.6)
	time_tint_tween.tween_property(map, "night_light_strength", 1.0 if day_cycle.period == 3 else 0.0, 0.6)
func _bed_upper_arrival(ladder: Node2D) -> Vector2:
	var position_on_bed: Vector2 = ladder.get_upper_position()
	if place == "宿舍尽头房间一" and ladder.bed_number == 1 and day_cycle.period == 3:
		position_on_bed += map.to_global(Vector2(-65, 0)) - map.to_global(Vector2.ZERO)
	return position_on_bed


func _current_bed_rest_point() -> Dictionary:
	if not _can_rest_on_bed(): return {}
	for point in map.points:
		if point.get("rest_period", -1) != day_cycle.period: continue
		if not point.get("show_ring", false): continue
		var target: Vector2 = map.to_global(point["pos"])
		if player.global_position.distance_to(target) <= float(point["radius"]) * map.global_scale.x:
			return point
	return {}


func _debug_step_time(direction: int) -> void:
	if bed_transition_busy: return
	var was_used: bool = bed_visit_rest_used
	bed_visit_rest_used = false
	if not day_cycle.debug_step(direction):
		bed_visit_rest_used = was_used
		return
	if is_instance_valid(active_bed_ladder):
		player.global_position = _bed_upper_arrival(active_bed_ladder)
	_sync_time_points()
	_sync_player_controls()

func _meal_slot_key() -> String:
	return "%d:%d" % [day_cycle.day, day_cycle.period]

func _sync_meal_points() -> void:
	var current_slot := _meal_slot_key()
	if meal_slot != current_slot:
		_end_meal_seating()
		if meal_dialogue_active:
			message = ""
			dialogue_lines.clear()
			meal_dialogue_active = false
		meal_slot = current_slot
		meal_taken = false
	var available: bool = day_cycle.period in [1, 3] and not completed_meals.has(current_slot)
	for point in map.points:
		if point["action"] == "canteen_take_meal":
			point["show_ring"] = available and not meal_taken
			point["title"] = "取饭" if not meal_taken else "已经取饭，请到中间座位吃饭"
		elif point["action"] == "canteen_eat_meal":
			point["show_ring"] = available
			point["title"] = "坐下吃饭" if meal_taken else "吃饭（请先取饭）"

func _use_canteen_meal(action: String) -> void:
	if place != "食堂内部" or action not in ["canteen_take_meal", "canteen_eat_meal"]: return
	var in_reach := false
	for point in map.points:
		if point["action"] == action:
			in_reach = player.global_position.distance_to(map.to_global(point["pos"])) <= float(point["radius"]) * map.global_scale.x
	if not in_reach: return
	_sync_meal_points()
	meal_dialogue_active = true
	dialogue_lines.clear()
	dialogue_index = 0
	if day_cycle.period not in [1, 3]:
		message = "现在不是用餐时间，只有中午和晚上可以取饭、吃饭。"
	elif completed_meals.has(meal_slot):
		message = "这个时段已经吃过饭了，下一次用餐时间再来吧。"
	elif action == "canteen_take_meal":
		if meal_taken:
			message = "已经取过饭了，请到中间的固定座位吃饭。"
		else:
			meal_taken = true
			message = "取好饭了，去中间亮着光圈的椅子上坐下吃饭吧。"
	elif not meal_taken:
		message = "还没有取饭，请先到档口取饭。"
	else:
		_start_meal_seating()
		completed_meals[meal_slot] = true
		meal_taken = false
		message = "你坐在椅子上吃完了%s。" % ("午饭" if day_cycle.period == 1 else "晚饭")
	_sync_time_points()

func _setup_meal_seat_animation() -> void:
	var frames: SpriteFrames = player.sprite.sprite_frames.duplicate()
	var standing: AtlasTexture = frames.get_frame_texture(&"idle_right", 0)
	var seated := AtlasTexture.new()
	seated.atlas = standing.atlas
	# 服装齐全的屈膝坐姿，后面的扩展动作没有上衣，不能用于吃饭。
	seated.region = Rect2(128, 1280, 64, 64)
	frames.add_animation(&"sit_meal")
	frames.add_frame(&"sit_meal", seated)
	player.sprite.sprite_frames = frames

func _start_meal_seating() -> void:
	meal_return_position = player.global_position
	meal_saved_sprite_position = player.sprite.position
	meal_saved_facing = player.facing
	meal_seated = true
	player.velocity = Vector2.ZERO
	$Player/CollisionShape2D.set_deferred("disabled", true)
	player.global_position = map.to_global(Vector2(560, 295))
	player.facing = "down"
	player.sprite.position = Vector2(0, -28)
	player.pose_override = &"sit_meal"
	player.sprite.play(&"sit_meal")

func _end_meal_seating() -> void:
	if not meal_seated: return
	meal_seated = false
	player.global_position = meal_return_position
	player.sprite.position = meal_saved_sprite_position
	player.facing = meal_saved_facing
	player.pose_override = &""
	player.sprite.play("idle_" + player.facing)
	player.velocity = Vector2.ZERO
	$Player/CollisionShape2D.set_deferred("disabled", false)

func _apply_player_place_size() -> void:
	# 只放大走廊中的角色画面，以脚底为锚点，避免改变相机和通行碰撞。
	var factor: float = 1.5 if place in ["男生宿舍内部", "男生宿舍 F2", "男生宿舍 F3"] else 1.0
	player.sprite.scale = player_sprite_base_scale * factor
	player.sprite.position = player_sprite_base_position * factor
	$Player/NameLabel.position = player_name_base_position + Vector2(0, -99.0 * (factor - 1.0))
func _update_teaching_passage() -> void:
	if place not in ["教学楼前平台", "休息区", "教学楼一楼内走廊"]:
		return
	if dorm_transition_cooldown > 0.0 or not player.movement_enabled:
		return
	for transition in map.auto_transitions:
		if transition.has("target") and transition["rect"].has_point(map.to_local(player.global_position)):
			_load_place(transition["target"], transition["spawn"])
			return

func _on_football_invite_answered(accepted: bool) -> void:
	dialogue_lines.clear()
	dialogue_index = 0
	if accepted:
		message = ""
		football_game.open()
	else:
		message = "wqy：好，下次再踢。"
	_sync_player_controls()
	_update_dialogue()
