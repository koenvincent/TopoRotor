extends RefCounted

# Main.GameMode values.
const LEARN = 0
const PRACTICE = 1
const RECORDS = 2

# Regression checks for the gameplay, effects and scenery review fixes. Called
# from the end of Main.smoke_test(); game state is reached through `main`.

static func lin(c: float) -> float:
	return c/12.92 if c<=0.04045 else pow((c+0.055)/1.055,2.4)

static func lum(c: Color) -> float:
	return 0.2126*lin(c.r)+0.7152*lin(c.g)+0.0722*lin(c.b)

# WCAG contrast of text colour fg (with its alpha) laid over an opaque background.
static func contrast(fg: Color,bg: Color) -> float:
	var a=lum(bg.lerp(Color(fg.r,fg.g,fg.b),fg.a))
	var b=lum(bg)
	return (maxf(a,b)+.05)/(minf(a,b)+.05)

static func sight_color(fx: Node) -> Color:
	var v: Vector3=fx.sight_material.get_shader_parameter("sight_color")
	return Color(v.x,v.y,v.z)

static func run(main: Node) -> void:
	overlays(main)
	europe_scenery(main)
	rainbow_and_models(main)
	locked_text(main)
	ground_sight(main)
	calm(main)
	stars_per_mode(main)
	dutch_scenery(main)

# F-05 / F-22: one registry decides which overlay is on top and what Back closes.
static func overlays(main: Node) -> void:
	main.return_menu()
	assert(main.state=="menu" and main.top_overlay()=="","No overlay is open in the hangar")
	main.open_online_content()
	assert(main.content_dialog.visible and main.top_overlay()=="content","The Online dialog is an overlay")
	main.go_back(true)
	assert(not main.content_dialog.visible and main.state=="menu" and main.top_overlay()=="","Back closes the Online dialog instead of quitting")
	var credits=main.show_credits()
	assert(main.credits_dialog==credits and credits.visible and main.top_overlay()=="credits","The credits dialog is an overlay")
	main.open_leaderboard()
	main.open_photo_dialog()
	main.open_paint_shop()
	assert(not main.board_open and not main.photo_open and not main.paint_open,"No screen opens on top of the credits")
	main.go_back(true)
	assert(not credits.visible and main.top_overlay()=="" and main.state=="menu","Back closes the credits instead of quitting")
	main.open_photo_dialog()
	assert(main.photo_open and main.top_overlay()=="photo","The photo dialog is an overlay")
	main.open_leaderboard()
	main.open_pilots()
	main.open_themes()
	main.open_homework()
	main.open_paint_shop()
	main.open_online_content()
	assert(not main.board_open and not main.pilots_open and not main.themes_open and not main.homework_open and not main.paint_open and not main.content_dialog.visible,"Nothing opens on top of the photo dialog")
	main.go_back(true)
	assert(not main.photo_open and main.top_overlay()=="","Back closes the photo dialog")
	main.open_leaderboard()
	assert(main.board_open,"The leaderboard opens when nothing else is open")
	main.open_online_content()
	assert(not main.content_dialog.visible and main.top_overlay()=="board","The Online dialog does not open over the leaderboard")
	main.go_back(true)
	assert(not main.board_open and main.state=="menu","Back closes the leaderboard")

