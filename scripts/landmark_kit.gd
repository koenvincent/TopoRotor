class_name LandmarkKit
extends RefCounted

# Recognisable miniature silhouettes for real Dutch landmarks. Every piece is
# merged into the shared DutchScenery colour surfaces, so 100+ landmarks cost
# no extra draw calls. Positions/types come from data/landmarks_nl.json.
const WATER = "318c9a"
const SLATE = "445c62"
const STONE = "d8d1bc"
const FOOTPRINTS = {
	"spire":1.0,"church":0.0,"windmill":1.5,"gate":1.5,"water_gate":1.3,"castle":2.1,
	"palace":3.2,"museum":0.0,"hall":0.0,"stadium":2.9,"skyscraper":1.0,"needle":1.1,
	"cubes":1.8,"saucer":1.9,"lighthouse":1.0,"ship":2.1,"hunebed":1.7,"race_track":3.6,
	"headframe":1.8,"waag":1.4,"harbour_tower":1.7,"lock":3.8,"colour_blocks":2.3,
	"dome":2.1,"four_towers":2.0,"textile_mill":2.3,"factory":2.4,"gothic_hall":1.3,
}

var s: DutchScenery
var cyl = CylinderMesh.new()
var taper = CylinderMesh.new()

func _init(scenery: DutchScenery) -> void:
	s=scenery
	cyl.top_radius=.5
	cyl.bottom_radius=.5
	cyl.height=1
	cyl.radial_segments=10
	taper.top_radius=.32
	taper.bottom_radius=.5
	taper.height=1
	taper.radial_segments=8

static func known(type: String) -> bool:
	return type=="builtin" or FOOTPRINTS.has(type)

# Radius in which generated city plots are cleared so a landmark stands free.
static func footprint(entry: Dictionary) -> float:
	var type: String=entry.get("type","")
	if type in ["church","museum","hall"]:
		return float(entry.get("length",3.0))*.5+.8
	if type=="palace":
		return 3.2*float(entry.get("scale",1.0))+(1.2 if entry.get("gardens",false) else 0.0)
	if type=="waag" and entry.get("cheese",false):
		return 2.1
	return float(FOOTPRINTS.get(type,1.2))

func build(pos: Vector3,entry: Dictionary) -> void:
	var c: String=entry.get("color","c4ad87")
	match entry.get("type",""):
		"spire": spire(pos,c,float(entry.get("height",5.0)),float(entry.get("lean",0.0)))
		"church": church(pos,entry,c)
		"windmill": windmill(pos,float(entry.get("height",4.0)))
		"gate": gate(pos,c,entry.get("pointed",true),entry.get("single",false))
		"water_gate": s.water_gate(pos)
		"castle": castle(pos,entry.get("moat",false),entry.get("round",false))
		"palace": palace(pos,float(entry.get("scale",1.0)),entry.get("gardens",false))
		"museum": museum(pos,entry,c)
		"hall": hall(pos,float(entry.get("length",4.0)),2.4,c if entry.has("color") else "c9d3d0")
		"stadium": stadium(pos,entry.get("roof","open")=="closed")
		"skyscraper": skyscraper(pos,float(entry.get("height",6.0)),float(entry.get("width",1.2)),c,entry.get("glass",false))
		"needle": needle(pos,float(entry.get("height",9.0)))
		"cubes": cubes(pos,c)
		"saucer": saucer(pos)
		"lighthouse": lighthouse(pos,c,float(entry.get("height",6.0)))
		"ship": ship(pos,c,int(entry.get("masts",3)))
		"hunebed": hunebed(pos)
		"race_track": race_track(pos)
		"headframe": headframe(pos)
		"waag": waag(pos,entry.get("cheese",false))
		"harbour_tower": harbour_tower(pos,entry.get("round",false))
		"lock": sea_lock(pos)
		"colour_blocks": colour_blocks(pos)
		"dome": dome(pos,entry.get("pool",false))
		"four_towers": four_towers(pos)
		"textile_mill": textile_mill(pos)
		"factory": s.factory(pos)
		"gothic_hall": gothic_hall(pos,c,int(entry.get("towers",0)))

func put(mesh: Mesh,origin: Vector3,basis: Basis,color: String) -> void:
	s.surface(color).append_from(mesh,0,Transform3D(basis,origin))

