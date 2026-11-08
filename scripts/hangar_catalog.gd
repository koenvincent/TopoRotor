class_name HangarCatalog
extends RefCounted

# Everything the hangar can offer: helicopters, aeroplanes and jets, paint
# schemes, accessories, upgrades and pilot looks, plus the rules for earning
# them. Items unlock at a total of flight points (never spent, so nothing can
# be lost again) or with a medal for a special achievement.

# Every type flies the same way in the game, so records stay comparable; the
# kind only changes the model, the banking and the engine sound.
const KINDS = [["heli","HELIKOPTERS"],["vliegtuig","VLIEGTUIGEN"],["jet","STRAALJAGERS"]]
const MODELS = [
	{"id":"redder","kind":"heli","name":"Redder","about":"Reddingsheli met twee turbines.","points":0},
	{"id":"libel","kind":"heli","name":"Libel","about":"Lichte lesheli met een glazen bol.","points":150},
	{"id":"molen","kind":"heli","name":"Molentje","about":"Gyrokopter met een duwpropeller.","points":300},
	{"id":"pijl","kind":"heli","name":"Pijlstaart","about":"Snelle heli met een staartrotor in een ring.","points":450},
	{"id":"tandem","kind":"heli","name":"Tandem","about":"Vrachtheli met twee grote rotoren.","points":900,"preview":.72},
	{"id":"wesp","kind":"heli","name":"Wesp","about":"Smalle gevechtsheli met twee cockpits.","points":1250},
	{"id":"kraan","kind":"heli","name":"Vliegende kraan","about":"Kraanheli op hoge poten.","points":1500},
	{"id":"coax","kind":"heli","name":"Tegendraaier","about":"Twee rotoren boven elkaar, geen staartrotor.","points":2000},
	{"id":"sport","kind":"vliegtuig","name":"Sportvlieger","about":"Eenmotorig lesvliegtuig met hoge vleugel.","points":600,"preview":.8},
	{"id":"dubbel","kind":"vliegtuig","name":"Dubbeldekker","about":"Oud stuntvliegtuig met twee vleugels.","points":1050,"preview":.8},
	{"id":"zee","kind":"vliegtuig","name":"Watervliegtuig","about":"Landt op het water met twee drijvers.","points":1400,"preview":.78},
	{"id":"dakota","kind":"vliegtuig","name":"Dakota","about":"Tweemotorig transportvliegtuig.","points":1800,"preview":.66},
	{"id":"valk","kind":"jet","name":"Valk","about":"Wendbare straaljager met één motor.","points":2300,"preview":.8},
	{"id":"delta","kind":"jet","name":"Deltajager","about":"Driehoekige vleugel en kleine neusvinnen.","points":3000,"preview":.8},
	{"id":"schaduw","kind":"jet","name":"Schaduw","about":"Platte stealthjager met schuine staartvinnen.","points":4000,"preview":.78},
]

