# StateIdle — 待机状态
# 角色站立不动，显示当前朝向的静止帧
class_name StateIdle
extends BaseState


## 检测到移动输入后转移
## 攻击需通过冷却检查，防止连按卡死
func handle_input(host: CharacterBody2D, action: String) -> String:
	if action == "move":
		return "StateWalk"
	if action == "attack":
		if host.attack_cooldown_timer <= 0.0:
			return "StateAttack"
	return ""


## 进入待机：设置 sprite 为当前朝向的静止帧
func enter(host: CharacterBody2D) -> void:
	var sprite: Sprite2D = host.get_node("Sprite2D")
	var last_direction: Vector2 = host.last_direction

	# 朝向 → 行号 + 翻转
	var target_row: int
	if abs(last_direction.x) > abs(last_direction.y):
		target_row = host.row_left
		sprite.flip_h = last_direction.x > 0
	else:
		if last_direction.y > 0:
			target_row = host.row_down
		else:
			target_row = host.row_up
		sprite.flip_h = false

	sprite.frame = target_row * sprite.hframes + host.idle_frame
	host.animation_timer = 0.0
	host.current_frame = host.idle_frame