func column(pos: Vector3,radius: float,height: float,color: String,mesh: Mesh=null) -> void:
	put(cyl if mesh==null else mesh,pos+Vector3(0,height*.5,0),Basis.from_scale(Vector3(radius*2,height,radius*2)),color)

func roof_top(pos: Vector3,width: float,kind: String,color: String) -> void:
	# pos is the top centre of a tower body.
	match kind:
		"lantern":
			s.block(pos+Vector3(0,.35,0),Vector3(width*.7,.7,width*.7),color)
			column(pos+Vector3(0,.7,0),width*.32,.8,color)
			s.piece(s.leaf,pos+Vector3(0,1.6,0),Vector3(width*.55,.6,width*.55),SLATE)
			s.piece(s.cone,pos+Vector3(0,2.3,0),Vector3(.12,.9,.12),SLATE)
		"flat":
			for x in [-1,1]:
				for z in [-1,1]:
					s.piece(s.cone,pos+Vector3(x*width*.42,.35,z*width*.42),Vector3(.16,.7,.16),color)
			s.block(pos+Vector3(0,.1,0),Vector3(width*1.04,.2,width*1.04),"b9ae92")
		_:
			s.piece(s.cone,pos+Vector3(0,width*1.2,0),Vector3(width*.5,width*2.4,width*.5),SLATE)

func spire(pos: Vector3,color: String,height: float,lean: float=0.0) -> void:
	# Stacked, narrowing tower with clock faces; optional lean (Delft Oude Kerk).
	var parts=[[.0,.56,1.35],[.56,.3,1.05],[.86,.12,.78]]
	for p in parts:
		var mid=height*(p[0]+p[1]*.5)
		s.block(pos+Vector3(lean*mid,mid,0),Vector3(p[2],height*p[1],p[2]),color if p[0]<.8 else "b9ae92")
	s.block(pos+Vector3(lean*height*.7,height*.72,.54),Vector3(.38,.38,.04),"ead8a1")
	for x in [-.32,.32]:
		s.block(pos+Vector3(x+lean*height*.4,height*.4,.69),Vector3(.2,.9,.04),"344b4e")
	s.piece(s.cone,pos+Vector3(lean*height,height*1.1,0),Vector3(.55,height*.3,.55),SLATE)

func church(pos: Vector3,entry: Dictionary,color: String) -> void:
	var length=float(entry.get("length",3.0))
	var height=float(entry.get("height",4.6))
	# Nave runs east-west; the tower stands at the west (-x) end.
	s.house(pos,Vector3(1.6,1.8,length),color,"5a6862",PI/2,0)
	if entry.get("buttresses",false):
		for i in 5:
			for z in [-.9,.9]:
				s.block(pos+Vector3(-length*.4+i*length*.2,.7,z),Vector3(.18,1.4,.25),color)
	if entry.get("crossing",false):
		s.block(pos+Vector3(length*.08,1.2,0),Vector3(1.0,1.6,2.6),color)
		s.piece(s.roof,pos+Vector3(length*.08,2.3,0),Vector3(1.1,.6,2.7),"5a6862",PI/2)
		s.piece(s.cone,pos+Vector3(length*.08,3.1,0),Vector3(.25,1.3,.25),SLATE)
	if entry.get("tower",true):
		var at=pos+Vector3(-length*.5-.55,0,0)
		s.block(at+Vector3(0,height*.36,0),Vector3(1.4,height*.72,1.4),color)
		s.block(at+Vector3(0,height*.78,0),Vector3(1.1,height*.12,1.1),color)
		s.block(at+Vector3(-.71,height*.62,0),Vector3(.04,.4,.4),"ead8a1")
		roof_top(at+Vector3(0,height*.84,0),1.0,entry.get("top","spire"),color)

