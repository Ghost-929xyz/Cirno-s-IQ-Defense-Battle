extends Node2D
var game: Node
func _draw() -> void:
	if is_instance_valid(game): game.draw_world(self)
