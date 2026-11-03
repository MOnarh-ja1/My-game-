extends Node3D
## RUNIVERSE v2 by MgameIO — complete Godot-native 3D runner and game UI.
## Menu/shop images are the design mockups approved by the user. All interaction,
## player models, animation, gameplay, save data, and abilities are real Godot code.
const Art = preload("res://scripts/world_art.gd")
const Runner = preload("res://scripts/character.gd")
const SAVE := "user://runiverse_v2.cfg"
const LANES := [-3.1, 0.0, 3.1]
const Z_PLAYER := 3.6
const W := 1672.0
const H := 941.0

var rng := RandomNumberGenerator.new()
var menu_texture: Texture2D
var shop_texture: Texture2D
var portraits: Array[Texture2D] = []
var characters: Array = []
var owned_heroes: Array[int] = []
var selected_hero: int = -1
var focused_hero: int = 0
var chosen_category: String = "Все персонажи"
var wallet: int = 0
var high_score: int = 0
var owned_worlds: Array[int] = [0]
var world_index: int = 0
var audio_on := true
var fullscreen := false
var state := "menu"
var world_styles: Array[Dictionary] = []
var root_world: Node3D
var ground: Array[Node3D] = []
var objects: Array[Dictionary] = []
var avatar: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var env: WorldEnvironment
var player_lane := 1
var run_time := 0.0
var run_distance := 0.0
var run_pickups := 0
var combo := 0
var combo_timer := 0.0
var health := 3
var jump_v := 0.0
var slide_left := 0.0
var invuln := 0.0
var dash_left := 0.0
var dash_cooldown := 0.0
var magnet_left := 0.0
var shield_left := 0.0
var shield_hits := 0
var revive_used := false
var breaker_used := false
var wave_countdown := 1.3
var game_speed := 22.0
var last_jump_time := -100.0
var last_slide_time := -100.0
var last_hit_time := -100.0
var next_bonus_time := 30.0
var earned_this_run := 0
var preview_timer := 0.0
var fx_nodes: Array[Node3D] = []
var audio_players: Dictionary = {}
var gui: Control
var screens: Dictionary = {}
var shop_focus_buttons: Array[Button] = []
var shop_dim: Array[ColorRect] = []
var shop_portrait_zooms: Array[TextureRect] = []
var shop_wallet_label: Label
var shop_name_label: Label
var shop_price_label: Label
var shop_perk_label: Label
var shop_buy_button: Button
var shop_notice_label: Label
var shop_avatar_preview: TextureRect
var menu_wallet_label: Label
var world_title_label: Label
var world_money_label: Label
var world_buttons: Array[Button] = []
var hud_score: Label
var hud_wallet: Label
var hud_heart: Label
var hud_world: Label
var hud_ability: Label
var hud_combo: Label
var over_result: Label
var over_details: Label
var pause_status: Label
var sound_btn: Button
var full_btn: Button

func _ready() -> void:
	rng.randomize()
	var file := FileAccess.open("res://data/characters.json", FileAccess.READ)
	if file != null:
		var decoded: Variant = JSON.parse_string(file.get_as_text())
		if decoded is Array:
			characters = decoded
	_init_worlds()
	_load()
	_load_pictures()
	_create_world()
	_create_audio()
	_build_ui()
	_equip_hero()
	_set_world(world_index)
	_show("menu")

func _load_pictures() -> void:
	var menu_png := Image.new()
	var menu_bytes := FileAccess.get_file_as_bytes("res://assets/ui/menu.webp")
	if menu_png.load_webp_from_buffer(menu_bytes) != OK:
		menu_png = Image.create_empty(1672,941,false,Image.FORMAT_RGBA8)
		menu_png.fill(Color("183743"))
	menu_texture = ImageTexture.create_from_image(menu_png)
	var shop_png := Image.new()
	var shop_bytes := FileAccess.get_file_as_bytes("res://assets/ui/shop.webp")
	if shop_png.load_webp_from_buffer(shop_bytes) != OK:
		shop_png = Image.create_empty(1672,941,false,Image.FORMAT_RGBA8)
		shop_png.fill(Color("183743"))
	shop_texture = ImageTexture.create_from_image(shop_png)
	var ylist := [212,350,481,609,727]
	for i in range(50):
		var px := 85+(i%10)*151
		var py := int(ylist[int(i/10)])+3
		var region := shop_png.get_region(Rect2i(px,py,138,77))
		portraits.append(ImageTexture.create_from_image(region))

func _init_worlds() -> void:
	world_styles = [
		{"name":"Зелёная долина", "price":0, "sky":Color("98d9f4"),"ground":Color("75b86e"),"road":Color("c4a073"),"edge":Color("f2d7a5"),"line":Color("f6e4b9"),"stone":Color("bfcda5"),"outfit":Color("db5745"),"obstacle":Color("b3754c")},
		{"name":"Пески времени", "price":80, "sky":Color("fbc79c"),"ground":Color("efc87c"),"road":Color("b78a62"),"edge":Color("fae6b5"),"line":Color("eecda1"),"stone":Color("c79c60"),"outfit":Color("d79a55"),"obstacle":Color("bb805b")},
		{"name":"Снежные пики", "price":200, "sky":Color("9ad6f5"),"ground":Color("e0f4ff"),"road":Color("95becb"),"edge":Color("f6ffff"),"line":Color("eafcff"),"stone":Color("b8d2df"),"outfit":Color("4397c1"),"obstacle":Color("538ba8")},
		{"name":"Дикие джунгли", "price":420, "sky":Color("b5e6c3"),"ground":Color("3c9e67"),"road":Color("ad926a"),"edge":Color("e5ddad"),"line":Color("f6e1ae"),"stone":Color("78a88c"),"outfit":Color("bb608d"),"obstacle":Color("ad7a4e")},
		{"name":"Остров вулканов", "price":800, "sky":Color("e4a27e"),"ground":Color("4e4050"),"road":Color("625364"),"edge":Color("fa8551"),"line":Color("e8a884"),"stone":Color("82707a"),"outfit":Color("b15b4d"),"obstacle":Color("af5548")}
	]

