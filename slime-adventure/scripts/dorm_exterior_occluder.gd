extends Node2D
var source_map:Node2D
func _draw() -> void:
	if is_instance_valid(source_map):
		source_map._draw_dorm_exterior(self)