# F-133 / F-134 / F-80: unknown landmark types are not counted, bad data degrades.
static func europe_scenery(main: Node) -> void:
	var scenery=main.world.europe_scenery
	assert(scenery!=null,"The Europe scenery is built")
	var count=0
	for city in scenery.landmark_data:
		var entries: Array=scenery.landmark_data[city]
		assert(scenery.landmark_built.get(city,-1)==entries.size() and scenery.landmark_names.get(city,[]).size()==entries.size(),"Every Europe landmark in the data is built and named: "+city)
		count+=entries.size()
	assert(count>=20,"Europe landmarks are bundled")
	# A scenery that was not baked still owns its kit; the baked one has dropped it.
	var probe=EuropeScenery.new(main.world)
	assert(probe.build_landmark(Vector3.ZERO,{"type":"towerbridge"})==false and probe.k_scale==1.0,"An unknown Europe landmark type builds nothing and leaves the kit scale alone")
	assert(probe.kit.build(Vector3.ZERO,{"type":"builtin"})==false,"The kit builds nothing for a type it cannot draw")
	assert(probe.build_landmark(Vector3.ZERO,{"type":"windmill"})==true and probe.k_scale==1.0,"A kit landmark builds at Europe scale and the scale is restored")
	probe.landmark_data={"Testplaats":[{"name":"Typfout","type":"towerbridge","at":[3.0,3.0]},{"name":"Molen","type":"windmill","at":[-3.0,-3.0]}]}
	probe.town(main.world.project(5.0,50.0),"Testplaats")
	assert(probe.landmark_built["Testplaats"]==1 and probe.landmark_names["Testplaats"]==["Molen"],"A landmark of unknown type is neither counted nor named")
	probe.kit=null
	assert(DutchScenery.landmark_cities(null,"test.json").is_empty(),"Missing or malformed landmark data gives an empty table")
	assert(DutchScenery.landmark_cities([],"test.json").is_empty() and DutchScenery.landmark_cities({"cities":[]},"test.json").is_empty(),"Landmark data of the wrong shape gives an empty table")
	assert(DutchScenery.landmark_cities({"cities":{"Parijs":[]}},"test.json").has("Parijs"),"Valid landmark data is used")

# F-120 / F-121 rainbow bands, F-60 airframe loads, F-17 model registry.
static func rainbow_and_models(main: Node) -> void:
	var heli: RotorHelicopter=main.helicopter
	var before=heli.body.get_child_count()
	heli.smoke_trail(Vector3.ZERO,true)
	var puff: CPUParticles3D=heli.body.get_child(before)
	var ramp: Gradient=puff.color_initial_ramp
	var bands=["e8453a","ff9a3c","f4c51c","3fbf6a","3b7dd8","8a4fd8"]
	assert(ramp.get_point_count()==6 and ramp.interpolation_mode==Gradient.GRADIENT_INTERPOLATE_CONSTANT,"The rainbow has six constant bands")
	for i in 6:
		assert(is_equal_approx(ramp.get_offset(i),i/6.0) and ramp.get_color(i)==Color(bands[i]),"Rainbow band %d has its own colour and offset" % i)
		assert(ramp.sample(i/6.0+.05)==Color(bands[i]),"Rainbow band %d is sampled in its own range" % i)
	assert(ramp.sample(.99)==Color(bands[5]),"Purple closes the rainbow")
	puff.free()
	assert(RotorHelicopter.load_scene("res://assets/shaders/target_zone.gdshader")==null,"A resource that is not a scene is rejected, not dereferenced")
	var with_frame=0
	for model in HangarCatalog.MODELS:
		assert(heli.model_builders().has(model.id),"Every catalog aircraft has a builder: "+model.id)
		if RotorHelicopter.has_airframe(model.id):
			with_frame+=1
			assert(RotorHelicopter.load_scene(RotorHelicopter.MODEL_DIR+model.id+".glb")!=null,"The bundled airframe loads: "+model.id)
	assert(with_frame>0,"At least one Blender airframe is bundled")
	assert(RotorHelicopter.DEFAULT_PAINT==HangarCatalog.DEFAULT_PAINT,"The factory paint lives in the catalog")

# F-44: text on locked and disabled controls stays readable.
static func locked_text(main: Node) -> void:
	var worst_face=Color(.1,.2,.24)
	var b=Button.new()
	main.tone_button(b,"locked")
	assert(contrast(b.get_theme_color("font_color"),worst_face)>=4.5,"Locked item text reaches 4.5:1")
	assert(contrast(b.get_theme_color("font_disabled_color"),worst_face)>=4.5,"Disabled button text reaches 4.5:1")
	assert(contrast(main.DIM_INK,worst_face)>=4.5,"Dimmed ink reaches 4.5:1")
	b.free()
	var theme: Theme=main.build_theme()
	assert(contrast(theme.get_color("font_disabled_color","Button"),worst_face)>=4.5,"The theme's disabled text reaches 4.5:1")