func _load() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE) != OK:
		return
	wallet = maxi(0,int(c.get_value("player","coins",0)))
	high_score = maxi(0,int(c.get_value("player","record",0)))
	selected_hero = int(c.get_value("player","character",-1))
	world_index = clampi(int(c.get_value("player","world",0)),0,4)
	audio_on = bool(c.get_value("options","sound",true))
	fullscreen = bool(c.get_value("options","fullscreen",false))
	var list_heroes: Array = c.get_value("player","heroes",[])
	for id in list_heroes:
		if int(id) >= 0 and int(id) < 50 and not owned_heroes.has(int(id)):
			owned_heroes.append(int(id))
	var list_worlds: Array = c.get_value("player","worlds",[0])
	for index in list_worlds:
		if int(index) >= 0 and int(index) < 5 and not owned_worlds.has(int(index)):
			owned_worlds.append(int(index))
	if not owned_heroes.has(selected_hero):
		selected_hero = -1
	if not owned_worlds.has(world_index):
		world_index = 0
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("player","coins",wallet)
	c.set_value("player","record",high_score)
	c.set_value("player","heroes",owned_heroes)
	c.set_value("player","character",selected_hero)
	c.set_value("player","worlds",owned_worlds)
	c.set_value("player","world",world_index)
	c.set_value("options","sound",audio_on)
	c.set_value("options","fullscreen",fullscreen)
	c.save(SAVE)

func _bonus() -> Dictionary:
	if selected_hero >= 0 and selected_hero < characters.size():
		var c: Dictionary = characters[selected_hero]
		return {String(c["bonus_key"]):float(c["bonus_value"])}
	return {}

func _perk(k: String) -> float:
	return float(_bonus().get(k,0.0))

func _create_world() -> void:
	root_world = Node3D.new()
	root_world.name = "FiveLivingBiomes"
	add_child(root_world)
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = world_styles[0]["sky"]
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("f2f6ff")
	e.ambient_light_energy = .84
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(-.84,-.54,.13)
	sun.light_color = Color("fff0d2")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.name = "ThirdPersonFollowCamera"
	camera.position = Vector3(2.1,5.9,15.7)
	camera.fov = 66.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0,1.15,-12),Vector3.UP)
	avatar = Runner.new()
	avatar.name = "AnimatedPlayableHero"
	avatar.position = Vector3(0,0,Z_PLAYER)
	add_child(avatar)
	for z in [-65.0,-39.0,-13.0,13.0,39.0]:
		ground.append(Art.ground(root_world,world_index,z,world_styles[world_index],rng))

func _equip_hero() -> void:
	if avatar == null:
		return
	if selected_hero >= 0 and selected_hero < characters.size():
		avatar.apply_character(characters[selected_hero])
	else:
		avatar.apply_character({"id":-1,"look":"runner","color":"db5642"})

func _set_world(i: int) -> void:
	world_index = i
	env.environment.background_color = world_styles[i]["sky"]
	for e in objects:
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	objects.clear()
	for g in ground:
		g.queue_free()
	ground.clear()
	for z in [-65.0,-39.0,-13.0,13.0,39.0]:
		ground.append(Art.ground(root_world,i,z,world_styles[i],rng))
	_save()

func _create_audio() -> void:
	for tag in ["tap","coin","jump","slide","hit","buy","over","boost"]:
		var tones := {"tap":460.0,"coin":880.0,"jump":430.0,"slide":240.0,"hit":155.0,"buy":720.0,"over":190.0,"boost":1000.0}
		var frequency: float = tones[tag]
		var wave := AudioStreamWAV.new()
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate = 22050
		var n := 3000 if tag != "over" else 7000
		var bytes := PackedByteArray()
		bytes.resize(n*2)
		for k in range(n):
			var v := float(k)/22050.0
			var amp := pow(maxf(0,1.0-float(k)/float(n)),1.5)
			var sample := int(sin(TAU*frequency*v*(1.0+.15*v))*amp*15500.0)
			bytes[k*2] = sample&255
			bytes[k*2+1] = (sample>>8)&255
		wave.data = bytes
		var ap := AudioStreamPlayer.new()
		ap.volume_db = -17.0
		ap.stream = wave
		add_child(ap)
		audio_players[tag] = ap

func _sound(tag: String) -> void:
	if audio_on and audio_players.has(tag):
		var a: AudioStreamPlayer = audio_players[tag]
		a.stop()
		a.play()

func _process(delta: float) -> void:
	var dt := minf(delta,.055)
	if state == "playing":
		_tick_run(dt)
	elif avatar != null:
		avatar.animate(dt,false,false,false,0,0)
	if state == "menu" or state == "shop":
		preview_timer += dt
		avatar.position.x = lerpf(avatar.position.x,0.0,minf(1,dt*4))
		camera.position.x = lerpf(camera.position.x,1.6,minf(1,dt*3))
	else:
		camera.position.x = lerpf(camera.position.x,2.1+avatar.position.x*.13,minf(1,dt*3.5))
	camera.look_at(Vector3(avatar.position.x*.30,1.4,-13),Vector3.UP)

