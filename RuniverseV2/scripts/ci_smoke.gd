extends SceneTree
## Tests the user-facing game flows in real Godot (not only source parsing).

func _initialize() -> void:
	call_deferred("_run_checks")

func _fail(message: String) -> void:
	push_error("TEST FAILED: " + message)
	quit(1)

func _run_checks() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	var roster: Array = game.get("characters")
	if roster.size() != 50:
		_fail("Expected 50 shop heroes")
		return
	game.set("wallet",100000)
	game.call("_open_shop")
	if game.get("state") != "shop":
		_fail("Shop did not open")
		return
	game.call("_select_shop_hero",37)
	game.call("_buy_hero")
	if game.get("selected_hero") != 37:
		_fail("Character purchase / equip did not work")
		return
	game.call("_open_worlds")
	game.call("_select_world",4)
	if game.get("world_index") != 4:
		_fail("World purchase and selection failed")
		return
	game.call("_start")
	if game.get("state") != "playing":
		_fail("Gameplay did not start")
		return
	game.call("_spawn_wave")
	game.call("_dash")
	game.set("player_lane",0)
	game.set("jump_v",13.0)
	for frame in range(90):
		await process_frame
	game.call("_game_over")
	if game.get("state") != "over":
		_fail("Game-over screen failed")
		return
	print("RUNIVERSE TEST PASSED: 50 heroes, purchase, world, animated run, game-over")
	quit(0)
