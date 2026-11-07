extends RefCounted
# Regression checks for the map data: Crimea, Vatican, country codes, Noord-Brabant, country anchors.

static func ring_contains(ring: Array, lon: float, lat: float) -> bool:
	var points := PackedVector2Array()
	for p in ring:
		points.append(Vector2(p[0],p[1]))
	return Geometry2D.is_point_in_polygon(Vector2(lon,lat),points)

static func rings_of(data: Dictionary, code: String) -> Array:
	for country in data.countries:
		if country.code==code:
			return country.polygons
	return []

static func in_any(rings: Array, lon: float, lat: float) -> bool:
	for ring in rings:
		if ring_contains(ring,lon,lat):
			return true
	return false

static func run(main: Node) -> void:
	# The raw file is checked on purpose: TopoWorld.reassign_crimea() would hide a wrong assignment in the data.
	var eu: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/map_eu.json"))
	assert(eu.has("meta") and int(eu.meta.format_version)==1 and eu.meta.pov in ["NLD","UKR"],"map_eu.json records format version and point of view")
	for crimea in [[33.52,44.6],[34.1,44.95],[34.17,44.5],[36.47,45.36]]:
		assert(in_any(rings_of(eu,"UKR"),crimea[0],crimea[1]),"Crimea %s is Ukraine in the data" % str(crimea))
		assert(not in_any(rings_of(eu,"RUS"),crimea[0],crimea[1]),"Crimea %s is not Russia in the data" % str(crimea))
	var joined=false
	for ring in rings_of(eu,"UKR"):
		joined=joined or (ring_contains(ring,34.1,44.95) and ring_contains(ring,30.52,50.45))
	assert(joined,"Crimea is joined to the Ukrainian mainland in one ring")
	var codes: Array=[]
	for country in eu.countries:
		codes.append(country.code)
		assert(not country.polygons.is_empty(),"Country %s has at least one ring" % country.code)
	for old_code in ["KOS","ALD","CYN"]:
		assert(not old_code in codes,"Non-ISO code %s is gone from map_eu.json" % old_code)
	assert("XKX" in codes and "VAT" in codes,"Kosovo is XKX and the Vatican has an entry")
	main.load_world("eu")
	var world: TopoWorld=main.world
	for code in ["ALD","CYN","KOS"]:
		assert(not world.country_polys.has(code),"No separate %s country in the game" % code)
	# The catalog follows the renamed code and every country anchor lies inside its own country.
	var vatican: Dictionary={}
	var kosovo_found=false
	for place in main.catalog.places:
		if place.kind!="land":
			continue
		assert(place.code!="KOS","Catalog uses XKX for Kosovo")
		kosovo_found=kosovo_found or place.code=="XKX"
		assert(world.country_contains(place.code,world.project(place.lon,place.lat)),"Anchor of %s lies inside its country" % place.name)
		if place.code=="VAT":
			vatican=place
	assert(kosovo_found,"Kosovo is in the catalog")
	for pair in [["Rusland","Moskou"],["Belarus","Minsk"],["Moldavië","Chisinau"],["Montenegro","Podgorica"],["Noord-Macedonië","Skopje"],["Malta","Valletta"],["Cyprus","Nicosia"]]:
		var country: Dictionary=main.catalog.region_lookup.eu[main.catalog.normalize(pair[0])]
		var capital: Dictionary=main.catalog.region_lookup.eu.get(main.catalog.normalize(pair[1]),{})
		assert(capital.is_empty() or country.lat!=capital.lat or country.lon!=capital.lon,"%s has its own anchor, not the capital's" % pair[0])
	# The Vatican used to be an empty entry with a 1.5 km circle fallback; the marker keeps about that reach.
	assert(world.has_country("VAT") and not vatican.is_empty(),"The Vatican has map geometry")
	var heli: Node3D=main.helicopter
	var before=heli.position
	heli.position=world.project(12.4535,41.9035)
	assert(main.at_goal(vatican),"Hovering over the Vatican counts")
	heli.position=world.project(12.4924,41.8902)
	assert(not main.at_goal(vatican),"The Colosseum is not the Vatican")
	heli.position=before
	# Noord-Brabant is one ring, not dozens of strips, and the points of its big cities resolve to it.
	main.load_world("nl")
	world=main.world
	assert(int(world.boundary_data.format_version)==1,"boundaries_nl.json declares its format version")
	for province in world.province_regions:
		assert(province.polygons.size()<=8,"%s is a few rings at most, found %d" % [province.name,province.polygons.size()])
		if province.name=="Noord-Brabant":
			assert(province.polygons.size()==1,"Noord-Brabant is one ring")
	for city in [[5.4697,51.4416],[4.7759,51.5719],[5.0913,51.5555],[5.3049,51.6998],[4.93,51.44]]:
		assert(world.province_at(world.project(city[0],city[1]))=="Noord-Brabant","%s lies in Noord-Brabant" % str(city))
	assert(world.province_at(world.project(5.1214,52.0907))=="Utrecht","Utrecht still resolves")
	assert(world.country_contains("NLD",world.project(4.9,52.37)),"Amsterdam is in the Netherlands")
	main.load_world("eu")