func _tick_run(dt: float) -> void:
	run_time += dt
	var base_speed := minf(22.0+run_distance*.011,48.0)
	game_speed = base_speed*(1.0+_perk("speed_mul")+(_perk("post_jump_speed") if run_time-last_jump_time < 2.5 else 0.0)+(_perk("speed_after_hit") if run_time-last_hit_time < 3.0 else 0.0))
	dash_left = maxf(0,dash_left-dt)
	dash_cooldown = maxf(0,dash_cooldown-dt)
	if dash_left > 0:
		game_speed *= 1.7*(1.0+_perk("dash_speed"))
	run_distance += game_speed*dt
	slide_left = maxf(0,slide_left-dt)
	invuln = maxf(0,invuln-dt)
	shield_left = maxf(0,shield_left-dt)
	magnet_left = maxf(0,magnet_left-dt)
	combo_timer -= dt
	if combo_timer < 0:
		combo = 0
	avatar.position.y += jump_v*dt
	jump_v -= 33.0*dt
	if avatar.position.y < 0:
		avatar.position.y = 0
		jump_v = maxf(0,jump_v)
	var airborne := avatar.position.y > .1
	var dx: float = LANES[player_lane]-avatar.position.x
	avatar.position.x = lerpf(avatar.position.x,LANES[player_lane],minf(1,dt* (10.7*(1.0+_perk("lane_agility")))))
	var turn := clampf(dx*.19,-.52,.52)
	avatar.rotation.y = lerp_angle(avatar.rotation.y, PI+turn,minf(1,dt*8.5))
	avatar.animate(dt,true,slide_left>0,airborne,game_speed/45.0,turn)
	camera.fov = lerpf(camera.fov,76.0 if dash_left > 0 else 66.0,minf(1,dt*3.2))
	var furthest := 100000.0
	for piece in ground:
		piece.position.z += game_speed*dt
		furthest = minf(furthest,piece.position.z)
	for piece in ground:
		if piece.position.z > 54.0:
			piece.position.z = furthest-26.0
			furthest = piece.position.z
	wave_countdown -= dt
	if wave_countdown < 0:
		_spawn_wave()
		wave_countdown = maxf(.85,1.48-run_distance/9000.0)+rng.randf_range(-.11,.16)
	if _perk("periodic_coins") > 0 and run_time >= next_bonus_time:
		_award_coins(15,false)
		next_bonus_time += 30.0
	if _perk("heal_interval") > 0 and run_time > 0 and floori(run_time/20.0) > floori((run_time-dt)/20.0):
		health = mini(4,health+1)
	for index in range(objects.size()-1,-1,-1):
		var thing: Dictionary = objects[index]
		var node: Node3D = thing["node"]
		if not is_instance_valid(node):
			objects.remove_at(index)
			continue
		node.position.z += game_speed*(1.0-_perk("slow_world"))*dt
		var kind: String = thing["kind"]
		if kind == "coin":
			node.rotation.y += dt*4.5
			node.position.y = 1.3+sin(run_time*4.0+float(thing["phase"]))* .17
		if node.position.z > Z_PLAYER+5.0:
			_remove(index)
			continue
		var lane_equal := int(thing["lane"]) == player_lane
		var reach := 1.0+_perk("pickup_radius")*3.0
		if magnet_left > 0 and kind == "coin":
			reach += 2.6*(1.0+_perk("magnet_radius"))
			lane_equal = true
		if not lane_equal or absf(node.position.z-Z_PLAYER) > reach:
			continue
		match kind:
			"coin":
				_collect_coin(airborne)
				_remove(index)
			"chest":
				_award_coins(int(40*(1+_perk("chest_value"))),true)
				_remove(index)
			"shield":
				shield_left = 12.0*(1+_perk("shield_duration")+_perk("powerup_duration"))
				shield_hits = 1+int(_perk("shield_hits"))
				_sound("boost")
				_remove(index)
			"magnet":
				magnet_left = 11.0*(1+_perk("magnet_duration")+_perk("powerup_duration"))
				_sound("boost")
				_remove(index)
			_:
				var dodged := (kind == "hurdle" and avatar.position.y > (1.05/(1.0+_perk("jump_mul")))) or (kind == "gate" and slide_left > .08)
				if dodged:
					combo += 1
					combo_timer = 5.0*(1.0+_perk("combo_duration"))
					_remove(index)
				elif invuln <= 0 and dash_left <= 0:
					_on_hit()
					_remove(index)
					if state != "playing":
						break
				else:
					_remove(index)
	if state == "playing":
		_update_hud()

func _collect_coin(is_airborne: bool) -> void:
	run_pickups += 1
	combo += 1
	combo_timer = 4.0*(1.0+_perk("combo_duration"))
	var bonus := 1.0+_perk("coin_mul")
	if is_airborne:
		bonus += _perk("air_coins")
	if slide_left > 0 or run_time-last_slide_time < 1.3:
		bonus += _perk("slide_coins")
	if dash_left > 0:
		bonus += _perk("dash_coins")
	if run_time > 60:
		bonus += _perk("late_coins")
	if combo >= 8:
		bonus += _perk("streak_coins")
	var actual := int(round(8*bonus))
	if rng.randf() < (_perk("double_coin")+_perk("lucky_coin_chance")):
		actual *= 2
	_award_coins(actual,true)