# "kind" limits an accessory to some aircraft kinds; without it, it fits all.
const ACCESSORIES = [
	{"id":"vlag","name":"Nederlandse vlag","points":40},
	{"id":"zoeklicht","name":"Zoeklicht","points":60},
	{"id":"ogen","name":"Stripogen","points":80},
	{"id":"antennes","name":"Antennes","points":100},
	{"id":"zwaailichten","name":"Zwaailichten","points":140},
	{"id":"wielen","name":"Wielen","points":180},
	{"id":"wimpel","name":"Wimpel","medal":"eerste_record"},
	{"id":"megafoon","name":"Megafoon","points":220},
	{"id":"camera","name":"Camerabol","points":250},
	{"id":"haaienbek","name":"Haaienbek","points":300},
	{"id":"lier","name":"Reddingslier","points":350},
	{"id":"radar","name":"Radarschotel","points":400},
	{"id":"ballonnen","name":"Ballonnen","points":450},
	{"id":"tanks","name":"Extra tanks","points":520},
	{"id":"drijvers","name":"Drijvers","points":600},
	{"id":"lichtslinger","name":"Lichtslinger","points":650},
	{"id":"koffer","name":"Bagagekoffer","points":700},
	{"id":"vleugels","name":"Stompvleugels","points":750},
	{"id":"skis","name":"Ski's","points":800},
	{"id":"rookspoor","name":"Rookspoor","points":900},
	{"id":"meetneus","name":"Meetneus","points":1000},
	{"id":"krat","name":"Vrachtkrat","points":1100},
	{"id":"bluskorf","name":"Bluskorf","points":1200},
	{"id":"zonnepaneel","name":"Zonnepaneel","points":1300},
	{"id":"banner","name":"Sleepbanner","points":1600},
	{"id":"vuurwerk","name":"Vuurwerkpods","points":2000},
	{"id":"regenboog","name":"Regenboogrook","medal":"foutloos"},
	{"id":"kroon","name":"Gouden kroon","medal":"huiswerk"},
]

# Level 0 is always available. Motor only changes Leren and Oefenen, so
# record times stay comparable.
const UPGRADES = [
	{"id":"rotor","name":"Rotor en propeller","about":"Extra rotor- of propellerbladen. Een straaljager krijgt een langere vlam.","levels":[{"name":"Standaard","points":0},{"name":"+1 blad","points":200},{"name":"+2 bladen","points":700}]},
	{"id":"motor","name":"Motor","about":"Sneller bij Leren en Oefenen. Bij Records vliegt iedereen even snel.","levels":[{"name":"Standaard","points":0},{"name":"Turbo","points":300},{"name":"Superturbo","points":1000}]},
	{"id":"lights","name":"Lichtpakket","about":"Extra landingslampen en flitsers.","levels":[{"name":"Standaard","points":0},{"name":"Extra lampen","medal":"foutloos"}]},
]

const MEDALS = {
	"eerste_record":"Eerste record gevlogen",
	"foutloos":"Foutloze Records-vlucht (drie sterren)",
	"europa":"Een missie in Europa voltooid",
	"combi":"Twee huiswerkopdrachten in één vlucht",
	"huiswerk":"Alle zes huiswerkopdrachten gevlogen",
}

const RANKS = [[0,"Leerling-piloot"],[150,"Piloot"],[450,"Gezagvoerder"],[900,"Reddingspiloot"],[1500,"Topopiloot"],[2500,"Radarkapitein"],[3500,"Straaljagerpiloot"],[5000,"Luchtvaartlegende"]]

