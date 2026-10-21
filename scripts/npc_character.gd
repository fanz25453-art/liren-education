extends StaticBody2D
## 在检查器修改人物名字、台词；在 AnimatedSprite2D 修改外观。
@export var idle_animation: StringName = &"idle_down"
@export var display_name: String = "cb"
@export_multiline var dialogue: String = "科技技，你来了！这里就是我们的教室。"

func _ready() -> void:
	$NameLabel.text = display_name
	$AnimatedSprite2D.play(idle_animation)

func set_active(active: bool) -> void:
	visible = active
	$CollisionShape2D.set_deferred("disabled", not active)
