@tool
extends Node2D
## 夜间灯具与真实局部照明；独立于 HUD，随 Map 的坐标与缩放变化。
const STREET_SHEET = preload("res://assets/tilesets/rasak/street_lights.png")
const GLOW_SHEET = preload("res://assets/tilesets/rasak/lamp_glow.png")
# 灯柱落脚点；下方三盏等距排列，入口留空。
const STREET_BASES := [
	Vector2(1916, 1035), # 宿舍左侧小红框
	Vector2(2930, 790), # 小卖部左上，宿舍右上
	Vector2(1690, 1410), Vector2(2300, 1410), Vector2(2910, 1410),
	Vector2(1685, 558), # 白房右上小红框
	Vector2(3070, 575), # 操场右下
]
const STREET_DIRECTIONS := [
	Vector2(1, -0.65), Vector2(-1, 0.20),
	Vector2.UP, Vector2.UP, Vector2.UP,
	Vector2(-0.5, 1.0), Vector2(0.8, 0.6),
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
		_add_hidden_area(Rect2(-1390, 820, 1140, 960), 0.18, "rest_area_fill")
		for index in range(STREET_BASES.size()):
			_add_street_lamp(STREET_BASES[index], STREET_DIRECTIONS[index])
		# 宿舍上方的横向通道补光，灯具视为被建筑遮挡。
		_light(Vector2(2306, 620), Vector2(2.0, 0.65), 0.48)
		lights.back().set_meta("hidden_fill", true)
	elif map.place in ["教学楼 F2", "教学楼 F3", "教学楼 F4", "教学楼 F5"]:
		var visible_floors = map.teaching_visible_floors()
		for index in range(visible_floors.size()):
			_add_ceiling_row(100.0 + index * 180.0)

func _sprite(sheet: Texture2D, source: Rect2, at: Vector2, sprite_scale: Vector2) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = source
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = at
	sprite.scale = sprite_scale
	sprite.z_index = 3
	add_child(sprite)
	return sprite

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

func _glow(at: Vector2, glow_scale: Vector2) -> void:
	var glow := _sprite(GLOW_SHEET,Rect2(192,0,48,48),at,glow_scale)
	var material := CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	glow_sprites.append(glow)

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

func _add_street_lamp(base: Vector2, direction: Vector2) -> void:
	var facing := direction.normalized()
	var upward := facing.y < -0.95
	var head_offset := Vector2(0, -140) if upward else Vector2(36 * signf(facing.x), -140)
	var source := Rect2(576,432,48,144) if upward else Rect2(384,96,48,144)
	var sprite_offset := Vector2(0,-82.8) if upward else Vector2(22 * signf(facing.x),-82.8)
	var fixture := _sprite(STREET_SHEET,source,base+sprite_offset,Vector2(1.15,1.15))
	fixture.flip_h = not upward and facing.x < 0.0
	fixture.set_meta("street_base",base)
	fixture.set_meta("light_direction",facing)
	_glow(base+head_offset,Vector2(0.65,0.65))
	# 光区沿灯头朝向延伸；向上的灯不再在柱脚下方形成亮斑。
	_light(base+facing*150.0,Vector2(1.65,1.05),0.82)
	lights.back().rotation = facing.angle()
	lights.back().set_meta("street_base",base)
	lights.back().set_meta("light_direction",facing)

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