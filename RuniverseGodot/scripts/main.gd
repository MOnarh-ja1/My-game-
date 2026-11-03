extends Node3D
## RUNIVERSE: complete original Godot 4 3D endless runner.
## No clearing a framebuffer per frame, no forced refreshes: engine-controlled continuous rendering.

const Art = preload("res://scripts/world_art.gd")
const Runner = preload("res://scripts/character.gd")
const SAVE_PATH := "user://runiverse_save.cfg"
const LANES := [-3.1, 0.0, 3.1]
const PLAYER_Z := 3.6
const CHUNK_LENGTH := 26.0

var rng := RandomNumberGenerator.new()
var worlds: Array[Dictionary] = []
var unlocked: Array[int] = [0]
var selected_world: int = 0
var wallet: int = 0
var record: int = 0
var mute: bool = false

var state: String = "menu" # menu, shop, running, pause, over
var current_lane: int = 1
var jump_velocity: float = 0.0
var sliding_timer: float = 0.0
var invincible_timer: float = 0.0
var run_coins: int = 0
var distance: float = 0.0
var speed: float = 24.0
var hp: int = 3
var wave_timer: float = 1.0
var coins_clock: float = 0.0
var game_time: float = 0.0

var environment: WorldEnvironment
var sunlight: DirectionalLight3D
var camera: Camera3D
var world_root: Node3D
var character: Node3D
var pieces: Array[Node3D] = []
var items: Array[Dictionary] = []
var sound_nodes: Dictionary = {}

var canvas_layer: CanvasLayer
var ui: Control
var shade: ColorRect
var menu_panel: PanelContainer
var shop_panel: PanelContainer
var pause_panel: PanelContainer
var over_panel: PanelContainer
var hud: PanelContainer
var hud_score: Label
var hud_coins: Label
var hud_hp: Label
var hud_world: Label
var menu_wallet: Label
var menu_world: Label
var best_label: Label
var shop_wallet: Label
var shop_cards: HBoxContainer
var over_label: Label
var over_best: Label

func _ready() -> void:
	rng.randomize()
	_init_worlds()
	_load_data()
	_create_scene()
	_make_sounds()
	_make_ui()
	_set_biome(selected_world)
	_set_state("menu")

func _init_worlds() -> void:
	worlds = [
		{"title":"ЗЕЛЁНАЯ ДОЛИНА", "subtitle":"Солнечный лес, ели и поляны", "price":0, "sky":Color("9bd9fb"), "ground":Color("78b96b"), "road":Color("c29a68"), "edge":Color("e3d7b3"), "line":Color("f9e4c2"), "stone":Color("c7cfa5"), "outfit":Color("2aa7a1"), "obstacle":Color("b56b42"), "accent":Color("65e3a1")},
		{"title":"ПЕСКИ ВРЕМЕНИ", "subtitle":"Каньоны, кактусы, древние руины", "price":80, "sky":Color("ffc99c"), "ground":Color("eac17c"), "road":Color("b78e61"), "edge":Color("fff0b8"), "line":Color("f7d7a0"), "stone":Color("c38d5a"), "outfit":Color("ed9f45"), "obstacle":Color("c27b4c"), "accent":Color("ffd16a")},
		{"title":"СНЕЖНЫЕ ПИКИ", "subtitle":"Мороз, кристаллы и снежные ели", "price":200, "sky":Color("a8dcf7"), "ground":Color("e5f1fa"), "road":Color("94bdcf"), "edge":Color("f9ffff"), "line":Color("edfaff"), "stone":Color("bed8e8"), "outfit":Color("4b98c9"), "obstacle":Color("4a89b3"), "accent":Color("9feaff")},
		{"title":"ДИКИЕ ДЖУНГЛИ", "subtitle":"Пальмы, лианы, затерянные тайны", "price":420, "sky":Color("a9e7c3"), "ground":Color("3d9b65"), "road":Color("b59a71"), "edge":Color("e5dcb0"), "line":Color("f4dfb0"), "stone":Color("78a885"), "outfit":Color("cc578e"), "obstacle":Color("9f704a"), "accent":Color("7af7b1")},
		{"title":"ОСТРОВ ВУЛКАНОВ", "subtitle":"Лава, обсидиан и огненные горы", "price":800, "sky":Color("df937b"), "ground":Color("514653"), "road":Color("665461"), "edge":Color("ff9455"), "line":Color("f2ae83"), "stone":Color("88727d"), "outfit":Color("b65d53"), "obstacle":Color("a4524a"), "accent":Color("ffac62")}
	]

