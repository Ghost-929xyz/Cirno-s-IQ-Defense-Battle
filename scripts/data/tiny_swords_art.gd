extends RefCounted
## Original sheets are 192px per frame, not 64px terrain tiles.
const ROOT := "res://assets/tiny_swords/"
const FRAME := 192
const MOVEMENT_SHEET := "res://assets/sprites/troops_vertical_walk.png"
const MOVEMENT_ROWS := {"Warrior": 0, "Archer": 2, "Pawn": 4, "Torch": 6}
static var frames_cache: Dictionary = {}
static var textures: Dictionary = {}
static var movement_layout: Dictionary = {}

static func texture(relative: String) -> Texture2D:
	if not textures.has(relative): textures[relative] = load(ROOT + relative)
	return textures[relative]

static func color_name(team: int) -> String:
	return "Blue" if team == 0 else ("Red" if team == 1 else "Yellow")

static func family(kind: String, team: int, working := false) -> String:
	if working: return "Pawn"
	if team == 2: return "Torch"
	if kind in ["archer", "sniper", "ice_archer", "sniper_plus", "ice_archer_plus", "scout"]: return "Archer"
	if kind in ["assassin", "hermit", "berserker", "hermit_dodge", "hermit_blink", "berserker_plus"]: return "Pawn"
	return "Warrior"

static func troop_path(troop: String, team: int) -> String:
	var faction := "Goblins" if troop == "Torch" else "Knights"
	var color := color_name(team)
	return "Factions/%s/Troops/%s/%s/%s_%s.png" % [faction, troop, color, troop, color]

static func add_row(frames: SpriteFrames, sheet: Texture2D, animation: String, row: int, count: int, fps: float, loop := true, size := FRAME) -> void:
	frames.add_animation(animation)
	frames.set_animation_speed(animation, fps)
	frames.set_animation_loop(animation, loop)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * size, row * size, size, size)
		frames.add_frame(animation, atlas)

static func troop_frames(troop: String, team: int) -> SpriteFrames:
	var key := troop_path(troop, team)
	if frames_cache.has(key): return frames_cache[key]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var sheet := texture(key)
	add_row(frames, sheet, "idle", 0, 7 if troop == "Torch" else 6, 8)
	add_row(frames, sheet, "run", 1, 6, 12)
	for direction in ["left", "right"]:
		add_row(frames, sheet, "idle_" + direction, 0, 7 if troop == "Torch" else 6, 8)
		add_row(frames, sheet, "run_" + direction, 1, 6, 12)
	add_vertical_movement(frames, troop)
	if troop == "Archer":
		add_row(frames, sheet, "attack_up", 2, 8, 16, false)
		add_row(frames, sheet, "attack_side", 4, 8, 16, false)
		add_row(frames, sheet, "attack_down", 6, 8, 16, false)
	elif troop == "Warrior":
		add_row(frames, sheet, "attack_up", 6, 6, 15, false)
		add_row(frames, sheet, "attack_side", 2, 6, 15, false)
		add_row(frames, sheet, "attack_down", 4, 6, 15, false)
	else:
		add_row(frames, sheet, "attack_up", 4 if troop == "Torch" else 2, 6, 15, false)
		add_row(frames, sheet, "attack_side", 2, 6, 15, false)
		add_row(frames, sheet, "attack_down", 3, 6, 15, false)
	frames_cache[key] = frames
	return frames

static func add_vertical_movement(frames: SpriteFrames, troop: String) -> void:
	var sheet: Texture2D = load(MOVEMENT_SHEET)
	if movement_layout.is_empty():
		movement_layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/troops_vertical_walk.json"))
	for index in 2:
		var direction: String = ["up", "down"][index]
		var row: int = MOVEMENT_ROWS[troop] + index
		var layout: Dictionary = movement_layout.rows[row]
		frames.add_animation("run_" + direction)
		frames.set_animation_speed("run_" + direction, 12)
		for column in 6:
			# One generated south-facing Warrior pose swaps hands; omit that pose.
			var entry: Dictionary = layout.frames[4 if troop == "Warrior" and index == 1 and column == 3 else column]
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(entry.region[0], entry.region[1], entry.region[2], entry.region[3])
			atlas.filter_clip = true
			atlas.set_meta("walk_scale", float(layout.scale))
			atlas.set_meta("foot_anchor", Vector2(entry.anchor[0], entry.anchor[1]))
			frames.add_frame("run_" + direction, atlas)
		frames.add_animation("idle_" + direction)
		frames.add_frame("idle_" + direction, frames.get_frame_texture("run_" + direction, 0))

static func building_path(kind: String, team: int, complete: bool, destroyed := false) -> String:
	if kind == "outpost":
		if not complete: return "Factions/Knights/Buildings/House/House_Construction.png"
		return "Factions/Goblins/Buildings/Wood_House/Goblin_House%s.png" % ("_Destroyed" if destroyed else "")
	var building := "Castle" if kind == "base" else ("Tower" if kind in ["well", "academy"] else "House")
	var state := color_name(team)
	if destroyed: state = "Destroyed"
	elif not complete: state = "Construction"
	return "Factions/Knights/Buildings/%s/%s_%s.png" % [building, building, state]

static func portrait(kind: String) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture(troop_path(family(kind, 0), 0))
	atlas.region = Rect2(48, 40, 96, 100)
	return atlas