func _award_coins(amount: int, play_sound: bool) -> void:
	wallet += amount
	earned_this_run += amount
	if play_sound:
		_sound("coin")
	if run_pickups % 8 == 0:
		_save()

func _score() -> int:
	var value := run_distance*4.0*(1.0+_perk("score_mul"))
	value += run_pickups*15.0*(1.0+_perk("coin_score"))
	if combo > 2:
		value += combo*5.0*(1.0+_perk("combo_mult"))
	if dash_left > 0:
		value *= 1.0+_perk("dash_score")
	if slide_left > 0:
		value *= 1.0+_perk("slide_score")
	return int(value)

func _spawn_wave() -> void:
	var blocked := rng.randi_range(0,2)
	var kind: String = ["crate","hurdle","gate"][rng.randi_range(0,2)]
	_spawn_item(kind,blocked,-89.0)
	var free_lane: int = (blocked+1+rng.randi_range(0,1))%3
	if run_distance > 130 and rng.randf() < .26:
		var blocked2: int = (blocked+1+rng.randi_range(0,1))%3
		_spawn_item(["crate","hurdle","gate"][rng.randi_range(0,2)],blocked2,-89.0)
		free_lane = 3-blocked-blocked2
	for i in range(6):
		_spawn_item("coin",free_lane,-76.0-float(i)*2.8)
	if rng.randf() < (.042+_perk("chest_chance")):
		_spawn_item("chest",free_lane,-111.0)
	if rng.randf() < .024:
		_spawn_item("shield",free_lane,-112.0)
	if rng.randf() < .027:
		_spawn_item("magnet",free_lane,-106.0)

func _spawn_item(kind: String, lane: int, z: float) -> void:
	var node: Node3D
	if kind == "coin":
		node = Art.coin(root_world)
	elif kind in ["shield","magnet","chest"]:
		node = Node3D.new()
		root_world.add_child(node)
		var color := Color("78dcfa") if kind == "shield" else (Color("8efa92") if kind == "magnet" else Color("f7d266"))
		Art.make_mesh(node,"sphere" if kind != "chest" else "box",Vector3(1.1,1.1,1.1),Vector3(0,1.32,0),color,Art.mat(color,true))
	else:
		node = Art.obstacle(root_world,kind,world_index,world_styles[world_index]["obstacle"])
	node.position = Vector3(LANES[lane],1.25 if kind == "coin" else 0.0,z)
	objects.append({"node":node,"lane":lane,"kind":kind,"phase":rng.randf_range(0,TAU)})

func _remove(index: int) -> void:
	var node: Node3D = objects[index]["node"]
	objects.remove_at(index)
	if is_instance_valid(node):
		node.queue_free()

func _on_hit() -> void:
	if shield_left > 0 and shield_hits > 0:
		shield_hits -= 1
		if shield_hits == 0:
			shield_left = 0
		invuln = .55
		_sound("boost")
		return
	if rng.randf() < _perk("dodge_chance"):
		invuln = .7
		return
	if _perk("breaker") > 0 and not breaker_used:
		breaker_used = true
		invuln = 1.0
		_sound("boost")
		return
	health -= 1
	combo = 0
	invuln = 1.35
	last_hit_time = run_time
	_sound("hit")
	if health <= 0:
		if (_perk("revive_once") > 0 and not revive_used) or (rng.randf() < _perk("revive_chance") and not revive_used):
			revive_used = true
			health = 1
			invuln = 2.0
		else:
			_game_over()

func _start() -> void:
	_sound("tap")
	_set_world(world_index)
	_equip_hero()
	player_lane = 1
	avatar.position = Vector3(0,0,Z_PLAYER)
	avatar.rotation.y = PI
	jump_v = 0
	slide_left = 0
	invuln = 0
	dash_left = 2.5 if _perk("start_dash") > 0 else 0
	dash_cooldown = 0
	magnet_left = 0
	shield_left = 12.0 if _perk("start_shield") > 0 else 0
	shield_hits = 1 if shield_left > 0 else 0
	run_time = 0
	run_distance = 0
	run_pickups = 0
	earned_this_run = 0
	combo = 0
	health = 3+int(_perk("extra_hp"))
	revive_used = false
	breaker_used = false
	wave_countdown = 1.1
	next_bonus_time = 30.0
	_show("playing")

func _game_over() -> void:
	_sound("over")
	var final_score := _score()
	if final_score > high_score:
		high_score = final_score
	var survival_pay := int(run_distance/3.0)
	_award_coins(survival_pay,false)
	_save()
	over_result.text = "РЕЗУЛЬТАТ:  %d      РЕКОРД:  %d" % [final_score,high_score]
	over_details.text = "Монеты за забег:  +%d      Собрано монет:  %d" % [earned_this_run,run_pickups]
	_show("over")

