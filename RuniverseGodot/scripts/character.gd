extends Node3D
## Animated original low-poly adventurer. Designed to run WITHOUT external models.

var body: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var scarf: Node3D
var animation_clock: float = 0.0
var surface_color: Color = Color("2ba8b2")
var playing: bool = false
var sliding: bool = false
var airborne: bool = false

func _ready() -> void:
	_rebuild()

func _mat(color: Color, metallic: float = 0.0, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.53
	if emission:
		material.emission_enabled = true
		material.emission = color * 0.5
	return material

func _mesh(parent: Node3D, name: String, type: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	var geometry: PrimitiveMesh
	match type:
		"sphere":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 16
			s.rings = 8
			geometry = s
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 12
			geometry = c
		_:
			geometry = BoxMesh.new()
	instance.mesh = geometry
	instance.material_override = _mat(color)
	instance.position = pos
	instance.scale = size
	parent.add_child(instance)
	return instance

func _rebuild() -> void:
	for node in get_children():
		node.queue_free()
	body = Node3D.new()
	body.name = "BodyRig"
	add_child(body)
	var navy := Color("233b56")
	var cream := Color("ffe2b9")
	var boots := Color("3d2b43")
	_mesh(body, "Vest", "box", Vector3(0.94, 1.05, 0.52), Vector3(0, 1.48, 0), surface_color)
	_mesh(body, "VestStripe", "box", Vector3(0.17, 0.78, 0.56), Vector3(0, 1.5, 0), Color("f7e9bb"))
	_mesh(body, "Belt", "box", Vector3(1.05, 0.19, 0.6), Vector3(0, 1.02, 0), navy)
	_mesh(body, "BuckledBelt", "box", Vector3(0.22, 0.19, 0.66), Vector3(0, 1.02, 0.01), Color("f7c95c"))
	_mesh(body, "Backpack", "box", Vector3(0.8, 0.84, 0.38), Vector3(0, 1.48, -0.43), Color("db8955"))
	_mesh(body, "PackFlap", "box", Vector3(0.84, 0.19, 0.44), Vector3(0, 1.82, -0.44), Color("f7c95c"))
	_mesh(body, "Neck", "cylinder", Vector3(0.26, 0.25, 0.26), Vector3(0, 2.08, 0), cream)
	_mesh(body, "Head", "sphere", Vector3(0.99, 1.05, 0.89), Vector3(0, 2.38, 0.03), cream)
	_mesh(body, "Hair", "sphere", Vector3(1.02, 0.36, 0.91), Vector3(0, 2.81, -0.02), Color("583a39"))
	_mesh(body, "FringeLeft", "sphere", Vector3(0.38, 0.27, 0.35), Vector3(-0.27, 2.71, 0.34), Color("583a39"))
	_mesh(body, "FringeRight", "sphere", Vector3(0.35, 0.25, 0.35), Vector3(0.28, 2.74, 0.33), Color("583a39"))
	for x in [-0.18, 0.18]:
		_mesh(body, "Eye", "sphere", Vector3(0.115, 0.16, 0.085), Vector3(x, 2.40, 0.445), navy)
		_mesh(body, "Cheek", "sphere", Vector3(0.18, 0.08, 0.06), Vector3(x * 1.6, 2.24, 0.403), Color("ec9e91"))
	_mesh(body, "Smile", "box", Vector3(0.22, 0.055, 0.065), Vector3(0, 2.22, 0.46), navy)
	_mesh(body, "GogglesBand", "box", Vector3(1.04, 0.12, 0.4), Vector3(0, 2.63, -0.18), Color("374a67"))
	left_leg = Node3D.new()
	right_leg = Node3D.new()
	left_arm = Node3D.new()
	right_arm = Node3D.new()
	for pair in [[left_leg, -0.29], [right_leg, 0.29]]:
		var pivot: Node3D = pair[0]
		var x: float = pair[1]
		pivot.position = Vector3(x, 0.97, 0)
		body.add_child(pivot)
		_mesh(pivot, "Trouser", "box", Vector3(0.37, 0.72, 0.4), Vector3(0, -0.38, 0), navy)
		_mesh(pivot, "Shoe", "box", Vector3(0.45, 0.28, 0.65), Vector3(0, -0.80, 0.16), boots)
		_mesh(pivot, "Sole", "box", Vector3(0.46, 0.07, 0.71), Vector3(0, -0.93, 0.19), Color("e6ecf0"))
	for pair in [[left_arm, -0.61], [right_arm, 0.61]]:
		var pivot: Node3D = pair[0]
		var x: float = pair[1]
		pivot.position = Vector3(x, 1.89, 0)
		body.add_child(pivot)
		_mesh(pivot, "Sleeve", "box", Vector3(0.36, 0.75, 0.42), Vector3(0, -0.40, 0), surface_color.darkened(0.16))
		_mesh(pivot, "Glove", "sphere", Vector3(0.39, 0.36, 0.43), Vector3(0, -0.86, 0.06), cream)
	scarf = Node3D.new()
	body.add_child(scarf)
	_mesh(scarf, "Scarf", "box", Vector3(1.06, 0.20, 0.56), Vector3(0, 2.00, 0), Color("f5b94e"))
	_mesh(scarf, "ScarfTail", "box", Vector3(0.19, 0.54, 0.12), Vector3(0.39, 1.70, -0.20), Color("f5b94e"))

func set_outfit(new_color: Color) -> void:
	surface_color = new_color
	_rebuild()

func animate(delta: float, moving: bool, slide: bool, jumping: bool, speed_factor: float) -> void:
	playing = moving
	sliding = slide
	airborne = jumping
	animation_clock += delta * (8.0 + speed_factor * 5.5 if moving else 2.3)
	var swing := sin(animation_clock)
	var amp := 0.77 if moving else 0.07
	if jumping:
		amp = 0.19
	left_leg.rotation.x = lerpf(left_leg.rotation.x, swing * amp, minf(delta * 13.0, 1.0))
	right_leg.rotation.x = lerpf(right_leg.rotation.x, -swing * amp, minf(delta * 13.0, 1.0))
	left_arm.rotation.x = lerpf(left_arm.rotation.x, -swing * amp * 0.75 - (0.45 if jumping else 0.0), minf(delta * 13.0, 1.0))
	right_arm.rotation.x = lerpf(right_arm.rotation.x, swing * amp * 0.75 - (0.45 if jumping else 0.0), minf(delta * 13.0, 1.0))
	var target_scale := 0.60 if slide else 1.0
	body.scale.y = lerpf(body.scale.y, target_scale, minf(delta * 15.0, 1.0))
	body.position.y = 0.10 * absf(sin(animation_clock)) if moving and not jumping and not slide else 0.0
	body.rotation.z = lerpf(body.rotation.z, 0.08 * swing if moving else sin(animation_clock * 0.3) * 0.02, minf(delta * 8.0, 1.0))
	scarf.rotation.x = sin(animation_clock * 0.75) * 0.10