func _load_data() -> void:
	var f := ConfigFile.new()
	if f.load(SAVE_PATH) != OK:
		return
	wallet = maxi(0,int(f.get_value("progress","wallet",0)))
	record = maxi(0,int(f.get_value("progress","record",0)))
	selected_world = clampi(int(f.get_value("progress","world",0)),0,worlds.size()-1)
	mute = bool(f.get_value("settings","muted",false))
	var saved: Array = f.get_value("progress","unlocked",[0])
	unlocked.clear()
	unlocked.append(0)
	for value in saved:
		var n := int(value)
		if n >= 0 and n < worlds.size() and not unlocked.has(n):
			unlocked.append(n)
	if not unlocked.has(selected_world):
		selected_world = 0

func _save_data() -> void:
	var f := ConfigFile.new()
	f.set_value("progress","wallet",wallet)
	f.set_value("progress","record",record)
	f.set_value("progress","world",selected_world)
	f.set_value("progress","unlocked",unlocked)
	f.set_value("settings","muted",mute)
	f.save(SAVE_PATH)

func _create_scene() -> void:
	world_root = Node3D.new()
	world_root.name = "LivingWorld"
	add_child(world_root)
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9bd9fb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e7f4ff")
	env.ambient_light_energy = 0.86
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	sunlight = DirectionalLight3D.new()
	sunlight.name = "WarmSunlight"
	sunlight.rotation = Vector3(-0.83,-0.5,0.15)
	sunlight.light_energy = 1.25
	sunlight.light_color = Color("fff0d8")
	sunlight.shadow_enabled = true
	add_child(sunlight)
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.position = Vector3(0,5.6,12.9)
	camera.fov = 68.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0,1.15,-10.0),Vector3.UP)
	character = Runner.new()
	character.name = "AnimatedExplorer"
	character.position = Vector3(0,0,PLAYER_Z)
	add_child(character)
	var shadow := Art.make_mesh(self,"cylinder",Vector3(1.05,0.025,0.68),Vector3(0,0.065,PLAYER_Z),Color("51675d"))
	shadow.name = "CharacterContactShadow"
	shadow.set_meta("follow_character",true)

func _set_biome(index: int) -> void:
	var color: Dictionary = worlds[index]
	environment.environment.background_color = color["sky"]
	sunlight.light_color = Color("ffe6c0") if index == 1 or index == 4 else Color("f2f8ff")
	character.set_outfit(color["outfit"])
	for child in world_root.get_children():
		world_root.remove_child(child)
		child.queue_free()
	pieces.clear()
	items.clear()
	for z in [-65.0,-39.0,-13.0,13.0,39.0]:
		pieces.append(Art.ground(world_root,index,z,color,rng))

func _make_sounds() -> void:
	for key in ["coin","jump","slide","hit","button","unlock","over"]:
		var pitch := 600.0
		match key:
			"coin": pitch = 900.0
			"jump": pitch = 410.0
			"slide": pitch = 230.0
			"hit": pitch = 120.0
			"button": pitch = 540.0
			"unlock": pitch = 740.0
			"over": pitch = 180.0
		var audio := AudioStreamPlayer.new()
		audio.stream = _synthesize(pitch,0.13 if key != "over" else 0.35)
		audio.volume_db = -17.0
		add_child(audio)
		sound_nodes[key] = audio