func _leave() -> void:
	_save()
	_show("menu")

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		if state == "playing":
			_show("pause")
		elif state == "pause":
			_show("playing")
		elif state != "menu":
			_show("menu")
		return
	if state != "playing":
		if state == "over" and (key == KEY_R or key == KEY_ENTER):
			_start()
		return
	match key:
		KEY_A,KEY_LEFT:
			player_lane = maxi(0,player_lane-1)
		KEY_D,KEY_RIGHT:
			player_lane = mini(2,player_lane+1)
		KEY_W,KEY_UP,KEY_SPACE:
			if avatar.position.y <= .02 and slide_left <= .02:
				jump_v = 13.7*(1.0+_perk("jump_mul")+(_perk("slide_jump") if run_time-last_slide_time < 2.0 else 0.0))
				last_jump_time = run_time
				_sound("jump")
		KEY_S,KEY_DOWN,KEY_CTRL:
			if avatar.position.y <= .05:
				slide_left = .78+_perk("slide_duration")
				last_slide_time = run_time
				_sound("slide")
		KEY_SHIFT:
			_dash()

func _dash() -> void:
	if dash_cooldown > 0:
		return
	dash_left = .72*(1.0+_perk("dash_duration")+_perk("air_duration"))
	dash_cooldown = 7.0*(1.0-_perk("dash_cooldown"))
	_sound("boost")

func _update_hud() -> void:
	hud_score.text = "ОЧКИ  %06d     РЕКОРД  %06d" % [_score(),high_score]
	hud_wallet.text = "◉ %s    +%d" % [_money(wallet),earned_this_run]
	hud_heart.text = "♥ ".repeat(health)
	hud_world.text = String(world_styles[world_index]["name"])
	hud_combo.text = "КОМБО x%d" % combo if combo >= 2 else "БЕГИ!"
	var label := "ЩИТ  %ds" % int(shield_left) if shield_left>0 else ("МАГНИТ  %ds" % int(magnet_left) if magnet_left>0 else "SHIFT — РЫВОК")
	if dash_cooldown > 0 and dash_left <= 0:
		label = "РЫВОК ЧЕРЕЗ %d с" % int(ceilf(dash_cooldown))
	hud_ability.text = label

func _money(number: int) -> String:
	var t := str(number)
	var out := ""
	for i in range(t.length()):
		if i > 0 and (t.length()-i)%3==0:
			out += " "
		out += t[i]
	return out

# -------------------------- INTERACTIVE USER INTERFACE --------------------
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameUI"
	add_child(layer)
	gui = Control.new()
	gui.name = "FullScreenMenuCanvas"
	gui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(gui)
	_build_main_menu()
	_build_shop()
	_build_world_selector()
	_build_settings()
	_build_game_hud()
	_build_pause()
	_build_game_over()

func _blank_screen(name: String, picture: Texture2D = null) -> Control:
	var node := Control.new()
	node.name = name
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gui.add_child(node)
	screens[name] = node
	if picture != null:
		var texture := TextureRect.new()
		texture.name = "ApprovedArtBackground"
		texture.texture = picture
		texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_SCALE
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(texture)
	return node

func _box_style(bg: Color, edge: Color = Color("f9c870"), radius: int = 14, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _label(parent: Control, caption: String, point: Vector2, area: Vector2, size: int = 26, tint: Color = Color("fff0c0"), center: bool = true) -> Label:
	var l := Label.new()
	l.text = caption
	l.position = point
	l.size = area
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",tint)
	l.add_theme_color_override("font_shadow_color",Color("301d1b"))
	l.add_theme_constant_override("shadow_offset_x",2)
	l.add_theme_constant_override("shadow_offset_y",2)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _plate(parent: Control, at: Vector2, sz: Vector2, bg: Color = Color("2f1d20ed"), edge: Color = Color("df9d43")) -> Panel:
	var p := Panel.new()
	p.position = at
	p.size = sz
	p.add_theme_stylebox_override("panel",_box_style(bg,edge,14,3))
	parent.add_child(p)
	return p

func _hotspot(parent: Control, bounds: Rect2, action: Callable) -> Button:
	var b := Button.new()
	b.position = bounds.position
	b.size = bounds.size
	b.pivot_offset = bounds.size*.5
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",_box_style(Color(0,0,0,0),Color(0,0,0,0),13,0))
	b.add_theme_stylebox_override("hover",_box_style(Color(1,.81,.40,.14),Color("ffe38b"),13,3))
	b.add_theme_stylebox_override("pressed",_box_style(Color(1,.85,.49,.21),Color("fff4be"),13,4))
	b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	parent.add_child(b)
	b.pressed.connect(action)
	b.mouse_entered.connect(_hover_button.bind(b,true))
	b.mouse_exited.connect(_hover_button.bind(b,false))
	return b

func _hover_button(button: Button, enters: bool) -> void:
	if enters:
		_sound("tap")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button,"scale",Vector2(1.027,1.027) if enters else Vector2.ONE,.14)

func _action_button(parent: Control, text: String, bounds: Rect2, callback: Callable, bright: bool = false, size: int = 25) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = bounds.position
	btn.size = bounds.size
	btn.pivot_offset = btn.size*.5
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size",size)
	btn.add_theme_color_override("font_color",Color("fff1bd"))
	btn.add_theme_color_override("font_hover_color",Color.WHITE)
	btn.add_theme_color_override("font_pressed_color",Color.WHITE)
	var dark := Color("436e3c") if bright else Color("69422f")
	var highlight := Color("80e362") if bright else Color("e4b16e")
	btn.add_theme_stylebox_override("normal",_box_style(dark,highlight,15,3))
	btn.add_theme_stylebox_override("hover",_box_style(dark.lightened(.19),Color("fff1b4"),15,4))
	btn.add_theme_stylebox_override("pressed",_box_style(dark.darkened(.1),Color("f9e4a3"),15,4))
	btn.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	btn.pressed.connect(callback)
	btn.mouse_entered.connect(_hover_button.bind(btn,true))
	btn.mouse_exited.connect(_hover_button.bind(btn,false))
	parent.add_child(btn)
	return btn