# body, trim and dark are required; tail defaults to body, glass and accent to
# the factory values. The first nine are the original free schemes.
const SCHEMES = [
	{"name":"Reddingsoranje","body":"e67b34","trim":"dce4dc","dark":"263845"},
	{"name":"Traumageel","body":"f4c51c","trim":"2a3035","dark":"1f2428"},
	{"name":"Politie","body":"f1f3f5","trim":"1e4fa3","dark":"23344a"},
	{"name":"Marinegrijs","body":"6f7b80","trim":"d9dfe0","dark":"2d3a40"},
	{"name":"Racerood","body":"c62f2f","trim":"f2f2f2","dark":"1d1f22"},
	{"name":"Junglegroen","body":"4f7a3a","trim":"d7c48b","dark":"2d3a2a"},
	{"name":"Nachtzwart","body":"25292c","trim":"f0b93a","dark":"111315"},
	{"name":"Oceaanblauw","body":"2f7fb8","trim":"f4efe0","dark":"1d3346"},
	{"name":"Flamingoroze","body":"e57fa8","trim":"fff1f6","dark":"3b2b3a"},
	{"name":"Ambulance","body":"f4f4f0","trim":"2e9e4f","dark":"2b3035","accent":"e8c33a","points":50},
	{"name":"Brandweer","body":"c8211d","trim":"f2d22e","dark":"1b1d20","points":80},
	{"name":"Kustwacht","body":"f2f2ee","tail":"e0582a","trim":"1f4a8a","dark":"263845","points":120},
	{"name":"Woestijn","body":"c9a66b","trim":"8a6a3f","dark":"4a3b2a","points":180},
	{"name":"Camouflage","body":"556b3a","tail":"3e4f2c","trim":"8a8a5c","dark":"2a3324","points":250},
	{"name":"IJsblauw","body":"bfe6f2","trim":"ffffff","dark":"3a5a6a","glass":"1c3a50","points":320},
	{"name":"Zonsondergang","body":"ff7b54","tail":"ffb26b","trim":"7a3e9d","dark":"2d1e3a","points":400},
	{"name":"Lavendel","body":"a98bd6","trim":"f3eefa","dark":"3b2f52","points":500},
	{"name":"Limoen","body":"9bd13b","trim":"1e2a1a","dark":"1a2414","points":600},
	{"name":"Kers en room","body":"9e1b32","trim":"f6e7d8","dark":"2a1a20","points":700},
	{"name":"Middernacht","body":"1b2a4a","tail":"0f1a30","trim":"5ce1ff","dark":"0c1220","glass":"2a6a8a","accent":"5ce1ff","points":850},
	{"name":"Robijn","body":"b0102a","trim":"ffd166","dark":"1a0a10","points":1000},
	{"name":"Neonracer","body":"1a1a1a","trim":"39ff14","dark":"0a0a0a","accent":"ff2bd6","points":1200},
	{"name":"Goud","body":"d4a017","trim":"fff4c2","dark":"3a2c08","accent":"ffffff","medal":"foutloos"},
	{"name":"Europa","body":"1f3f99","trim":"ffcc00","dark":"102050","accent":"ffcc00","medal":"europa"},
	{"name":"Recordzilver","body":"c0c6cc","trim":"2a2f35","dark":"1a1d21","accent":"e63946","medal":"eerste_record"},
]

# Factory paint as hex strings without '#'. The helicopter view and the paint
# rules both read it from here, so the rules do not depend on the view class.
const DEFAULT_PAINT = {"body":"e67b34","tail":"e67b34","trim":"dce4dc","rotor":"263845","gear":"263845","glass":"1d3446","accent":"f2c14e"}
const DEFAULT_GARAGE = {"model":"redder","accessories":[],"rotor":0,"motor":0,"lights":0}
const MAX_POINTS = 10000000

static func scheme_paint(scheme: Dictionary) -> Dictionary:
	return {
		"body":scheme.body,
		"tail":scheme.get("tail",scheme.body),
		"trim":scheme.trim,
		"rotor":scheme.dark,
		"gear":scheme.dark,
		"glass":scheme.get("glass",DEFAULT_PAINT.glass),
		"accent":scheme.get("accent",DEFAULT_PAINT.accent),
	}

static func unlocked(item: Dictionary,points: int,medals: Array) -> bool:
	if item.has("medal"):
		return item.medal in medals
	return points>=int(item.get("points",0))

static func requirement(item: Dictionary,points: int) -> String:
	if item.has("medal"):
		return "Medaille: "+MEDALS.get(item.medal,item.medal).to_lower()
	return "Nog %d vliegpunten" % maxi(int(item.get("points",0))-points,0)

static func find(list: Array,id: String) -> Dictionary:
	for item in list:
		if item.id==id:
			return item
	return {}

static func upgrade_levels(id: String) -> int:
	return find(UPGRADES,id).get("levels",[{}]).size()

static func rank(points: int) -> String:
	var name: String=RANKS[0][1]
	for entry in RANKS:
		if points>=entry[0]:
			name=entry[1]
	return name

