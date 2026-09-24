class_name HitEffect
extends Node2D

const Metrics = preload("res://scripts/game/game_metrics.gd")

var _color := Color.WHITE
var _max_radius := 24.0
var _age := 0.0
var _duration := 0.24


func setup(color: Color, max_radius: float) -> void:
	_color = color
	# 所有命中特效的高旧尺度数值统一转换为新的高密度地图尺度。
	_max_radius = maxf(3.0, Metrics.art(max_radius))
	z_index = 20
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= _duration:
		queue_free()


func _draw() -> void:
	var ratio := clampf(_age / _duration, 0.0, 1.0)
	var radius := lerpf(maxf(1.0, Metrics.art(8.0)), _max_radius, ratio)
	var alpha := 1.0 - ratio
	var line_width := maxf(1.0, Metrics.art(3.0))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(_color.r, _color.g, _color.b, alpha * 0.85), line_width)
	draw_circle(Vector2.ZERO, radius * 0.35, Color(_color.r, _color.g, _color.b, alpha * 0.12))
