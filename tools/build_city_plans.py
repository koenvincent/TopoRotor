"""Generate schematic neighbourhoods constrained by Natural Earth urban areas.

uv run --with shapely python tools/build_city_plans.py /path/to/ne_10m_urban_areas.geojson
These are miniature city layouts, not surveyed streets or individual buildings.
"""
import json, math, random, sys, zlib
from pathlib import Path
from shapely.geometry import Point, Polygon, MultiPoint, box, shape
from shapely.ops import transform, unary_union
from shapely.strtree import STRtree
from shapely import voronoi_polygons

ROOT=Path(__file__).resolve().parents[1]
places=[p for p in json.loads((ROOT/'data/places.json').read_text()) if p['region']=='nl' and p['kind']=='stad']
source=json.loads(Path(sys.argv[1]).read_text())
urban=[shape(f['geometry']) for f in source['features'] if f['geometry']]
urban=[p for p in urban if p.bounds[0]<7.5 and p.bounds[2]>3 and p.bounds[1]<54 and p.bounds[3]>50.5]
index=STRtree(urban)
water=unary_union([Polygon(r) for r in json.loads((ROOT/'data/map_nl.json').read_text())['lakes']])
types={}
for kind,names in {
 'canal':['Amsterdam','Utrecht','Delft','Leiden','Gouda','Alkmaar','Leeuwarden','Sneek','Hoorn','Middelburg'],
 'river':['Arnhem','Nijmegen','Maastricht','Deventer','Zutphen','Venlo','Roermond','Dordrecht'],
 'modern':['Almere','Lelystad'],
 'port':['Rotterdam','Den Helder','Vlissingen','Terneuzen'],
 'green':['Apeldoorn','Assen','Emmen','Wageningen','Harderwijk'],
 'industrial':['Eindhoven','Tilburg','Enschede','Hengelo','Helmond','Oss'],
}.items():
 for name in names:types[name]=kind
plans={}
sx=math.cos(math.radians(52.2))*85
for place in places:
 name=place['name'];lon=place['lon'];lat=place['lat'];kind=types.get(name,'historic')
 rng=random.Random(zlib.crc32(name.encode()))
 city=Point(lon,lat);poly=urban[index.nearest(city)]
 supported=poly.distance(city)<.015
 local=transform(lambda x,y:((x-lon)*sx,-(y-lat)*85),poly) if supported else None
 nearest=min(math.hypot((other['lon']-lon)*sx,(other['lat']-lat)*85) for other in places if other is not place)
 radius=min(6.5,max(2.2,nearest*.43))
 angle=rng.uniform(-.55,.55)
 if local is not None and local.area<220:
  rect=list(local.minimum_rotated_rectangle.exterior.coords)
  dx=rect[1][0]-rect[0][0];dz=rect[1][1]-rect[0][1]
  if abs(dx)+abs(dz)>.001:angle=math.atan2(dz,dx)
 count=48 if name in ['Amsterdam','Rotterdam','Utrecht','Den Haag','Groningen'] else rng.randrange(22,38)
 plots=[];occupied=[]
 # A different street orientation/shape per city, with a shared deterministic seed.
 for attempt in range(3000):
  if len(plots)>=count:break
  x=rng.uniform(-radius,radius);z=rng.uniform(-radius*.8,radius*.8)
  if (x/radius)**2+(z/(radius*.8))**2>1:continue
  if kind=='river' and abs(z)<.8:continue
  if kind=='canal' and abs(x+.6*math.sin(z*.8))<.5:continue
  if kind=='green' and math.hypot(x,z)<radius*.34:continue
  if kind in ['modern','industrial']:
   x=round(x/1.3)*1.3;z=round(z/1.4)*1.4
   if abs(x)<.5 or abs(z)<.45:continue
  elif kind=='historic' and math.hypot(x,z)<.9:continue
  xx=x*math.cos(angle)-z*math.sin(angle);zz=x*math.sin(angle)+z*math.cos(angle)
  width=rng.uniform(.50,.82);depth=rng.uniform(.65,1.05)
  rect=box(xx-width*.65,zz-depth*.65,xx+width*.65,zz+depth*.65)
  if supported and not local.covers(rect):continue
  geo=Point(lon+xx/sx,lat-zz/85)
  if water.contains(geo):continue
  if any(rect.intersects(old) for old in occupied):continue
  h=rng.uniform(.85,2.4);style=rng.choice([0,0,1,1,3])
  if kind=='modern':h=rng.uniform(1.1,3.6);style=2
  elif kind=='industrial' and rng.random()<.4:width*=1.25;h=.8;style=2
  elif kind=='port' and rng.random()<.45:h=.75;style=2
  elif kind=='green':h=rng.uniform(.7,1.5)
  # A clear central reserve keeps the existing iconic models readable.
  landmark_reserve=3.6 if name in ['Amsterdam','Rotterdam','Utrecht'] else 1.3
  if math.hypot(xx,zz)<landmark_reserve:continue
  plots.append([round(xx,3),round(zz,3),round(width,3),round(depth,3),round(h,3),round(angle+rng.uniform(-.10,.10),3),style])
  occupied.append(rect)
 if not plots:raise ValueError('No neighbourhood generated for '+name)
 outline=unary_union(occupied).buffer(.3).simplify(.12,preserve_topology=True)
 rings=[outline] if outline.geom_type=='Polygon' else list(outline.geoms)
 hull=MultiPoint([(p[0],p[1]) for p in plots]).convex_hull.buffer(.35)
 road_geometry=voronoi_polygons(MultiPoint([(p[0],p[1]) for p in plots]),only_edges=True).intersection(hull) if len(plots)>2 else None
 roads=[]
 if road_geometry is not None:
  for line in getattr(road_geometry,'geoms',[road_geometry]):
   if line.geom_type=='LineString' and line.length>.15:
    roads.append([[round(x,3),round(z,3)] for x,z in line.coords])
 plans[name]={'streets':roads,'kind':kind,'seed':zlib.crc32(name.encode()),'source_supported':supported,'angle':round(angle,3),'radius':round(radius,3),'plots':plots,'blocks':[[[round(x,3),round(z,3)] for x,z in p.exterior.coords] for p in rings if p.area>.1]}
(ROOT/'data/city_plans_nl.json').write_text(json.dumps({'source':'Natural Earth 1:10m urban areas','note':'Synthetic plots within historical urban extents; symbolic roads and exaggerated landmarks, not a street map.','cities':plans},ensure_ascii=False,separators=(',',':'))+'\n')
print('Generated',len(plans),'distinct plans with',sum(len(p['plots']) for p in plans.values()),'building plots')
print('Schematic fallback (not covered by source):',[n for n,p in plans.items() if not p['source_supported']])
