class_name ToyLook
extends RefCounted

# The shared look of the aircraft and the pilots, like painted die-cast
# scale models: rounded blocks instead of sharp boxes, smooth spheres and a
# lacquered paint that catches the sky. Built procedurally, so every model
# keeps its paint slots and the hangar can recolour it at any moment.

static var _boxes: Dictionary = {}
static var _sphere: SphereMesh
static var _sky: Sky

# A smooth sphere for every round part: enough segments for a clean
# silhouette, still cheap enough for a hundred parts.
static func sphere() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radial_segments = 32
		_sphere.rings = 16
	return _sphere

# Lacquer: gloss 0 is cloth or skin, .75 painted metal, 1 tinted glass.
# Glossy paint is a little metallic so it mirrors the sky like a model car.
static func material(color: Color, gloss: float = .55) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = lerpf(.82, .16, gloss)
	m.metallic = lerpf(0.0, .32, gloss * gloss)
	m.metallic_specular = lerpf(.3, .75, gloss)
	if gloss >= 1.0:
		m.roughness = .06
		m.metallic = .45
		m.metallic_specular = 1.0
	return m

static func recolor(m: Material, color: Color) -> void:
	if m is StandardMaterial3D:
		(m as StandardMaterial3D).albedo_color = color

static func color_of(m: Material) -> Color:
	if m is StandardMaterial3D:
		return (m as StandardMaterial3D).albedo_color
	return Color.WHITE

# A soft studio sky: pale above, a warm horizon and a dark floor. Glossy
# paint and glass reflect it, so curved parts get highlights and depth.
static func studio_sky() -> Sky:
	if _sky == null:
		var sky_material = ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("9fc4dd")
		sky_material.sky_horizon_color = Color("f1e2c9")
		sky_material.sky_curve = .12
		sky_material.ground_bottom_color = Color("101c22")
		sky_material.ground_horizon_color = Color("5d6d70")
		sky_material.ground_curve = .08
		sky_material.sun_angle_max = 12.0
		_sky = Sky.new()
		_sky.sky_material = sky_material
		_sky.radiance_size = Sky.RADIANCE_SIZE_64
	return _sky

# A box with rounded edges and corners at its real size (a box grown by a
# sphere), cached per size. Flat faces stay flat because each corner gets its
# own copy of the boundary rows; the rounding is a share of the thinnest side.
static func rounded_box(size: Vector3, roundness: float = .42, max_radius: float = .45) -> ArrayMesh:
	size = size.abs().max(Vector3.ONE * .002)
	var radius: float = minf(minf(size.x, minf(size.y, size.z)) * .5 * roundness * 2.0, max_radius)
	radius = minf(radius, minf(size.x, minf(size.y, size.z)) * .5)
	var key = "%.3f|%.3f|%.3f|%.3f" % [size.x, size.y, size.z, radius]
	if _boxes.has(key):
		return _boxes[key]
	var half: Vector3 = size * .5 - Vector3.ONE * radius
	var quarter = 3 # segments per quarter turn
	var rings = 3 # segments from the pole to the equator
	var columns = 4 * (quarter + 1)
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	# Rows: top hemisphere pole..equator, then bottom equator..pole.
	for hemi in 2:
		for r in rings + 1:
			var theta: float = (PI * .5) * float(r) / rings + (PI * .5 if hemi == 1 else 0.0)
			var sy: float = 1.0 if hemi == 0 else -1.0
			for q in 4:
				var mid: float = (q + .5) * PI * .5
				var sx: float = signf(cos(mid))
				var sz: float = signf(sin(mid))
				for c in quarter + 1:
					var phi: float = (q + float(c) / quarter) * PI * .5
					var n = Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
					verts.append(n * radius + Vector3(sx * half.x, sy * half.y, sz * half.z))
					normals.append(n)
	var indices = PackedInt32Array()
	var rows = 2 * (rings + 1)
	for row in rows - 1:
		for col in columns:
			var a = row * columns + col
			var b = row * columns + (col + 1) % columns
			var c = (row + 1) * columns + col
			var d = (row + 1) * columns + (col + 1) % columns
			_triangle(indices, verts, normals, a, b, c)
			_triangle(indices, verts, normals, b, d, c)
	# The flat top and bottom caps between the four pole corners.
	for row in [0, rows - 1]:
		var corners: Array = []
		for q in 4:
			corners.append(row * columns + q * (quarter + 1))
		_triangle(indices, verts, normals, corners[0], corners[1], corners[2])
		_triangle(indices, verts, normals, corners[0], corners[2], corners[3])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_boxes[key] = mesh
	return mesh

# Adds a triangle with Godot's clockwise front face, judged against the
# vertex normals, and drops the slivers that collapse at the poles.
static func _triangle(indices: PackedInt32Array, verts: PackedVector3Array, normals: PackedVector3Array, a: int, b: int, c: int) -> void:
	var face: Vector3 = (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if face.length_squared() < 1e-12:
		return
	if face.dot(normals[a] + normals[b] + normals[c]) > 0.0:
		indices.append_array([a, c, b])
	else:
		indices.append_array([a, b, c])