# F-16: the ground sight gives nothing away while the radar rings or a hidden target apply.
static func ground_sight(main: Node) -> void:
	var fx=main.fx
	var neutral=Color("fffbe8")
	fx.inside_amount=1.0
	main.world.target.show()
	fx.update_sight(Vector3(0,5,0),true)
	assert(fx.sight_tint()==1.0 and sight_color(fx).g>.99 and sight_color(fx).r<.4,"The sight turns green over a shown goal")
	fx.show_radar([{"at":Vector3.ZERO,"radius":3.0}])
	fx.update_sight(Vector3(0,5,0),true)
	assert(fx.sight_tint()==0.0 and sight_color(fx).is_equal_approx(fx.RADAR_COLOR),"Neutral radar rings keep the sight neutral, goal or not")
	fx.show_radar([])
	main.world.target.hide()
	fx.update_sight(Vector3(0,5,0),true)
	assert(fx.sight_tint()==0.0 and sight_color(fx).is_equal_approx(neutral),"A hidden target never tints the sight")
	fx.inside_amount=0.0
	fx.update_sight(Vector3.ZERO,false)

static func flash_alpha(main: Node) -> float:
	var c: Color=main.hud_fx.vignette_material.get_shader_parameter("flash_color")
	return c.a

# F-15 / F-72 / F-105 / F-84: the 'Rustige beelden' setting.
static func calm(main: Node) -> void:
	var hud_fx=main.hud_fx
	var fx=main.fx
	main.return_menu()
	main.saved.erase("calm")
	main.apply_calm()
	assert(not main.calm_on() and not hud_fx.calm and not fx.calm and main.calm_button.text=="Rustige beelden: uit","Calm mode starts off")
	assert(ProgressStore.clean({"calm":true}).calm==true and not ProgressStore.clean({"calm":"ja"}).has("calm"),"The calm setting is validated")
	for shader in [fx.zone_material,fx.sight_material,fx.beacon_material]:
		var names=shader.shader.get_shader_uniform_list().map(func(u): return u.name)
		assert("motion" in names,"Overlay shaders expose a motion switch")
		assert(shader.get_shader_parameter("motion")==1.0,"Shaders animate by default")
	# Normal behaviour first: a miss flashes, a hit bursts, confetti falls.
	hud_fx.show_miss()
	assert(flash_alpha(main)>.5 and not is_equal_approx(hud_fx.cross.scale.x,1.0),"A miss flashes and pops by default")
	hud_fx.show_hit("GOED ZO!","Test",0)
	assert(hud_fx.burst.visible,"A hit shows the sunburst by default")
	hud_fx.celebrate()
	assert(hud_fx.confetti.emitting,"Confetti falls by default")
	hud_fx.clear()
	main.toggle_calm()
	hud_fx.flash(hud_fx.RED)
	assert(flash_alpha(main)==0.0,"A direct flash request is ignored when calm")
	assert(main.saved.calm==true and main.calm_on() and hud_fx.calm and fx.calm and main.calm_button.text=="Rustige beelden: aan","The toggle switches calm mode on")
	for shader in [fx.zone_material,fx.sight_material,fx.beacon_material]:
		assert(shader.get_shader_parameter("motion")==0.0,"Calm mode freezes the overlay shaders")
	fx.show_radar([{"at":Vector3.ZERO,"radius":3.0}])
	assert(fx.radar_rings[0].material_override.get_shader_parameter("motion")==0.0,"Radar rings that already exist hold still")
	fx.show_radar([])
	assert(JSON.parse_string(JSON.stringify(main.saved)).calm==true,"The setting is saved with the other settings")
	# Calm feedback: still visible, no flash, pop, burst or confetti.
	hud_fx.show_miss()
	assert(hud_fx.cross.visible and hud_fx.cross_label.visible and flash_alpha(main)==0.0,"A calm miss shows the cross without a flash")
	assert(hud_fx.cross.scale==Vector2.ONE and is_zero_approx(hud_fx.cross.rotation) and is_zero_approx(hud_fx.cross.position.x),"A calm miss does not pop, spin or shake")
	hud_fx.show_hit("GOED ZO!","Test",3)
	assert(hud_fx.banner.visible and not hud_fx.burst.visible and flash_alpha(main)==0.0 and hud_fx.banner.scale==Vector2.ONE,"A calm hit shows the banner without sunburst, flash or bounce")
	hud_fx.confetti.emitting=false
	hud_fx.celebrate()
	assert(not hud_fx.confetti.emitting and flash_alpha(main)==0.0,"No confetti and no flash when calm")
	hud_fx.clear()
	var bursts=fx.bursts_started
	fx.celebrate(Vector3.ZERO)
	assert(fx.bursts_started==bursts,"No rockets when calm")
	var panel=Control.new()
	main.add_child(panel)
	main.reveal(panel)
	assert(panel.modulate.a==1.0 and panel.scale==Vector2.ONE,"Panels appear at once when calm")
	panel.free()
	# In flight: no screen shake, and the answer button holds steady instead of pulsing.
	main.mode_select.select(LEARN)
	main.start_mission([main.catalog.lookup.amsterdam])
	main.helicopter.position=main.world.project(-20,35)
	main.answer()
	assert(main.goal_mistakes==1 and main.shake==0.0 and hud_fx.cross.visible,"A calm wrong answer shows the cross but does not shake the view")
	main.helicopter.position=main.world.project(main.catalog.lookup.amsterdam.lon,main.catalog.lookup.amsterdam.lat)
	main.flight_time=0.0
	main.update_effects(1.0/60.0)
	var first: Vector2=main.found_button.scale
	main.flight_time=.1
	main.update_effects(1.0/60.0)
	assert(main.in_zone and first==main.found_button.scale and first.x>1.0,"Inside the zone the answer button is steady and enlarged, not pulsing")
	fx.update_sight(main.helicopter.position,true)
	main.return_menu()
	# Back to normal: shake and pulse return.
	main.toggle_calm()
	assert(not main.calm_on() and not hud_fx.calm and not fx.calm and main.saved.calm==false,"The toggle switches calm mode off again")
	for shader in [fx.zone_material,fx.sight_material,fx.beacon_material]:
		assert(shader.get_shader_parameter("motion")==1.0,"Shaders animate again")
	main.start_mission([main.catalog.lookup.amsterdam])
	main.helicopter.position=main.world.project(-20,35)
	main.answer()
	assert(main.shake>0.0,"Wrong answers shake the view again")
	main.helicopter.position=main.world.project(main.catalog.lookup.amsterdam.lon,main.catalog.lookup.amsterdam.lat)
	main.flight_time=0.0
	main.update_effects(1.0/60.0)
	var pulsing: Vector2=main.found_button.scale
	main.flight_time=.1
	main.update_effects(1.0/60.0)
	assert(pulsing!=main.found_button.scale,"The answer button pulses again")
	main.return_menu()
	main.saved.erase("calm")

