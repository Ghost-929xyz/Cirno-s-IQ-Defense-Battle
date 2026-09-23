class_name EnchantDrop
extends Node2D

## 精英敌人掉落的附魔拾取物：十字芒星、高亮脉冲。
## 击杀精英后生成在世界坐标，玩家左键点击拾取后触发附魔三选一。

var shards := 1
var _age := 0.0


func setup(p_shards: int = 1) -> void:
	shards = maxi(1, p_shards)
	z_index = 18
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_age * 5.2)
	var outer := 15.0 + pulse * 4.5
	var inner := 5.5 + pulse * 1.5

	# 光晕（高亮脉冲）
	var halo := Color(1.0, 0.95, 0.55, 0.16 + pulse * 0.10)
	draw_circle(Vector2.ZERO, outer + 6.0, halo)
	draw_circle(Vector2.ZERO, outer + 2.0, Color(1.0, 0.95, 0.55, 0.08))

	# 十字芒星：8 个顶点，长轴（十字）+ 短轴（斜芒）交替
	var points := PackedVector2Array()
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var radius := outer if i % 2 == 0 else inner
		points.append(Vector2.from_angle(angle) * radius)
	draw_colored_polygon(points, Color("#ffe26b"))
	# 十字加粗
	var cross := PackedVector2Array()
	for i in range(4):
		var angle := TAU * float(i) / 4.0
		cross.append(Vector2.from_angle(angle) * (outer + 3.0))
	cross.append(cross[0])
	draw_polyline(cross, Color("#fff6c8"), 3.0, true)
	# 中心亮点
	draw_circle(Vector2.ZERO, inner * 0.7, Color("#fffdf2"))
	# 外圈细描边
	draw_arc(Vector2.ZERO, outer + 8.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.4, 0.5 + pulse * 0.3), 1.5)