func _scrim(parent: Control, opacity: float = .83) -> void:
	var r := ColorRect.new()
	r.color = Color(0.035,.082,.13,opacity)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

func _menu_money(screen: Control) -> void:
	var patch := ColorRect.new()
	patch.position = Vector2(1455,39)
	patch.size = Vector2(112,35)
	patch.color = Color("402d27")
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(patch)
	menu_wallet_label = _label(screen,_money(wallet),Vector2(1455,37),Vector2(112,42),26,Color("fff2cc"))

func _build_main_menu() -> void:
	var m := _blank_screen("menu",menu_texture)
	_menu_money(m)
	var buttons := [
		{"area":Rect2(472,309,703,91),"call":Callable(self,"_open_worlds")},
		{"area":Rect2(472,420,703,91),"call":Callable(self,"_open_shop")},
		{"area":Rect2(472,530,703,91),"call":Callable(self,"_open_settings")},
		{"area":Rect2(472,643,703,90),"call":Callable(get_tree(),"quit")}
	]
	for item in buttons:
		_hotspot(m,item["area"],item["call"])

func _build_shop() -> void:
	var shop := _blank_screen("shop",shop_texture)
	# Repaint currency number from the original concept image with live saved balance.
	var patch := ColorRect.new()
	patch.position = Vector2(1452,41)
	patch.size = Vector2(114,34)
	patch.color = Color("422c24")
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop.add_child(patch)
	shop_wallet_label = _label(shop,"",Vector2(1452,39),Vector2(114,38),26)
	_hotspot(shop,Rect2(48,29,69,61),Callable(self,"_leave"))
	_hotspot(shop,Rect2(44,854,184,59),Callable(self,"_leave"))
	var categories := ["Все персонажи","Бегуны","Воины","Маги","Будущее","Маскоты"]
	var category_areas := [Rect2(84,159,258,44),Rect2(358,159,212,44),Rect2(588,159,231,44),Rect2(836,159,222,44),Rect2(1071,159,225,44),Rect2(1315,159,237,44)]
	for j in range(categories.size()):
		_hotspot(shop,category_areas[j],_set_category.bind(categories[j]))
	# Each card has its own hover sprite, selectable region, and actual data.
	var row_positions := [212,350,481,609,727]
	for i in range(characters.size()):
		var col := i%10
		var row := int(i/10)
		var x := float(82+col*151)
		var y := float(row_positions[row])
		var card_rect := Rect2(x,y,149,116)
		var dark_overlay := ColorRect.new()
		dark_overlay.position = card_rect.position
		dark_overlay.size = card_rect.size
		dark_overlay.color = Color(0,0,0,.64)
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dark_overlay.visible = false
		shop.add_child(dark_overlay)
		shop_dim.append(dark_overlay)
		var zoom := TextureRect.new()
		zoom.texture = portraits[i]
		zoom.position = Vector2(x+4,y+3)
		zoom.size = Vector2(141,79)
		zoom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		zoom.stretch_mode = TextureRect.STRETCH_SCALE
		zoom.pivot_offset = zoom.size*.5
		zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zoom.modulate.a = 0.0
		shop.add_child(zoom)
		shop_portrait_zooms.append(zoom)
		var b := _hotspot(shop,card_rect,_select_shop_hero.bind(i))
		b.mouse_entered.connect(_zoom_card.bind(i,true))
		b.mouse_exited.connect(_zoom_card.bind(i,false))
		shop_focus_buttons.append(b)
	# The selected-character lower panel is redrawn from true store state.
	_plate(shop,Vector2(873,853),Vector2(742,72),Color("35211df7"),Color("ffa941"))
	shop_avatar_preview = TextureRect.new()
	shop_avatar_preview.position = Vector2(892,859)
	shop_avatar_preview.size = Vector2(92,60)
	shop_avatar_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shop_avatar_preview.stretch_mode = TextureRect.STRETCH_SCALE
	shop_avatar_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop.add_child(shop_avatar_preview)
	shop_name_label = _label(shop,"",Vector2(994,856),Vector2(166,29),22)
	shop_price_label = _label(shop,"",Vector2(994,883),Vector2(166,31),20,Color("ffcf78"))
	shop_perk_label = _label(shop,"",Vector2(1163,857),Vector2(238,61),18,Color("dbf7ce"))
	shop_buy_button = _action_button(shop,"КУПИТЬ",Rect2(1407,858,198,59),Callable(self,"_buy_hero"),true,23)
	shop_notice_label = _label(shop,"",Vector2(834,819),Vector2(800,31),20,Color("ffdeab"))
	# Correct the single duplicated price on the user-approved illustration.
	_plate(shop,Vector2(272,798),Vector2(110,27),Color("3e231aea"),Color("a47b48"))
	_label(shop,"◉ 5 075",Vector2(274,799),Vector2(106,25),18)

func _zoom_card(index: int, hover: bool) -> void:
	var sprite := shop_portrait_zooms[index]
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite,"modulate:a",1.0 if hover else 0.0,.13)
	tween.tween_property(sprite,"scale",Vector2(1.09,1.09) if hover else Vector2.ONE,.15)