func _synthesize(frequency: float, duration: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var count := int(22050.0 * duration)
	var samples := PackedByteArray()
	samples.resize(count*2)
	for i in range(count):
		var t := float(i)/22050.0
		var fade := pow(1.0-t/duration,1.65)
		var value := int(sin(t*TAU*frequency*(1.0+t*0.2/duration))*fade*17000.0)
		samples[i*2] = value&255
		samples[i*2+1] = (value>>8)&255
	stream.data = samples
	return stream

func _sound(key: String) -> void:
	if not mute and sound_nodes.has(key):
		var a: AudioStreamPlayer = sound_nodes[key]
		a.stop()
		a.play()

func _process(delta: float) -> void:
	if state == "running":
		_update_game(minf(delta,0.05))
	elif state == "menu" or state == "shop":
		character.animate(minf(delta,0.05),false,false,false,0.0)
	var x_target: float = LANES[current_lane]
	character.position.x = lerpf(character.position.x,x_target,minf(delta*12.0,1.0))
	for child in get_children():
		if child.has_meta("follow_character"):
			child.position.x = character.position.x
	camera.position.x = lerpf(camera.position.x,character.position.x*0.16,minf(delta*2.6,1.0))
	camera.look_at(Vector3(camera.position.x*0.4,1.25,-10.0),Vector3.UP)

func _update_game(delta: float) -> void:
	game_time += delta
	speed = minf(24.0+distance*0.017,47.0)
	distance += speed*delta
	invincible_timer = maxf(0.0,invincible_timer-delta)
	sliding_timer = maxf(0.0,sliding_timer-delta)
	character.position.y += jump_velocity*delta
	jump_velocity -= 29.0*delta
	if character.position.y <= 0.0:
		character.position.y = 0.0
		jump_velocity = maxf(0.0,jump_velocity)
	var airborne := character.position.y > 0.12
	character.animate(delta,true,sliding_timer > 0.0,airborne,speed/40.0)
	var backmost: float = 9999.0
	for chunk in pieces:
		chunk.position.z += speed*delta
		backmost = minf(backmost,chunk.position.z)
	for chunk in pieces:
		if chunk.position.z > 50.0:
			chunk.position.z = backmost-CHUNK_LENGTH
			backmost = chunk.position.z
			# Props stay attached to moving ground: no redrawing / flashing.
	wave_timer -= delta
	if wave_timer <= 0.0:
		_spawn_wave()
		wave_timer = maxf(0.82,1.47-distance/7000.0)+rng.randf_range(-0.14,0.16)
	for i in range(items.size()-1,-1,-1):
		var info: Dictionary = items[i]
		var node: Node3D = info["node"]
		node.position.z += speed*delta
		if info["kind"] == "coin":
			node.rotation.y += delta*4.9
			node.position.y = 1.27+sin(game_time*5.0+float(info["offset"]))*0.15
		if node.position.z > PLAYER_Z+4.0:
			_remove_item(i)
			continue
		if absf(node.position.z-PLAYER_Z) < 1.0 and int(info["lane"]) == current_lane:
			if info["kind"] == "coin":
				if absf(character.position.y-node.position.y) < 2.5:
					run_coins += 1
					wallet += 1
					_sound("coin")
					_remove_item(i)
			else:
				var safe: bool = (info["kind"] == "hurdle" and character.position.y > 0.95) or (info["kind"] == "gate" and sliding_timer > 0.1)
				if not safe and invincible_timer <= 0.0:
					_damage()
					if state != "running":
						break
					_remove_item(i)
					elif safe:
					_remove_item(i)
	if is_instance_valid(hud_score):
		hud_score.text = "ОЧКИ  %06d" % _score()
		hud_coins.text = "●  %d" % run_coins
		hud_hp.text = "ЖИЗНИ  %s" % ("♥ ".repeat(hp))

func _remove_item(index: int) -> void:
	var info: Dictionary = items[index]
	var node: Node3D = info["node"]
	items.remove_at(index)
	if is_instance_valid(node):
		node.queue_free()

func _spawn_wave() -> void:
	var first := rng.randi_range(0,2)
	var kind := ["crate","hurdle","gate"][rng.randi_range(0,2)]
	var color: Dictionary = worlds[selected_world]
	_spawn_obstacle(first,kind,-84.0,color)
	# Two hazards only sometimes, ALWAYS leaves a navigable lane.
	if distance > 150.0 and rng.randf() < 0.28:
		var second := (first+1+rng.randi_range(0,1))%3
		_spawn_obstacle(second,["crate","hurdle","gate"][rng.randi_range(0,2)],-84.0,color)
	var coin_lane := (first+1+rng.randi_range(0,1))%3
	for j in range(4):
		var n := Art.coin(world_root)
		n.position = Vector3(LANES[coin_lane],1.25,-72.0-float(j)*2.8)
		items.append({"node":n,"kind":"coin","lane":coin_lane,"offset":rng.randf_range(0.0,TAU)})

func _spawn_obstacle(lane: int,kind: String,z: float,color: Dictionary) -> void:
	var n := Art.obstacle(world_root,kind,selected_world,color["obstacle"])
	n.position = Vector3(LANES[lane],0,z)
	items.append({"node":n,"kind":kind,"lane":lane,"offset":0.0})

func _damage() -> void:
	hp -= 1
	_sound("hit")
	invincible_timer = 1.6
	if hp <= 0:
		_finish()

func _score() -> int:
	return int(distance*5.0)+run_coins*20

func _start_game() -> void:
	_sound("button")
	_set_biome(selected_world)
	current_lane = 1
	character.position = Vector3(0,0,PLAYER_Z)
	character.body.scale.y = 1.0
	jump_velocity = 0.0
	sliding_timer = 0.0
	invincible_timer = 0.0
	distance = 0.0
	run_coins = 0
	hp = 3
	game_time = 0.0
	wave_timer = 1.5
	_set_state("running")

func _finish() -> void:
	_sound("over")
	if _score() > record:
		record = _score()
	_save_data()
	over_label.text = "ТВОЙ РЕЗУЛЬТАТ   %06d\nСОБРАНО МОНЕТ   %d" % [_score(),run_coins]
	over_best.text = "ЛУЧШИЙ РЕЗУЛЬТАТ   %06d" % record
	_set_state("over")

func _toggle_pause() -> void:
	if state == "running":
		_set_state("pause")
	elif state == "pause":
		_set_state("running")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key == KEY_ESCAPE or key == KEY_P:
			if state == "running" or state == "pause":
				_toggle_pause()
			elif state == "shop":
				_set_state("menu")
			return
		if key == KEY_M:
			mute = not mute
			_save_data()
		if state == "running":
			match key:
				KEY_A,KEY_LEFT:
					current_lane = maxi(0,current_lane-1)
				KEY_D,KEY_RIGHT:
					current_lane = mini(2,current_lane+1)
				KEY_W,KEY_UP,KEY_SPACE:
					if character.position.y <= 0.02 and sliding_timer <= 0.05:
						jump_velocity = 12.7
						_sound("jump")
				KEY_S,KEY_DOWN,KEY_CTRL:
					if character.position.y <= 0.02:
						sliding_timer = 0.83
						_sound("slide")
		elif state == "over" and (key == KEY_ENTER or key == KEY_R):
			_start_game()

# ------------------------------- UI --------------------------------
func _style(fill: Color, border: Color = Color("ffffff"), radius: int = 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 14.0
	s.content_margin_bottom = 14.0
	return s

func _label(text: String,size: int,color: Color,bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color",color)
	l.add_theme_font_size_override("font_size",size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bold:
		l.add_theme_color_override("font_shadow_color",Color("263949"))
		l.add_theme_constant_override("shadow_offset_y",2)
	return l

func _button(text: String,background: Color,action: Callable,size: int = 21) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170,55)
	b.add_theme_font_size_override("font_size",size)
	b.add_theme_color_override("font_color",Color("173343"))
	b.add_theme_color_override("font_hover_color",Color("163444"))
	b.add_theme_color_override("font_pressed_color",Color("163444"))
	b.add_theme_stylebox_override("normal",_style(background,background.lightened(0.13),16))
	b.add_theme_stylebox_override("hover",_style(background.lightened(0.13),Color.WHITE,16))
	b.add_theme_stylebox_override("pressed",_style(background.darkened(0.07),Color.WHITE,16))
	b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	b.pressed.connect(action)
	return b

func _new_panel(width: float,height: float) -> PanelContainer:
	var p := PanelContainer.new()
	ui.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -width/2.0
	p.offset_top = -height/2.0
	p.offset_right = width/2.0
	p.offset_bottom = height/2.0
	p.add_theme_stylebox_override("panel",_style(Color("193549f2"),Color("a6dbd6"),24))
	return p

func _vbox(parent: Node) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",13)
	parent.add_child(v)
	return v

func _spacer(parent: Node,height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)

func _make_ui() -> void:
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(ui)
	shade = ColorRect.new()
	shade.color = Color("101e2b99")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	_build_menu()
	_build_shop()
	_build_pause()
	_build_over()
	_build_hud()

func _build_menu() -> void:
	menu_panel = _new_panel(580,560)
	var box := _vbox(menu_panel)
	_spacer(box,14)
	box.add_child(_label("RUNIVERSE",51,Color("ffdf8d"),true))
	box.add_child(_label("МИРЫ НА БЕГУ  •  3D ПРИКЛЮЧЕНИЕ",19,Color("d5f4e9")))
	_spacer(box,17)
	menu_world = _label("",23,Color("ffffff"),true)
	box.add_child(menu_world)
	menu_wallet = _label("",21,Color("ffe19a"))
	box.add_child(menu_wallet)
	best_label = _label("",18,Color("bfe4e0"))
	box.add_child(best_label)
	_spacer(box,21)
	box.add_child(_button("▶   ИГРАТЬ",Color("75dfaa"),func():_start_game(),26))
	box.add_child(_button("🌍   МАГАЗИН МИРОВ",Color("ffd18b"),func():_open_shop(),21))
	_spacer(box,11)
	box.add_child(_label("← →  дорожки    •    ПРОБЕЛ  прыжок    •    ↓  подкат",15,Color("cbdae2")))
	box.add_child(_label("ESC  пауза    •    M  звук",15,Color("cbdae2")))

func _build_shop() -> void:
	shop_panel = _new_panel(1210,595)
	var box := _vbox(shop_panel)
	box.add_child(_label("ВЫБЕРИ СВОЙ МИР",38,Color("fff0b8"),true))
	shop_wallet = _label("",21,Color("ffdda0"))
	box.add_child(shop_wallet)
	box.add_child(_label("Собирай монеты во время забега и открывай новые локации",17,Color("c5dfdf")))
	_spacer(box,15)
	shop_cards = HBoxContainer.new()
	shop_cards.add_theme_constant_override("separation",10)
	box.add_child(shop_cards)
	_spacer(box,12)
	box.add_child(_button("←   НАЗАД В МЕНЮ",Color("9bcee1"),func():_set_state("menu"),19))

func _make_card(i: int) -> PanelContainer:
	var world: Dictionary = worlds[i]
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(217,340)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel",_style(Color("27465b"),world["accent"],16))
	var v := _vbox(p)
	var swatch := ColorRect.new()
	swatch.color = world["sky"]
	swatch.custom_minimum_size.y = 76
	v.add_child(swatch)
	v.add_child(_label(world["title"],17,Color.WHITE,true))
	var desc := _label(world["subtitle"],13,Color("cde6e5"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.y = 55
	v.add_child(desc)
	_spacer(v,4)
	var own := unlocked.has(i)
	var selection := i == selected_world
	var price := "✓  ВЫБРАН" if selection else ("ВЫБРАТЬ" if own else "●  %d МОНЕТ" % int(world["price"]))
	var color: Color = Color("75dfaa") if own else Color("ffd18b")
	var idx := i
	var btn := _button(price,color,func():_buy_or_select(idx),16)
	btn.custom_minimum_size = Vector2(160,54)
	v.add_child(btn)
	return p

func _refresh_shop() -> void:
	shop_wallet.text = "ТВОИ МОНЕТЫ:  ●  %d" % wallet
	for child in shop_cards.get_children():
		shop_cards.remove_child(child)
		child.queue_free()
	for i in range(worlds.size()):
		shop_cards.add_child(_make_card(i))

func _buy_or_select(index: int) -> void:
	if unlocked.has(index):
		selected_world = index
		_sound("button")
		_set_biome(selected_world)
	else:
		var price: int = worlds[index]["price"]
		if wallet < price:
			shop_wallet.text = "НУЖНО ЕЩЁ  ●  %d  МОНЕТ" % (price-wallet)
			_sound("hit")
			return
		wallet -= price
		unlocked.append(index)
		selected_world = index
		_set_biome(selected_world)
		_sound("unlock")
	_save_data()
	_refresh_shop()

func _open_shop() -> void:
	_sound("button")
	_set_state("shop")

func _build_pause() -> void:
	pause_panel = _new_panel(480,350)
	var v := _vbox(pause_panel)
	v.add_child(_label("ПАУЗА",42,Color("fff0b8"),true))
	v.add_child(_label("Твоё путешествие подождёт",19,Color("cfe7e4")))
	_spacer(v,17)
	v.add_child(_button("▶   ПРОДОЛЖИТЬ",Color("75dfaa"),func():_toggle_pause()))
	v.add_child(_button("⌂   ГЛАВНОЕ МЕНЮ",Color("ffd18b"),func():_leave_run()))

func _build_over() -> void:
	over_panel = _new_panel(545,465)
	var v := _vbox(over_panel)
	v.add_child(_label("ЗАБЕГ ЗАВЕРШЁН",38,Color("ffdb9a"),true))
	_spacer(v,15)
	over_label = _label("",23,Color.WHITE,true)
	v.add_child(over_label)
	over_best = _label("",19,Color("a9eac7"))
	v.add_child(over_best)
	_spacer(v,21)
	v.add_child(_button("↻   ЕЩЁ РАЗ",Color("75dfaa"),func():_start_game()))
	v.add_child(_button("⌂   В МЕНЮ",Color("ffd18b"),func():_leave_run()))

func _build_hud() -> void:
	hud = PanelContainer.new()
	ui.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 24
	hud.offset_top = 15
	hud.offset_right = -24
	hud.offset_bottom = 94
	hud.add_theme_stylebox_override("panel",_style(Color("193549d9"),Color("a1d9cb"),16))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",26)
	hud.add_child(line)
	hud_score = _label("ОЧКИ  000000",24,Color.WHITE,true)
	hud_coins = _label("●  0",26,Color("ffdb75"),true)
	hud_hp = _label("ЖИЗНИ  ♥ ♥ ♥",22,Color("ff9aa0"),true)
	hud_world = _label("",17,Color("d0f0e9"))
	for l in [hud_score,hud_coins,hud_hp,hud_world]:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(l)
	var btn := _button("Ⅱ",Color("b5dada"),func():_toggle_pause(),26)
	btn.custom_minimum_size = Vector2(61,45)
	line.add_child(btn)

func _leave_run() -> void:
	_save_data()
	_set_state("menu")

func _set_state(next_state: String) -> void:
	state = next_state
	menu_panel.visible = next_state == "menu"
	shop_panel.visible = next_state == "shop"
	pause_panel.visible = next_state == "pause"
	over_panel.visible = next_state == "over"
	hud.visible = next_state == "running"
	shade.visible = next_state != "running"
	if next_state == "menu":
		menu_world.text = "ТВОЙ МИР:  " + str(worlds[selected_world]["title"])
		menu_wallet.text = "●  %d МОНЕТ" % wallet
		best_label.text = "ЛУЧШИЙ РЕЗУЛЬТАТ:  %06d" % record
	if next_state == "shop":
		_refresh_shop()
	if next_state == "running":
		hud_world.text = str(worlds[selected_world]["title"])