# F-20: only Oefenen and Records write the stars shown under their own names.
static func stars_per_mode(main: Node) -> void:
	var backup=main.saved.duplicate(true)
	main.load_world("nl")
	main.region_select.select(0)
	var utrecht=main.catalog.lookup.utrecht
	var at_utrecht=main.world.project(utrecht.lon,utrecht.lat)
	var results={}
	for mode in [LEARN,PRACTICE,RECORDS]:
		main.saved.best={}
		main.mode_select.select(mode)
		main.start_mission([utrecht],false)
		main.helicopter.position=at_utrecht
		main.answer()
		assert(main.state=="summary" and not main.custom_mission,"The mission finishes as a standard route")
		results[mode]=main.saved.best.duplicate()
		main.return_menu()
	assert(results[LEARN].is_empty(),"A Leren mission writes no stars")
	assert(results[PRACTICE].has("nl_oefenen") and not results[PRACTICE].has("nl_test"),"Oefenen writes the Oefenen stars")
	assert(results[RECORDS].has("nl_test") and not results[RECORDS].has("nl_oefenen"),"Records writes the Records stars")
	main.saved=backup

static func dutch_scenery(main: Node) -> void:
	var scenery=main.world.dutch_scenery
	var probe=DutchScenery.new(main.world)
	assert(probe.kit.build(Vector3.ZERO,{"type":"nope"})==false and probe.kit.build(Vector3.ZERO,{"type":"windmill"})==true,"The Dutch kit reports whether it built a landmark")
	probe.kit=null
	for city in scenery.landmark_data:
		var wanted=0
		for entry in scenery.landmark_data[city]:
			if entry.get("type")!="builtin":
				wanted+=1
		assert(scenery.landmark_built.get(city,-1)==wanted,"Only landmarks that were drawn are counted: "+city)