func windmill(pos: Vector3,height: float) -> void:
	# Tall stage mill: dark body, white stage, cap and four lattice sails.
	put(taper,pos+Vector3(0,height*.42,0),Basis.from_scale(Vector3(1.7,height*.84,1.7)),"3f4a45")
	column(pos+Vector3(0,height*.34,0),1.15,.12,"e8e2cf")
	for i in 8:
		var a=TAU*i/8
		s.block(pos+Vector3(cos(a)*1.1,height*.34-.35,sin(a)*1.1),Vector3(.06,.7,.06),"6b5a45")
	s.block(pos+Vector3(0,.4,0),Vector3(1.9,.8,1.9),"8e3f34")
	s.piece(s.leaf,pos+Vector3(0,height*.86,0),Vector3(1.15,.7,1.25),"e9e2cc")
	var hub=pos+Vector3(0,height*.86,.75)
	for k in 4:
		var a=PI/4+k*PI/2
		var dir=Vector3(cos(a),sin(a),0)
		s.beam(hub,hub+dir*height*.62,.11,"efe8d3")
		var side=Vector3(-dir.y,dir.x,0)
		s.beam(hub+dir*height*.15+side*.22,hub+dir*height*.6+side*.22,.05,"c9a37a")
		for t in [.25,.38,.51]:
			s.beam(hub+dir*height*t,hub+dir*height*t+side*.42,.035,"efe8d3")

func gate(pos: Vector3,color: String,pointed: bool,single: bool) -> void:
	var xs=[0.0] if single else [-.95,.95]
	for x in xs:
		s.block(pos+Vector3(x,1.35,0),Vector3(1.0 if not single else 1.5,2.7,1.0),color)
		if pointed:
			s.piece(s.cone,pos+Vector3(x,3.4,0),Vector3(.6 if not single else .85,1.6,.6 if not single else .85),SLATE)
		else:
			for c in [-.35,.35]:
				s.block(pos+Vector3(x+c,2.82,0),Vector3(.25,.25,1.0),color)
	if not single:
		s.block(pos+Vector3(0,1.35,0),Vector3(1.0,1.6,.8),color)
		s.block(pos+Vector3(0,2.3,0),Vector3(1.1,.4,.85),SLATE)
	s.block(pos+Vector3(0,.5,.5 if single else .41),Vector3(.55,1.0,.04),"2c3133")

func castle(pos: Vector3,moat: bool,round_keep: bool) -> void:
	if moat:
		for side in [[0,-2.0,4.4,.6],[0,2.0,4.4,.6],[-2.0,0,.6,4.4],[2.0,0,.6,4.4]]:
			s.block(pos+Vector3(side[0],.1,side[1]),Vector3(side[2],.1,side[3]),WATER)
	if round_keep:
		# Leiden Burcht: shell keep with crenellated ring wall on a mound.
		s.mound(pos,Vector2(2.0,2.0),1.0,"7f9b55")
		for i in 18:
			var a=TAU*i/18
			s.block(pos+Vector3(cos(a)*1.25,1.35,sin(a)*1.25),Vector3(.45,.8 if i%2==0 else .62,.32),"b8a080",-a)
		return
	s.block(pos+Vector3(0,.9,0),Vector3(2.4,1.8,2.4),"b07a58")
	s.piece(s.roof,pos+Vector3(0,2.15,0),Vector3(2.4,.7,2.4),"58625e")
	for x in [-1.2,1.2]:
		for z in [-1.2,1.2]:
			column(pos+Vector3(x,0,z),.38,2.5,"a8704f")
			s.piece(s.cone,pos+Vector3(x,3.0,z),Vector3(.5,1.0,.5),SLATE)
	s.block(pos+Vector3(0,.45,1.22),Vector3(.5,.9,.04),"2c3133")

func palace(pos: Vector3,scale_value: float,gardens: bool) -> void:
	var k=scale_value
	s.block(pos+Vector3(0,1.0*k,0),Vector3(3.2*k,2.0*k,1.4*k),"c4ab80")
	s.piece(s.roof,pos+Vector3(0,2.3*k,0),Vector3(3.3*k,.6*k,1.5*k),"55605a")
	for x in [-1.9,1.9]:
		s.block(pos+Vector3(x*k,.75*k,.9*k),Vector3(.8*k,1.5*k,2.4*k),"c4ab80")
		s.piece(s.roof,pos+Vector3(x*k,1.75*k,.9*k),Vector3(.9*k,.5*k,2.5*k),"55605a")
	s.block(pos+Vector3(0,2.65*k,0),Vector3(.5*k,.5*k,.5*k),"e2d6b6")
	if gardens:
		# Formal parterre behind the palace: hedged squares and a fountain.
		s.block(pos+Vector3(0,.07,-2.4*k),Vector3(4.2*k,.06,2.6*k),"9db17a")
		for x in [-1.3,0.0,1.3]:
			for z in [-1.7,-3.0]:
				s.block(pos+Vector3(x*k,.14,z*k),Vector3(1.0*k,.12,1.0*k),"3f6a3c")
		column(pos+Vector3(0,.1,-2.35*k),.35*k,.1,WATER)

