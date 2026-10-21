extends CharacterBody2D
## 玩家移动和动画。替换 AnimatedSprite2D 的 Sprite Frames 即可换外观。
@export var display_name: String = "科技技"
@export var speed: float = 120.0
var movement_enabled: bool = true
var facing: String = "down"
var pose_override: StringName = &""
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	$NameLabel.text = display_name

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if wasd != Vector2.ZERO:
		direction = wasd.normalized()
	if not movement_enabled:
		direction = Vector2.ZERO
	velocity = direction * speed
	move_and_slide()
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			facing = "right" if direction.x > 0 else "left"
		else:
			facing = "down" if direction.y > 0 else "up"
	if pose_override != &"" and sprite.sprite_frames.has_animation(pose_override):
		sprite.play(pose_override)
		return
	var animation_name: String = ("walk_" if direction != Vector2.ZERO else "idle_") + facing
	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)