func _set_category(category: String) -> void:
	chosen_category = category
	_sound("tap")
	for i in range(characters.size()):
		var filtered := category != "Все персонажи" and String(characters[i]["category"]) != category
		shop_dim[i].visible = filtered
		shop_focus_buttons[i].disabled = filtered
		shop_portrait_zooms[i].modulate.a = 0.0
	shop_notice_label.text = "" if category == "Все персонажи" else "Категория:  " + category

func _open_shop() -> void:
	_sound("tap")
	focused_hero = max(0,focused_hero)
	_set_category("Все персонажи")
	_update_shop()
	_show("shop")

func _select_shop_hero(index: int) -> void:
	focused_hero = index
	_sound("tap")
	shop_notice_label.text = ""
	_update_shop()

func _update_shop() -> void:
	if characters.is_empty():
		return
	var c: Dictionary = characters[focused_hero]
	shop_wallet_label.text = _money(wallet)
	shop_name_label.text = String(c["name"])
	shop_avatar_preview.texture = portraits[focused_hero]
	var price := _price(focused_hero)
	shop_price_label.text = "◉  " + _money(price)
	shop_perk_label.text = String(c["perk"])
	if owned_heroes.has(focused_hero):
		shop_buy_button.text = "ВЫБРАН" if selected_hero == focused_hero else "ВЫБРАТЬ"
	else:
		shop_buy_button.text = "КУПИТЬ"
	for j in range(shop_focus_buttons.size()):
		if j == focused_hero:
			shop_focus_buttons[j].add_theme_stylebox_override("normal",_box_style(Color(1,.68,.32,.09),Color("ffd77c"),13,3))
		else:
			shop_focus_buttons[j].add_theme_stylebox_override("normal",_box_style(Color(0,0,0,0),Color(0,0,0,0),13,0))

func _price(index: int) -> int:
	var price := int(characters[index]["price"])
	if _perk("shop_discount") > 0:
		price = int(round(price*(1.0-_perk("shop_discount"))))
	return price

func _buy_hero() -> void:
	if owned_heroes.has(focused_hero):
		selected_hero = focused_hero
		_sound("buy")
		shop_notice_label.text = "ПЕРСОНАЖ ВЫБРАН!"
	else:
		var price := _price(focused_hero)
		if wallet < price:
			shop_notice_label.text = "НУЖНО ЕЩЁ %s МОНЕТ" % _money(price-wallet)
			_sound("hit")
			return
		wallet -= price
		owned_heroes.append(focused_hero)
		selected_hero = focused_hero
		shop_notice_label.text = "ОТКРЫТ ПЕРСОНАЖ: " + String(characters[focused_hero]["name"])
		_sound("buy")
	_equip_hero()
	_save()
	_update_shop()

func _open_worlds() -> void:
	_sound("tap")
	_refresh_worlds()
	_show("worlds")

func _build_world_selector() -> void:
	var ui := _blank_screen("worlds",menu_texture)
	_scrim(ui,.83)
	_label(ui,"ВЫБОР МИРА",Vector2(250,80),Vector2(1172,91),71,Color("ffdb84"))
	world_money_label = _label(ui,"",Vector2(1050,176),Vector2(465,50),29)
	world_buttons.clear()
	var icon_chars := ["🌳","☀","❄","🌴","🌋"]
	for i in range(world_styles.size()):
		var x := 78.0+float(i)*311.5
		var col: Color = world_styles[i]["sky"]
		_plate(ui,Vector2(x,257),Vector2(285,405),Color("2e2e36e8"),col)
		var title_label := _label(ui,icon_chars[i],Vector2(x+20,269),Vector2(245,105),71,col)
		title_label.add_theme_color_override("font_color",col)
		_label(ui,String(world_styles[i]["name"]),Vector2(x+9,392),Vector2(267,89),31,Color("ffdf9d"))
		_label(ui,"Уникальная локация\nс собственными препятствиями",Vector2(x+15,499),Vector2(253,74),20)
		var btn := _action_button(ui,"",Rect2(x+23,581,239,62),_select_world.bind(i),false,22)
		world_buttons.append(btn)
	_action_button(ui,"← НАЗАД",Rect2(79,747,253,68),Callable(self,"_leave"))
	_action_button(ui,"▶ ИГРАТЬ",Rect2(1330,747,263,68),Callable(self,"_start"),true)
	world_title_label = _label(ui,"Выбран: Зелёная долина",Vector2(415,744),Vector2(792,69),29)
	_label(ui,"MgameIO",Vector2(650,875),Vector2(372,37),25)

func _refresh_worlds() -> void:
	world_money_label.text = "МОИ МОНЕТЫ:  ◉ " + _money(wallet)
	world_title_label.text = "ВЫБРАН:  " + String(world_styles[world_index]["name"]).to_upper()
	for i in range(world_buttons.size()):
		var btn := world_buttons[i]
		if i == world_index:
			btn.text = "✓ ВЫБРАН"
		elif owned_worlds.has(i):
			btn.text = "ВЫБРАТЬ"
		else:
			btn.text = "◉ %s" % _money(int(world_styles[i]["price"]))

func _select_world(index: int) -> void:
	if owned_worlds.has(index):
		_set_world(index)
		_sound("tap")
	else:
		var amount := int(world_styles[index]["price"])
		if wallet < amount:
			world_title_label.text = "НЕ ХВАТАЕТ  ◉ %s" % _money(amount-wallet)
			_sound("hit")
			return
		wallet -= amount
		owned_worlds.append(index)
		_set_world(index)
		_sound("buy")
	_refresh_worlds()