func museum(pos: Vector3,entry: Dictionary,color: String) -> void:
	var length=float(entry.get("length",4.0))
	s.house(pos,Vector3(length,1.9,1.5),color,"4e5a58",0,0)
	match int(entry.get("towers",2)):
		2:
			for x in [-.2,.2]:
				var at=pos+Vector3(x*length,0,.2)
				s.block(at+Vector3(0,1.7,0),Vector3(.75,3.4,.75),color)
				s.piece(s.cone,at+Vector3(0,4.0,0),Vector3(.45,1.2,.45),"6f8a7c")
				s.block(at+Vector3(0,2.9,.39),Vector3(.32,.32,.04),"e2c46b")
		1:
			var at=pos+Vector3(length*.42,0,.1)
			s.block(at+Vector3(0,2.1,0),Vector3(.8,4.2,.8),color)
			s.piece(s.cone,at+Vector3(0,4.9,0),Vector3(.4,1.4,.4),"6f8a7c")
	s.block(pos+Vector3(0,.55,.77),Vector3(.9,1.1,.04),"2c3133")
	if entry.get("train_shed",false):
		hall(pos+Vector3(0,0,-1.9),length*.9,2.2,"b9c2c0")

func hall(pos: Vector3,length: float,width: float,color: String) -> void:
	# Barrel-vault roof (station shed, ice rink) built from rotated plates.
	var segments=7
	for i in segments:
		var a0=PI*float(i)/segments
		var a1=PI*float(i+1)/segments
		var p0=Vector3(0,.35+sin(a0)*width*.45,cos(a0)*width*.5)
		var p1=Vector3(0,.35+sin(a1)*width*.45,cos(a1)*width*.5)
		var mid=(p0+p1)*.5
		var tilt=atan2(p1.y-p0.y,p1.z-p0.z)
		var basis=Basis(Vector3.RIGHT,-tilt)*Basis.from_scale(Vector3(length,.08,p0.distance_to(p1)+.02))
		put(s.box,pos+mid,basis,color if i%2==0 else "aab4b2")
	for z in [-.5,.5]:
		s.block(pos+Vector3(0,.2,z*width),Vector3(length,.4,.08),"7d8a88")

func stadium(pos: Vector3,closed: bool) -> void:
	s.block(pos+Vector3(0,.09,0),Vector3(3.0,.06,1.9),"4f9a45")
	s.block(pos+Vector3(0,.13,0),Vector3(.04,.02,1.9),"f2f2e8")
	var count=20
	for i in count:
		var a=TAU*float(i)/count
		var at=pos+Vector3(cos(a)*2.3,0,sin(a)*1.6)
		var facing=atan2(cos(a)*1.6,sin(a)*2.3)
		s.block(at+Vector3(0,.55,0),Vector3(.95,1.1,.5),"c3c9c6",facing)
		s.block(at+Vector3(0,.75,0)-Vector3(cos(a),0,sin(a))*.2,Vector3(.9,.12,.25),"c4473a",facing)
		s.block(at+Vector3(0,1.2,0),Vector3(1.0,.1,.8),"e7ebe7",facing)
	if closed:
		s.block(pos+Vector3(0,1.3,0),Vector3(3.4,.1,2.4),"d9dfdc")
		s.block(pos+Vector3(0,1.37,0),Vector3(1.6,.04,.9),"9fc6c9")
	for x in [-2.4,2.4]:
		s.beam(pos+Vector3(x,0,-1.7),pos+Vector3(x,2.4,-1.7),.08,"8e9895")

func skyscraper(pos: Vector3,height: float,width: float,color: String,glass: bool) -> void:
	s.block(pos+Vector3(0,height*.5,0),Vector3(width,height,width*.85),color)
	var bands=int(height/.55)
	for i in bands:
		var y=.4+i*.55
		if y>height-.2:
			break
		s.block(pos+Vector3(0,y,width*.43),Vector3(width*.9,.16 if not glass else .05,.04),"35535a" if not glass else "e8eeee")
	s.block(pos+Vector3(0,height+.15,0),Vector3(width*.6,.3,width*.5),"7f8b8d")
	if glass:
		for x in [-.5,0.0,.5]:
			s.block(pos+Vector3(x*width,height*.5,width*.43),Vector3(.04,height,.05),"e8eeee")

