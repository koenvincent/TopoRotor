extends RefCounted

# Regression checks for the catalogue, world labels, locator card and minimap
# (review workstream ws5a). Called once at the end of Main.smoke_test().
static func run(main: Node) -> void:
	var catalog: TopoCatalog=main.catalog
	region_names(main,catalog)
	route_names(catalog)
	name_fold(catalog)
	if main.region!="nl":
		main.load_world("nl")
	custom_labels(main)
	locator_card(main)
	projection(main)
	minimap_tooltip(main)

# A Europe list or pack resolves the names both maps have to the Europe entries.
static func region_names(main: Node,catalog: TopoCatalog) -> void:
	var nl_sea: Dictionary=catalog.lookup.noordzee
	var eu_sea: Dictionary=catalog.resolve("Noordzee","eu")
	assert(nl_sea.region=="nl" and eu_sea.region=="eu" and main.hit_radius_km(eu_sea)>main.hit_radius_km(nl_sea),"Setup: the Noordzee exists once per region")
	var eu_list=catalog.parse_list("Noordzee, Rijn, Donau","eu")
	assert(eu_list.found.size()==3 and eu_list.unknown.is_empty() and eu_list.found.all(func(p): return p.region=="eu"),"A Europe list resolves Noordzee and Rijn to the Europe entries")
	assert(catalog.parse_list("Noordzee\nRijn").found.all(func(p): return p.region=="nl"),"A Dutch list keeps the Dutch Noordzee and Rijn")
	var mixed=catalog.parse_list("Noordzee, Parijs, Rijn")
	assert(mixed.found.size()==3 and mixed.found.all(func(p): return p.region=="eu"),"A list that names a Europe place counts as a Europe list")
	assert(catalog.parse_list("Noordzee, Arnhem","nl").found[0].region=="nl","An explicit Dutch region keeps Dutch names")
	assert(catalog.parse_list("Arnhem, Noordzee","eu").found[0].region=="nl","Dutch-only names still resolve on a Europe list")
	assert(catalog.resolve("Noordzee","nl").region=="nl" and catalog.resolve("Biesboss","eu").is_empty(),"resolve() gives an empty result for an unknown name")
	# The typed / photo list follows the active region.
	var saved_region: String=main.region
	var saved_text: String=main.mission_text.text
	main.region="eu"
	main.mission_text.text="Noordzee\nRijn"
	var typed=main.parse_custom()
	main.region=saved_region
	main.mission_text.text=saved_text
	assert(typed.found.size()==2 and typed.found.all(func(p): return p.region=="eu"),"A typed list on the Europe map gets the Europe sea and river")
	# Online packs: by region field, or by what the names say.
	var pack='{"version":1,"missions":[{"title":"Zeeën","places":["Noordzee","Oostzee"]},{"title":"Eu","region":"eu","places":["Noordzee","Rijn"]},{"title":"Nl","places":["Noordzee","Rijn"]},{"title":"Nl2","region":"nl","places":["Noordzee"]}]}'
	assert(main.apply_online_content(pack),"Online pack with a region field validates")
	var packs: Array=main.online_packs
	assert(packs[0].places[0].region=="eu" and packs[1].places.all(func(p): return p.region=="eu") and packs[2].places.all(func(p): return p.region=="nl") and packs[3].places[0].region=="nl","Online packs resolve shared names per region")
	assert(not main.apply_online_content('{"version":1,"missions":[{"title":"Fout","region":"mars","places":["Noordzee"]}]}') and not main.apply_online_content('{"version":1,"missions":[{"title":"Fout","region":5,"places":["Noordzee"]}]}'),"Online pack with an unknown region is rejected")
	assert(main.apply_online_content(FileAccess.get_file_as_string("res://content/missions.json")),"Online lesson example still validates")

# An unknown route name is reported with route and name, not crashed on.
static func route_names(catalog: TopoCatalog) -> void:
	assert(catalog.load_errors.is_empty(),"Bundled data resolves: %s" % str(catalog.load_errors))
	var errors: Array=[]
	var routes=catalog.build_routes({"routes":[{"title":"Proef","places":["Noordzee","Biesboss","Rijn"]}]},"eu",errors)
	assert(routes.size()==1 and routes[0].places.size()==2 and routes[0].places.all(func(p): return p.region=="eu"),"An unknown route name is skipped, the others stay")
	assert(errors.size()==1 and errors[0].contains("Proef") and errors[0].contains("Biesboss"),"The error names the route and the place")
	errors.clear()
	assert(catalog.build_routes(null,"nl",errors).is_empty() and catalog.build_routes({"routes":"x"},"nl",errors).is_empty() and errors.size()==2,"Malformed routes data is reported")

# GDScript fold against the vectors the Python normaliser is checked with.
static func name_fold(catalog: TopoCatalog) -> void:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/name_vectors.json"))
	assert(data is Dictionary and data.get("cases") is Array and data.cases.size()>40,"Name vectors are bundled")
	var failures: Array=[]
	for pair in data.cases:
		if TopoCatalog.normalize(pair[0])!=pair[1]:
			failures.append("%s -> %s (expected %s)" % [pair[0],TopoCatalog.normalize(pair[0]),pair[1]])
	assert(failures.is_empty(),"GDScript name fold differs from the Python one: "+"\n".join(failures))
	var plain := RegEx.new()
	plain.compile("^[ -~]+$")
	for key in catalog.lookup:
		assert(plain.search(key)!=null,"Catalogue key folds to plain ASCII: "+key)

