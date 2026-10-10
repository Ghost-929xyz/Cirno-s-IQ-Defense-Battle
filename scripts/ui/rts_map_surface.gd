extends Node2D
var chart: Control
func _draw() -> void:
	if is_instance_valid(chart): chart.draw_map(self)