func needle(pos: Vector3,height: float) -> void:
	# Euromast: concrete shaft, crow's-nest ring, slim Space Tower and antenna.
	column(pos,.42,height*.55,"dcd6c6")
	column(pos+Vector3(0,height*.5,0),1.2,.35,"cfc9b8")
	column(pos+Vector3(0,height*.53,0),1.0,.3,"7fa2a9")
	column(pos+Vector3(0,height*.55,0),.22,height*.35,"e8e4d8")
	column(pos+Vector3(0,height*.88,0),.42,.4,"c8463b")
	s.beam(pos+Vector3(0,height*.9,0),pos+Vector3(0,height*1.02,0),.06,"e8e4d8")

func cubes(pos: Vector3,color: String) -> void:
	# Tilted cube houses (Rotterdam Blaak, Helmond paalwoningen) on poles.
	var tilt=Basis(Vector3(1,0,-1).normalized(),atan(sqrt(2.0)))
	for i in 5:
		var at=pos+Vector3(-2.0+i*1.0,0,(i%2)*.5-.25)
		column(at,.18,1.25,"8d9592")
		put(s.box,at+Vector3(0,1.25+.6,0),Basis(Vector3.UP,PI/4)*tilt*Basis.from_scale(Vector3.ONE*.85),color)
		put(s.box,at+Vector3(0,1.25+.6,0),Basis(Vector3.UP,PI/4)*tilt*Basis.from_scale(Vector3(.87,.87,.6)),"4f6970")

func saucer(pos: Vector3) -> void:
	# Evoluon: flying-saucer dome on a ring of slanted legs.
	for i in 8:
		var a=TAU*i/8
		s.beam(pos+Vector3(cos(a)*1.0,0,sin(a)*1.0),pos+Vector3(cos(a)*1.6,1.2,sin(a)*1.6),.14,"d8dcda")
	column(pos+Vector3(0,1.15,0),1.85,.3,"e9ecea")
	s.piece(s.leaf,pos+Vector3(0,1.4,0),Vector3(3.4,.9,3.4),"dde2e0")
	column(pos+Vector3(0,1.18,0),1.9,.12,"5d7a80")

func lighthouse(pos: Vector3,color: String,height: float) -> void:
	put(taper,pos+Vector3(0,height*.45,0),Basis.from_scale(Vector3(1.2,height*.9,1.2)),color)
	for t in [.28,.6]:
		put(cyl,pos+Vector3(0,height*t,0),Basis.from_scale(Vector3(1.12-t*.4,height*.1,1.12-t*.4)),"f2ece0")
	column(pos+Vector3(0,height*.9,0),.5,.15,"2f3537")
	column(pos+Vector3(0,height*.95,0),.33,.45,"ffe7a1")
	s.piece(s.cone,pos+Vector3(0,height*1.07,0),Vector3(.4,.4,.4),"2f3537")

func ship(pos: Vector3,color: String,masts: int) -> void:
	s.block(pos+Vector3(0,.12,0),Vector3(4.6,.1,1.6),WATER)
	s.block(pos+Vector3(0,.38,0),Vector3(3.2,.55,.8),color)
	s.piece(s.roof,pos+Vector3(1.8,.38,0),Vector3(.8,.55,.6),color,PI/2)
	if masts==0:
		# Grey navy frigate: superstructure and a lattice mast.
		s.block(pos+Vector3(-.2,.85,0),Vector3(1.4,.5,.6),"9aa3a5")
		s.block(pos+Vector3(-.4,1.3,0),Vector3(.6,.45,.5),"9aa3a5")
		s.beam(pos+Vector3(-.4,1.5,0),pos+Vector3(-.4,2.6,0),.08,"60686a")
		return
	s.block(pos+Vector3(-1.3,.85,0),Vector3(.8,.5,.75),"8a6544")
	for m in masts:
		var x=-.9+m*.9
		s.beam(pos+Vector3(x,.6,0),pos+Vector3(x,3.0-abs(m-1)*.4,0),.08,"4e3a28")
		for y in [1.5,2.2]:
			s.block(pos+Vector3(x,y,0),Vector3(.06,.5,.9),"efe6cf")