static func custom_labels(main: Node) -> void:
	var world: TopoWorld=main.world
	var city_label: Label3D=world.marker_labels.get("Utrecht")
	assert(city_label!=null and city_label.get_meta("kind")=="stad","Setup: the Utrecht city has a label")
	var city_at: Vector3=city_label.position
	var count=world.labels.size()
	var point={"name":"Utrecht","lat":52.15,"lon":5.39,"region":"nl","kind":"eigen punt","code":""}
	world.ensure_mission_markers([point])
	assert(city_label.position==city_at and city_label.get_meta("kind")=="stad","A custom point named like a city leaves the city label alone")
	assert(world.labels.size()==count+1 and world.marker_labels.has("eigen:Utrecht"),"The custom point gets its own label")
	var own: Label3D=world.marker_labels["eigen:Utrecht"]
	assert(own.position.is_equal_approx(world.project(5.39,52.15)+Vector3(0,3.8,0)),"The custom label sits on the custom coordinates")
	point.lon=5.5
	world.ensure_mission_markers([point])
	assert(world.labels.size()==count+1 and own.position.is_equal_approx(world.project(5.5,52.15)+Vector3(0,3.8,0)) and city_label.position==city_at,"The same custom point is moved, never duplicated")
	world.ensure_mission_markers([{"name":"Utrecht","lat":52.0,"lon":5.0,"region":"nl","kind":"eigen punt","code":""}])
	assert(world.labels.size()==count+1,"A custom point named like a city is still one label per name")
	world.ensure_mission_markers([{"name":"Schooltje","lat":52.4,"lon":5.0,"region":"nl","kind":"eigen punt","code":""}])
	world.set_hints(true)
	world.refresh_labels(Vector3(1000,0,1000),true)
	assert(world.marker_labels["eigen:Schooltje"].visible and own.visible,"Custom points keep their name in the overview")
	world.set_hints(false)
	var overview_ok=true
	for name in TopoWorld.OVERVIEW_CITIES:
		overview_ok=overview_ok and main.catalog.lookup.has(TopoCatalog.normalize(name)) and main.catalog.lookup[TopoCatalog.normalize(name)].kind=="stad"
	assert(overview_ok,"Every overview city exists in the catalogue")
	# Names without the disambiguation suffix on the map.
	assert(world.marker_labels["Utrecht provincie"].text=="Utrecht" and world.marker_labels["Groningen provincie"].text=="Groningen","Province labels show the plain name")

static func locator_card(main: Node) -> void:
	var catalog: TopoCatalog=main.catalog
	var card: LocatorCard=main.locator
	var province: Dictionary=catalog.lookup["utrecht provincie"]
	assert(LocatorCard.title_for(province)=="Provincie Utrecht" and LocatorCard.title_for(catalog.lookup.utrecht)=="Utrecht","Card title has no suffix")
	card.present(province,[])
	assert(card.title_label.text=="Provincie Utrecht","The card shows the province title")
	var expected={"IJsselmeer":"Het","Markermeer":"Het","Haringvliet":"Het","Hollands Diep":"Het","Noordzeekanaal":"Het","Amsterdam-Rijnkanaal":"Het","Twentekanaal":"Het","Veerse Meer":"Het","Rijn":"De","Waddenzee":"De","Nieuwe Waterweg":"De","Dollard":"De","Merwede":"De"}
	for name in expected:
		var water=catalog.resolve(name,"nl")
		assert(LocatorCard.water_name(water)==expected[name]+" "+name,"Article for "+name)
	assert(card.describe(catalog.lookup.haringvliet).begins_with("Het Haringvliet ligt"),"The sentence uses the right article")
	var key=InputEventKey.new()
	key.pressed=true
	key.keycode=KEY_ENTER
	card._unhandled_key_input(key)
	assert(not card.visible,"Enter closes the card")
	card.present(province,[])
	var space=InputEventKey.new()
	space.pressed=true
	space.keycode=KEY_SPACE
	card._unhandled_key_input(space)
	assert(card.visible,"Space is left for answering the next goal")
	var escape=InputEventKey.new()
	escape.pressed=true
	escape.keycode=KEY_ESCAPE
	escape.physical_keycode=KEY_ESCAPE
	card._unhandled_key_input(escape)
	assert(not card.visible,"Escape closes the card")
	card._unhandled_key_input(key)
	card.dismiss()

static func projection(main: Node) -> void:
	for region in ["nl","eu"]:
		var shared=TopoWorld.projection(region)
		var world=main.world
		if world.region==region:
			assert(world.origin==shared.origin and is_equal_approx(world.geo_scale,shared.scale),"The world uses the shared projection")
	assert(TopoWorld.projection("nl").scale==85.0 and TopoWorld.projection("eu").scale==14.0,"Shared projection keeps the shipped scale")
	var plans: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/city_plans_nl.json"))
	if plans.has("projection"):
		var built=plans.projection
		var shared=TopoWorld.projection("nl")
		assert(Vector2(built.origin[0],built.origin[1])==shared.origin and is_equal_approx(float(built.scale),shared.scale),"City plans were built for the game's projection")

static func minimap_tooltip(main: Node) -> void:
	main.load_world("eu")
	assert(not main.minimap.tooltip_text.contains("Tik") and not main.minimap.tooltip_text.contains("Kadaster"),"The Europe minimap promises no tap toggle")
	main.load_world("nl")
	assert(main.minimap.tooltip_text.contains("Tik om te wisselen") and main.minimap.tooltip_text.contains("Kadaster"),"The Dutch minimap keeps its tap hint and attribution")
