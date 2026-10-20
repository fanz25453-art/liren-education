@tool
extends Node2D
const RASAK_STEPS = preload("res://assets/tilesets/rasak/interior_steps.png")
@export var use_rasak_steps: bool = false
@export var horizontal_side_ladder: bool = false
@export var horizontal_length: float = 70.0
## 可复用的斜梯：原点为顶端连接点，局部 +Y 朝地面。
## 地图/控制器通过三个位置方法驱动上下梯，不绑定宿舍场景名称。
@export_range(0.0, 60.0, 1.0) var angle_from_vertical: float = 25.0
@export var vertical_height: float = 120.0
@export var rail_width: float = 30.0
@export_enum("向右:1", "向左:-1") var lean_direction: int = 1
@export var bed_number: int = 1
@export var upper_side_distance: float = 20.0
@export var top_hook_length: float = 0.0

func _ready() -> void:
	z_index = 1
	queue_redraw()

func foot_offset() -> Vector2:
	if horizontal_side_ladder: return Vector2(horizontal_length * lean_direction, 0)
	return Vector2(tan(deg_to_rad(angle_from_vertical)) * vertical_height * lean_direction, vertical_height)

func get_foot_position() -> Vector2:
	return to_global(foot_offset())

func get_landing_position() -> Vector2:
	return to_global(foot_offset() + Vector2(lean_direction * 28.0, 0.0 if horizontal_side_ladder else 18.0))

func get_upper_position() -> Vector2:
	return to_global(Vector2(-lean_direction * upper_side_distance, 0.0 if horizontal_side_ladder else -12.0))

func _draw() -> void:
	if use_rasak_steps:
		var foot := foot_offset()
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if top_hook_length > 0.0:
			draw_line(Vector2.ZERO, Vector2(-lean_direction * top_hook_length, 0), Color("#bd7d2e"), 6, true)
		draw_set_transform(Vector2.ZERO, -atan2(foot.x, foot.y))
		# 从原版图一取红框内完整48×96木梯段，不使用带红框的截图。
		draw_texture_rect_region(RASAK_STEPS, Rect2(-rail_width * 0.8, 0, rail_width * 1.6, foot.length()), Rect2(336, 432, 48, 96))
		draw_set_transform(Vector2.ZERO)
		return
	if top_hook_length > 0.0:
		draw_line(Vector2.ZERO, Vector2(-lean_direction * top_hook_length, 0), Color("#d9bb91"), 6, true)
	var foot := foot_offset()
	var across := Vector2(foot.y, -foot.x).normalized() * rail_width * 0.5
	for side in [-1.0, 1.0]:
		var start: Vector2 = across * side
		draw_line(start + Vector2(3, 4), foot + start + Vector2(3, 4), Color(0.17, 0.19, 0.19, 0.20), 9, true)
		draw_line(start, foot + start, Color("#947047"), 8, true)
		draw_line(start + Vector2(-1, 0), foot + start + Vector2(-1, 0), Color("#ecd2a9"), 4, true)
	for index in range(1, 8):
		var center := foot * float(index) / 8.0
		draw_line(center - across, center + across, Color("#9e7a4f"), 7, true)
		draw_line(center - across + Vector2(0, -1), center + across + Vector2(0, -1), Color("#f0dbb6"), 3, true)