func hunebed(pos: Vector3) -> void:
	for i in 4:
		for z in [-.55,.55]:
			s.piece(s.leaf,pos+Vector3(-1.2+i*.8,.35,z),Vector3(.7,.8,.6),"8e8b80",i*.7)
	for i in 3:
		s.piece(s.leaf,pos+Vector3(-.85+i*.85,.95,0),Vector3(1.0,.45,1.45),"7d7a70",i*.4)

func race_track(pos: Vector3) -> void:
	var points: Array=[]
	for i in 25:
		var a=TAU*float(i)/24
		var r=Vector2(3.3,1.6)
		points.append(pos+Vector3(cos(a)*r.x+sin(a*2)*.6,.1,sin(a)*r.y))
	for i in 24:
		s.ribbon(points[i],points[i+1],.42,"4b4f52")
		if i%3==0:
			s.ribbon(points[i],points[i+1],.5,"d9473b" if i%2==0 else "f2f2ea")
	s.block(pos+Vector3(0,.55,-2.1),Vector3(3.0,1.1,.6),"c7cdca")
	s.block(pos+Vector3(0,1.15,-2.0),Vector3(3.1,.1,.9),"e6e9e6")

func headframe(pos: Vector3) -> void:
	# Mine shaft headframe: steel A-frame with two winding wheels.
	for x in [-.55,.55]:
		s.beam(pos+Vector3(x,0,.5),pos+Vector3(x*.4,3.8,0),.13,"8c3f33")
		s.beam(pos+Vector3(x,0,-1.4),pos+Vector3(x*.4,3.8,0),.11,"8c3f33")
	s.block(pos+Vector3(0,3.85,0),Vector3(.8,.2,.5),"8c3f33")
	for x in [-.22,.22]:
		put(cyl,pos+Vector3(x,4.3,0),Basis(Vector3.FORWARD,PI/2)*Basis.from_scale(Vector3(1.0,.08,1.0)),"5c6466")
	s.house(pos+Vector3(0,0,1.3),Vector3(1.8,1.2,1.0),"a8664a","5b6463",0,0)

func waag(pos: Vector3,cheese: bool) -> void:
	s.house(pos,Vector3(1.6,1.5,1.2),"b9805c","59615c",0,1)
	s.block(pos+Vector3(0,2.6,-.1),Vector3(.55,1.0,.55),"e8dcc0")
	s.piece(s.cone,pos+Vector3(0,3.4,-.1),Vector3(.35,.9,.35),SLATE)
	if cheese:
		s.block(pos+Vector3(0,.07,1.5),Vector3(3.4,.04,1.6),"d6ccb1")
		for x in 6:
			for z in 3:
				column(pos+Vector3(-1.3+x*.52,.08,1.0+z*.45),.17,.14,"f0b93a")

func harbour_tower(pos: Vector3,round_tower: bool) -> void:
	s.block(pos+Vector3(.6,.1,1.0),Vector3(3.2,.1,1.6),WATER)
	if round_tower:
		column(pos,.75,2.0,"b9a07e")
		s.piece(s.cone,pos+Vector3(0,2.5,0),Vector3(.8,1.0,.8),SLATE)
		return
	s.block(pos+Vector3(0,1.0,0),Vector3(1.4,2.0,1.4),"b5916c")
	s.block(pos+Vector3(0,2.2,0),Vector3(.7,.4,.7),"e8dcc0")
	s.piece(s.cone,pos+Vector3(0,2.9,0),Vector3(.35,1.0,.35),SLATE)

func sea_lock(pos: Vector3) -> void:
	s.block(pos+Vector3(0,.1,0),Vector3(1.6,.1,7.0),WATER)
	for x in [-1.0,1.0]:
		s.block(pos+Vector3(x,.3,0),Vector3(.4,.5,7.0),"c9c6b8")
	for z in [-3.2,3.2]:
		s.block(pos+Vector3(0,.45,z),Vector3(1.6,.6,.2),"3c4a4e")
		s.block(pos+Vector3(0,1.4,z),Vector3(2.4,.25,.4),"c9c6b8")
		for x in [-1.0,1.0]:
			s.block(pos+Vector3(x,.9,z),Vector3(.3,1.2,.3),"c9c6b8")
	s.block(pos+Vector3(0,.35,.4),Vector3(.7,.4,2.2),"354f59")
	s.block(pos+Vector3(0,.7,1.0),Vector3(.5,.4,.5),"ead6a5")

