extends Node2D
const HEAT = preload("res://scripts/effects/torch_heat.gdshader")
var game: Node2D
var patches: Array[ColorRect] = []

func sync() -> void:
	var positions: Array = game.sim.torch_positions()
	while patches.size() < positions.size():
		var patch := ColorRect.new()
		patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		patch.material = ShaderMaterial.new()
		patch.material.shader = HEAT
		add_child(patch)
		patches.append(patch)
	var scale_factor: float = game.zoom / game.CELL
	for i in patches.size():
		var patch := patches[i]
		patch.visible = i < positions.size()
		if not patch.visible: continue
		patch.visible = game.sim.is_visible(positions[i])
		patch.position = game.world_to_screen(positions[i]) + Vector2(-9, -25) * scale_factor
		patch.size = Vector2(18, 19) * scale_factor
		patch.material.set_shader_parameter("clock", game.sim.elapsed + i * 1.7)
		patch.material.set_shader_parameter("strength", scale_factor * 0.4)
