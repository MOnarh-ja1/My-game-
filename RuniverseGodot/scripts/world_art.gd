extends RefCounted
## Reusable low-poly 3D art: each biome gets a distinct landscape, road and hazards.

static func mat(color: Color, emission: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.91
	if emission:
		m.emission_enabled = true
		m.emission = color * 0.8
	return m

static func make_mesh(parent: Node3D, kind: String, size: Vector3, pos: Vector3, color: Color, material: StandardMaterial3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var source: PrimitiveMesh
	match kind:
		"sphere":
			var m := SphereMesh.new()
			m.radius = 0.5
			m.height = 1.0
			m.radial_segments = 10
			m.rings = 5
			source = m
		"cone":
			var m := CylinderMesh.new()
			m.top_radius = 0.0
			m.bottom_radius = 0.5
			m.height = 1.0
			m.radial_segments = 7
			source = m
		"cylinder":
			var m := CylinderMesh.new()
			m.top_radius = 0.5
			m.bottom_radius = 0.5
			m.height = 1.0
			m.radial_segments = 9
			source = m
		_:
			source = BoxMesh.new()
	instance.mesh = source
	instance.material_override = material if material != null else mat(color)
	instance.position = pos
	instance.scale = size
	parent.add_child(instance)
	return instance

static func ground(parent: Node3D, biome: int, z: float, colors: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Landscape"
	root.position.z = z
	parent.add_child(root)
	make_mesh(root,"box",Vector3(74,0.6,26.2),Vector3(0,-0.55,0),colors["ground"])
	make_mesh(root,"box",Vector3(9.4,0.25,26.2),Vector3(0,-0.13,0),colors["road"])
	make_mesh(root,"box",Vector3(0.18,0.07,26.2),Vector3(-4.73,0.05,0),colors["edge"])
	make_mesh(root,"box",Vector3(0.18,0.07,26.2),Vector3(4.73,0.05,0),colors["edge"])
	for x in [-1.56,1.56]:
		for n in range(7):
			make_mesh(root,"box",Vector3(0.09,0.027,1.7),Vector3(x,0.01,-12+n*4.0),colors["line"])
	for side in [-1,1]:
		for idx in range(6):
			var xx: float = float(side)*(7.0+rng.randf_range(0.0,12.0))
			var zz: float = -11.5+float(idx)*4.0+rng.randf_range(-1.1,1.1)
			decorate(root,biome,xx,zz,rng)
		for idx in range(5):
			var xx: float = float(side)*(6.0+rng.randf_range(0.0,28.0))
			var zz: float = rng.randf_range(-12.0,12.0)
			make_mesh(root,"sphere",Vector3(0.5,0.25,0.45)*rng.randf_range(0.55,1.7),Vector3(xx,-0.09,zz),colors["stone"])
	return root

static func decorate(parent: Node3D, biome: int, x: float, z: float, rng: RandomNumberGenerator) -> void:
	var trunk := Color("946345")
	var s := rng.randf_range(0.75,1.45)
	match biome:
		0: # Sunlit forest: conifers, flowers, big leafy trees.
			make_mesh(parent,"cylinder",Vector3(0.45,3.0,0.45)*s,Vector3(x,1.1*s,z),trunk)
			var foliage := Color("3eae71") if rng.randf() < 0.55 else Color("70c27a")
			for i in range(3):
				make_mesh(parent,"cone",Vector3(3.0-i*0.4,3.2,3.0-i*0.4)*s,Vector3(x,(3.1+i*0.75)*s,z),foliage)
			make_mesh(parent,"sphere",Vector3(1.1,0.4,1.1)*s,Vector3(x+1.3*s,0.0,z),Color("e6c451"))
		1: # Desert: tall cacti, layered sandstones and dunes.
			if rng.randf() < 0.64:
				make_mesh(parent,"cylinder",Vector3(0.76,4.3,0.76)*s,Vector3(x,2.0*s,z),Color("449a72"))
				make_mesh(parent,"sphere",Vector3(0.76,0.76,0.76)*s,Vector3(x,4.15*s,z),Color("449a72"))
				for d in [-1,1]:
					make_mesh(parent,"box",Vector3(1.35,0.37,0.44)*s,Vector3(x+d*0.75*s,1.75*s,z),Color("449a72"))
					make_mesh(parent,"cylinder",Vector3(0.38,1.05,0.38)*s,Vector3(x+d*1.25*s,2.15*s,z),Color("449a72"))
			else:
				make_mesh(parent,"cone",Vector3(4.0,4.2,4.0)*s,Vector3(x,2.0*s,z),Color("d89a54"))
				make_mesh(parent,"box",Vector3(1.9,0.45,2.0)*s,Vector3(x,0.25*s,z),Color("f2bc71"))
		2: # Snow: fir trees with icy tips and piles of snow.
			make_mesh(parent,"cylinder",Vector3(0.5,2.6,0.5)*s,Vector3(x,1.2*s,z),Color("6e6a78"))
			for i in range(3):
				make_mesh(parent,"cone",Vector3(3.3-i*0.5,2.7,3.3-i*0.5)*s,Vector3(x,(2.7+i*0.8)*s,z),Color("419f9a"))
				make_mesh(parent,"cone",Vector3(2.8-i*0.5,0.5,2.8-i*0.5)*s,Vector3(x,(3.65+i*0.8)*s,z),Color("f1faff"))
			make_mesh(parent,"sphere",Vector3(1.7,0.65,1.7)*s,Vector3(x+1.25*s,0.0,z),Color("f8faff"))
		3: # Jungle: broad canopies, palms, flowers.
			make_mesh(parent,"cylinder",Vector3(0.6,5.4,0.6)*s,Vector3(x,2.55*s,z),Color("90704f"))
			for i in range(6):
				var a: float = float(i)*TAU/6.0
				var leaf := make_mesh(parent,"sphere",Vector3(2.8,0.38,0.94)*s,Vector3(x+cos(a)*1.2*s,5.1*s,z+sin(a)*1.2*s),Color("2fbb86"))
				leaf.rotation.y = -a
			make_mesh(parent,"sphere",Vector3(1.4,1.3,1.4)*s,Vector3(x+1.9*s,0.62*s,z),Color("24935e"))
			make_mesh(parent,"sphere",Vector3(0.55,0.55,0.55)*s,Vector3(x+1.9*s,1.36*s,z),Color("f26c91"))
		4: # Volcano: jagged obsidian, glowing lava.
			make_mesh(parent,"cone",Vector3(3.3,5.5,3.3)*s,Vector3(x,2.4*s,z),Color("353347"))
			make_mesh(parent,"cone",Vector3(1.6,2.0,1.6)*s,Vector3(x+0.65*s,2.6*s,z+0.4*s),Color("554352"))
			make_mesh(parent,"sphere",Vector3(1.6,0.2,1.1)*s,Vector3(x+2*s,0.0,z),Color("ff7337"),mat(Color("ff7337"),true))

static func obstacle(parent: Node3D, kind: String, biome: int, color: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Obstacle_" + kind
	parent.add_child(n)
	match kind:
		"crate":
			make_mesh(n,"box",Vector3(1.65,1.72,1.38),Vector3(0,0.88,0),color.darkened(0.22))
			make_mesh(n,"box",Vector3(1.74,0.19,1.48),Vector3(0,1.69,0),color)
			make_mesh(n,"box",Vector3(0.18,1.72,1.51),Vector3(0,0.87,0),Color("e8bf78"))
			make_mesh(n,"box",Vector3(1.81,0.15,0.22),Vector3(0,0.9,0.71),Color("e8bf78"))
		"hurdle":
			for xx in [-0.9,0.9]:
				make_mesh(n,"cylinder",Vector3(0.17,1.12,0.17),Vector3(xx,0.54,0),Color("404f58"))
			make_mesh(n,"box",Vector3(2.06,0.47,0.27),Vector3(0,0.65,0),color)
			make_mesh(n,"box",Vector3(2.09,0.09,0.31),Vector3(0,0.68,0.02),Color("fdf4c4"))
		"gate":
			for xx in [-1.02,1.02]:
				make_mesh(n,"box",Vector3(0.23,3.2,0.42),Vector3(xx,1.55,0),color.darkened(0.27))
			make_mesh(n,"box",Vector3(2.30,0.58,0.52),Vector3(0,2.55,0),color)
			make_mesh(n,"box",Vector3(1.50,0.10,0.56),Vector3(0,2.19,0),Color("ffdc7d"))
	if biome == 4:
		make_mesh(n,"sphere",Vector3(0.35,0.25,0.2),Vector3(0,0.16,0.76),Color("ffb74d"),mat(Color("ffb74d"),true))
	return n

static func coin(parent: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = "CollectibleCoin"
	parent.add_child(n)
	make_mesh(n,"cylinder",Vector3(0.92,0.14,0.92),Vector3.ZERO,Color("ffc847"),mat(Color("ffdb60"),true)).rotation.x = PI/2.0
	make_mesh(n,"cylinder",Vector3(0.58,0.17,0.58),Vector3(0,0,0.015),Color("f7a32f"),mat(Color("f7a32f"),true)).rotation.x = PI/2.0
	return n
