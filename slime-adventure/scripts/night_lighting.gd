@tool
extends Node2D
## 夜间灯具与真实局部照明；独立于 HUD，随 Map 的坐标与缩放变化。
# 隐藏地面光源的位置，不生成灯柱、灯头或发光贴图。
const GROUND_LIGHT_BASES := [
	Vector2(2176,1035), # 宿舍左侧小红框
	Vector2(3702,790), # 小卖部左上，宿舍右上
	Vector2(1950,1410), Vector2(2816,1410), Vector2(3682,1410),
	Vector2(2221.25,538.5), # 白房右上小红框
	Vector2(3260,551.25), # 操场右下
]
var lights: Array[PointLight2D] = []
var glow_sprites: Array[Sprite2D] = []
var tube_sprites: Array[Sprite2D] = []
var radial_texture: GradientTexture2D
var teaching_fill_texture: ImageTexture

func configure(map: Node2D) -> void:
	_prepare_teaching_fill_texture()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.65, 1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0.7),Color(1,1,1,0.25),Color(1,1,1,0)])
	radial_texture = GradientTexture2D.new()
	radial_texture.gradient = gradient
	radial_texture.width = 256
	radial_texture.height = 256
	radial_texture.fill = GradientTexture2D.FILL_RADIAL
	radial_texture.fill_from = Vector2(0.5,0.5)
	radial_texture.fill_to = Vector2(1.0,0.5)
	if map.place in ["校园 G0", "教学楼前平台", "休息区"]:
		for floor_number in range(1,6):
			_add_ceiling_row(map.exterior_teaching_top(floor_number), map.EXTERIOR_TEACHING_SCALE, -200.0)
		_add_hidden_area(Rect2(-200, 1150, 1640, 280), 0.22, "platform_fill")
		_add_hidden_area(Rect2(-1390,500,1140,1280), 0.18, "rest_area_fill")
		for base in GROUND_LIGHT_BASES:
			_add_ground_light(base)
		_add_hidden_area(Rect2(240,1430,1240,660),0.20,"gate_plaza_ground")
		_add_hidden_area(Rect2(1460,1180,map.CAMPUS_RIGHT-1460,260),0.18,"east_plaza_ground")
		_add_hidden_area(map.outdoor_court_transform()*map.playground,0.12,"sports_ground")
		# 宿舍上方的横向通道补光，灯具视为被建筑遮挡。
		_light(Vector2(map.dorm.get_center().x,620),Vector2(map.dorm.size.x/364.0,0.65),0.48)
		lights.back().set_meta("hidden_fill", true)
	elif map.place in ["教学楼 F2", "教学楼 F3", "教学楼 F4", "教学楼 F5"]:
		var visible_floors = map.teaching_visible_floors()
		for index in range(visible_floors.size()):
			_add_ceiling_row(100.0 + index * 180.0)

func _light(at: Vector2, footprint: Vector2, power: float) -> void:
	var light := PointLight2D.new()
	light.texture = radial_texture
	light.position = at
	light.scale = footprint
	light.color = Color("#fff0c8")
	light.energy = 0.0
	light.set_meta("night_energy",power)
	light.shadow_enabled = false
	add_child(light)
	lights.append(light)

func _prepare_teaching_fill_texture() -> void:
	# 宽幅均匀补光，仅在边缘柔化；光源视为藏在天花板内。
	var image := Image.create(256, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		var vertical: float = smoothstep(0.0, 6.0, float(y)) * smoothstep(0.0, 6.0, float(63-y))
		for x in range(256):
			var horizontal: float = smoothstep(0.0, 12.0, float(x)) * smoothstep(0.0, 12.0, float(255-x))
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, horizontal * vertical))
	teaching_fill_texture = ImageTexture.create_from_image(image)

func _add_ceiling_row(top: float, vertical_scale: float = 1.0, facade_left: float = -120.0) -> void:
	# 不绘制灯管或灯具光斑，整层由隐藏的暖白光均匀照亮。
	_light(Vector2(facade_left + 820, top + 85 * vertical_scale), Vector2(1640.0/256.0, 156.0/64.0 * vertical_scale), 0.48)
	lights.back().texture = teaching_fill_texture
	lights.back().color = Color("#fff6de")
	lights.back().set_meta("teaching_hidden_fill", true)

func _add_ground_light(base: Vector2) -> void:
	# 柔和地面光晕，不显示实体灯具，也不会阻挡人物。
	_light(base,Vector2(2.8,1.8),0.42)
	lights.back().color=Color("#fff2db")
	lights.back().set_meta("hidden_ground",true)

func set_strength(value: float) -> void:
	var strength: float = clampf(value,0.0,1.0)
	for light in lights:
		light.energy = float(light.get_meta("night_energy")) * strength
		light.visible = strength > 0.001
	for glow in glow_sprites:
		glow.modulate = Color(1.0,0.91,0.65,0.62 * strength)
		glow.visible = strength > 0.001
	for tube in tube_sprites:
		tube.modulate = Color(0.40,0.43,0.43).lerp(Color(1.0,1.0,0.91),strength)

func _add_hidden_area(area: Rect2, power: float, tag: String) -> void:
	# 地面只做低强度补光，不显示灯具或光斑。
	_light(area.get_center(), area.size / Vector2(256, 64), power)
	lights.back().texture = teaching_fill_texture
	lights.back().color = Color("#fff1da")
	lights.back().set_meta(tag, true)
	lights.back().set_meta("hidden_ground",true)