# Every lockable item as [label, requirement dictionary], for progress texts.
static func all_items() -> Array:
	var items: Array=[]
	for m in MODELS:
		items.append([{"heli":"heli ","vliegtuig":"vliegtuig ","jet":"straaljager "}[m.kind]+m.name,m])
	for a in ACCESSORIES:
		items.append([a.name,a])
	for u in UPGRADES:
		for level in range(1,u.levels.size()):
			items.append(["%s %s" % [u.name,u.levels[level].name],u.levels[level]])
	for s in SCHEMES:
		items.append(["kleur "+s.name,s])
	# Pilot looks: an option with a third element is earned like a hangar item.
	for entry in PilotFigure.ATTRIBUTES:
		for option in entry[2]:
			if option.size()>2:
				items.append(["%s %s" % [String(entry[1]).to_lower(),option[1]],option[2]])
	return items

static func model_kind(id: String) -> String:
	return String(find(MODELS,id).get("kind","heli"))

static func models_of(kind: String) -> Array:
	return MODELS.filter(func(m): return m.kind==kind)

# The cheapest item still locked behind points, or {} when everything is earned.
static func next_unlock(points: int) -> Dictionary:
	var best: Dictionary={}
	for entry in all_items():
		var item: Dictionary=entry[1]
		if item.has("medal") or int(item.get("points",0))<=points:
			continue
		if best.is_empty() or int(item.points)<int(best.points):
			best={"name":entry[0],"points":int(item.points)}
	return best

static func unlocked_names(points: int,medals: Array) -> PackedStringArray:
	var names=PackedStringArray()
	for entry in all_items():
		var item: Dictionary=entry[1]
		if (item.has("medal") or int(item.get("points",0))>0) and unlocked(item,points,medals):
			names.append(entry[0])
	return names

# Names earned between two progress snapshots, for the mission summary.
static func newly_unlocked(points_before: int,medals_before: Array,points_after: int,medals_after: Array) -> PackedStringArray:
	var before=unlocked_names(points_before,medals_before)
	var fresh=PackedStringArray()
	for name in unlocked_names(points_after,medals_after):
		if not name in before:
			fresh.append(name)
	return fresh

# Points for one finished mission. Harder modes pay more per place; the star
# bonus grows with the route but is capped so tiny lists cannot farm it.
static func mission_points(mode: int,found: int,first_try: int,stars: int,new_record: bool,places: int) -> int:
	var per_place: int=[10,15,20][clampi(mode,0,2)]
	return found*per_place+first_try*5+stars*mini(places,10)*2+(25 if new_record else 0)

static func clean_garage(raw: Variant) -> Dictionary:
	var garage: Dictionary=DEFAULT_GARAGE.duplicate(true)
	if not raw is Dictionary:
		return garage
	if raw.get("model") is String and not find(MODELS,raw.model).is_empty():
		garage.model=raw.model
	if raw.get("accessories") is Array:
		for id in raw.accessories:
			if id is String and not find(ACCESSORIES,id).is_empty() and not id in garage.accessories:
				garage.accessories.append(id)
	for u in UPGRADES:
		var level: Variant=raw.get(u.id)
		if typeof(level) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(level)) and float(level)==floor(float(level)):
			garage[u.id]=clampi(int(level),0,u.levels.size()-1)
	return garage

# What the helicopter really carries: anything still locked falls back to the
# factory choice, so an edited save file cannot skip the unlocks.
static func effective(garage: Dictionary,points: int,medals: Array) -> Dictionary:
	var out: Dictionary=clean_garage(garage)
	if not unlocked(find(MODELS,out.model),points,medals):
		out.model=DEFAULT_GARAGE.model
	var kept: Array=[]
	for id in out.accessories:
		if unlocked(find(ACCESSORIES,id),points,medals):
			kept.append(id)
	out.accessories=kept
	for u in UPGRADES:
		while out[u.id]>0 and not unlocked(u.levels[out[u.id]],points,medals):
			out[u.id]-=1
	return out
