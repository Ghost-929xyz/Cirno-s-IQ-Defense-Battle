extends Node2D
const ART = preload("res://scripts/effects/resource_art.gd")
const GLOW = preload("res://scripts/effects/vision_crystal.gdshader")
var game: Node2D
var lights: Dictionary = {}

func sync() -> void:
	var present: Dictionary = {}
	var scale_factor: float = game.zoom / game.CELL
	for site in game.sim.resource_sites:
		if site.kind != "vision_tower": continue
		present[site.id] = true
		if not lights.has(site.id):
			var patch := ColorRect.new()
			patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			patch.material = ShaderMaterial.new()
			patch.material.shader = GLOW
			add_child(patch)
			lights[site.id] = patch
		var light: ColorRect = lights[site.id]
		light.visible = site.team == 0 and game.sim.is_visible(game.sim.point(site))
		if not light.visible: continue
		light.size = Vector2(24, 28) * scale_factor
		light.position = game.screen_point(site) + ART.tower_crystal_offset() * scale_factor - light.size * 0.5
		# Simulation time pauses with the game and survives save/load.
		light.material.set_shader_parameter("clock", game.sim.elapsed + float(site.id) * 0.37)
	for id in lights.keys():
		if present.has(id): continue
		lights[id].queue_free()
		lights.erase(id)