func _build_settings() -> void:
	var s := _blank_screen("settings",menu_texture)
	_scrim(s,.86)
	_plate(s,Vector2(451,178),Vector2(770,584))
	_label(s,"НАСТРОЙКИ",Vector2(470,194),Vector2(730,80),66,Color("ffdc83"))
	sound_btn = _action_button(s,"",Rect2(535,322,605,76),Callable(self,"_toggle_audio"),false,29)
	full_btn = _action_button(s,"",Rect2(535,431,605,76),Callable(self,"_toggle_fullscreen"),false,29)
	_action_button(s,"← НАЗАД",Rect2(559,611,551,78),Callable(self,"_leave"),true,30)
	_label(s,"MgameIO",Vector2(666,865),Vector2(333,39),25)

func _open_settings() -> void:
	_sound("tap")
	_update_settings()
	_show("settings")

func _update_settings() -> void:
	sound_btn.text = "ЗВУК:  ВКЛ" if audio_on else "ЗВУК:  ВЫКЛ"
	full_btn.text = "ЭКРАН:  ПОЛНЫЙ" if fullscreen else "ЭКРАН:  ОКНО"

func _toggle_audio() -> void:
	audio_on = not audio_on
	_save()
	_update_settings()
	_sound("tap")

func _toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	_save()
	_update_settings()

func _build_game_hud() -> void:
	var h := _blank_screen("playing")
	_plate(h,Vector2(28,25),Vector2(900,85),Color("1c2733e8"),Color("e4b36b"))
	hud_score = _label(h,"",Vector2(47,34),Vector2(865,68),34,Color("ffebb5"))
	_plate(h,Vector2(1120,25),Vector2(520,85),Color("1c2733e8"),Color("e4b36b"))
	hud_wallet = _label(h,"",Vector2(1137,34),Vector2(490,68),32,Color("ffcb66"))
	_plate(h,Vector2(27,126),Vector2(440,66),Color("213c3ccf"),Color("a6dac7"))
	hud_heart = _label(h,"♥ ♥ ♥",Vector2(45,131),Vector2(401,55),38,Color("ff9fa8"))
	_plate(h,Vector2(1233,126),Vector2(408,66),Color("213c3ccf"),Color("a6dac7"))
	hud_world = _label(h,"",Vector2(1240,133),Vector2(391,55),24)
	_plate(h,Vector2(609,762),Vector2(455,74),Color("222932dc"),Color("e6ba6b"))
	hud_combo = _label(h,"",Vector2(628,774),Vector2(420,56),33,Color("ffcc75"))
	_plate(h,Vector2(1242,773),Vector2(407,77),Color("222932e8"),Color("e6ba6b"))
	hud_ability = _label(h,"",Vector2(1250,779),Vector2(391,64),22)
	_label(h,"← / A  ВЛЕВО      → / D  ВПРАВО      ПРОБЕЛ  ПРЫЖОК      ↓ / S  ПОДКАТ      SHIFT  РЫВОК",Vector2(70,869),Vector2(1520,57),23,Color("f7e6c2"))
	_action_button(h,"Ⅱ",Rect2(1542,213,100,69),Callable(self,"_pause"),false,37)

func _pause() -> void:
	if state == "playing":
		_show("pause")

func _build_pause() -> void:
	var p := _blank_screen("pause",menu_texture)
	_scrim(p,.86)
	_plate(p,Vector2(483,199),Vector2(708,522))
	_label(p,"ПАУЗА",Vector2(514,213),Vector2(646,99),74,Color("ffdc86"))
	pause_status = _label(p,"",Vector2(523,320),Vector2(628,75),25)
	_action_button(p,"▶ ПРОДОЛЖИТЬ",Rect2(563,426,546,79),Callable(self,"_resume"),true,30)
	_action_button(p,"⌂ В ГЛАВНОЕ МЕНЮ",Rect2(563,544,546,79),Callable(self,"_leave"),false,28)
	_label(p,"MgameIO",Vector2(680,870),Vector2(310,42),25)

func _resume() -> void:
	_show("playing")

func _build_game_over() -> void:
	var o := _blank_screen("over",menu_texture)
	_scrim(o,.86)
	_plate(o,Vector2(414,176),Vector2(840,613))
	_label(o,"ЗАБЕГ ОКОНЧЕН",Vector2(430,204),Vector2(806,106),59,Color("ffdd81"))
	over_result = _label(o,"",Vector2(469,335),Vector2(728,89),31)
	over_details = _label(o,"",Vector2(469,427),Vector2(728,86),26)
	_action_button(o,"↻ ЕЩЁ РАЗ",Rect2(498,560,678,71),Callable(self,"_start"),true,31)
	_action_button(o,"⌂ В ГЛАВНОЕ МЕНЮ",Rect2(498,651,678,72),Callable(self,"_leave"),false,29)
	_label(o,"MgameIO",Vector2(682,876),Vector2(300,40),25)

func _show(mode: String) -> void:
	state = mode
	for key in screens.keys():
		var node: Control = screens[key]
		node.visible = String(key) == mode
	if mode == "menu":
		menu_wallet_label.text = _money(wallet)
		_save()
	elif mode == "shop":
		_update_shop()
	elif mode == "pause":
		pause_status.text = "Очки: %d       Монеты: +%d" % [_score(),earned_this_run]
	elif mode == "playing":
		_update_hud()