func colour_blocks(pos: Vector3) -> void:
	# Groninger Museum: gold tower, pink block and a tilted silver pavilion on water.
	s.block(pos+Vector3(0,.1,0),Vector3(5.0,.1,1.6),WATER)
	s.block(pos+Vector3(0,1.8,0),Vector3(.9,3.6,.9),"e7b528")
	s.block(pos+Vector3(-1.4,.7,0),Vector3(1.5,1.4,1.1),"d77fa0")
	put(s.box,pos+Vector3(1.5,.9,0),Basis(Vector3.FORWARD,.18)*Basis.from_scale(Vector3(1.6,1.4,1.1)),"aeb8bc")
	s.block(pos+Vector3(-.7,.4,0),Vector3(.6,.6,.9),"3e8f86")

func dome(pos: Vector3,pool: bool) -> void:
	if pool:
		column(pos+Vector3(1.6,0,1.0),1.0,.12,WATER)
	column(pos,1.9,.5,"c8cdc9")
	s.piece(s.leaf,pos+Vector3(0,.5,0),Vector3(3.6,2.2,3.6),"a9cfca")
	for i in 6:
		var a=TAU*i/6
		s.beam(pos+Vector3(cos(a)*1.75,.5,sin(a)*1.75),pos+Vector3(0,2.6,0),.06,"e8eeee")

func four_towers(pos: Vector3) -> void:
	# Munsterkerk Roermond: Romanesque nave, four towers and a crossing dome.
	var color="c2a37c"
	s.house(pos,Vector3(1.5,1.7,3.4),color,"58625e",PI/2,0)
	for x in [-1.9,1.9]:
		for z in [-.6,.6]:
			s.block(pos+Vector3(x,1.4,z),Vector3(.65,2.8,.65),color)
			s.piece(s.cone,pos+Vector3(x,3.3,z),Vector3(.4,1.0,.4),SLATE)
	column(pos+Vector3(.2,1.7,0),.55,.8,color)
	s.piece(s.leaf,pos+Vector3(.2,2.55,0),Vector3(1.1,.7,1.1),SLATE)

func textile_mill(pos: Vector3) -> void:
	for i in 5:
		s.block(pos+Vector3(-1.4+i*.7,.5,0),Vector3(.7,1.0,2.4),"a5613f")
		put(s.roof,pos+Vector3(-1.25+i*.7,1.3,0),Basis(Vector3.FORWARD,.0)*Basis.from_scale(Vector3(.7,.6,2.4)),"6c7a7c")
		s.block(pos+Vector3(-1.05+i*.7,1.3,0),Vector3(.04,.55,2.3),"9fc3c6")
	column(pos+Vector3(2.4,0,-.8),.35,5.2,"9c5638")
	column(pos+Vector3(2.4,5.2,-.8),.42,.25,"6e3d2b")

func gothic_hall(pos: Vector3,color: String,towers: int) -> void:
	# Free-standing town hall: tall stepped front, pinnacles, red shutters.
	s.block(pos+Vector3(0,1.0,0),Vector3(1.4,2.0,2.0),color)
	s.piece(s.roof,pos+Vector3(0,2.5,0),Vector3(1.45,1.0,2.05),"55605a")
	for level in 4:
		s.block(pos+Vector3(0,2.15+level*.32,1.0),Vector3(1.4-level*.32,.32,.12),color)
	for x in [-.7,.7]:
		s.piece(s.cone,pos+Vector3(x,2.6,1.0),Vector3(.14,.9,.14),SLATE)
	for x in [-.4,.4]:
		for y in [.8,1.5]:
			s.block(pos+Vector3(x,y,1.02),Vector3(.26,.4,.04),"b83a33")
	if towers>0:
		for x in [-.85,.85]:
			column(pos+Vector3(x,0,1.0),.25,2.8,color)
			s.piece(s.cone,pos+Vector3(x,3.2,1.0),Vector3(.3,.8,.3),"6f8a7c")
