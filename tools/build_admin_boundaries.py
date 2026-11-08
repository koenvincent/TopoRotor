"""Bundle simplified PDOK/Kadaster boundaries for offline game/minimap use.

uv run --with shapely python tools/build_admin_boundaries.py work/admin-source --source-updated 2026-01-28
Source GeoJSON collections: gemeentegebied, provinciegebied, landgebied (PDOK OGC API, f=json, limit=1000).
CC BY 4.0, Kadaster NL. Shared edges are noded/deduplicated before simplification.
--source-updated is the date Kadaster published the data (the API does not say); the retrieval date is the
timeStamp inside the downloaded files. Both are written to the output, so neither can go stale unnoticed.
Province fills are plain outer rings (the game has no holes). Holes smaller than MAX_HOLE (the Belgian
enclaves of Baarle-Hertog) are filled; a bigger one stops the build rather than flooding land.
Run after tools/import_nl_lakes.py: the fills are cut against the lakes in data/map_nl.json (lakes_sha).
"""
import argparse,hashlib,json,sys
from pathlib import Path
from shapely.geometry import Polygon,LineString,Point,shape
from shapely.geometry.polygon import orient
from shapely.ops import unary_union,linemerge
from shapely.strtree import STRtree
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('source',type=Path)
parser.add_argument('--source-updated',required=True,help='YYYY-MM-DD, publication date of the Kadaster data')
options=parser.parse_args()
source=options.source
MAX_HOLE=.001  # square degrees (about 8 km2); the largest Baarle enclave is .0002
SNAP=.00005  # degrees (about 5 m); line ends closer than this to a coarser line vertex are moved onto it
def collection(name):return json.loads((source/(name+'.geojson')).read_text())
stamps=[]
def features(name):
 data=collection(name);stamps.append(data['timeStamp'][:10]);return data['features']
municipal=features('gemeentegebied');provincial=features('provinciegebied');national=features('landgebied')
country=unary_union([shape(f['geometry']) for f in national])
country_lines=country.boundary
province_lines=unary_union([shape(f['geometry']).boundary for f in provincial]).difference(country_lines.buffer(.000002))
municipal_lines=unary_union([shape(f['geometry']).boundary for f in municipal]).difference(unary_union([country_lines,province_lines]).buffer(.000002))
def lines(geom):
 if geom.geom_type not in ["LineString","LinearRing"]:
  geom=linemerge(geom)
 result=[]
 for item in ([geom] if geom.geom_type in ['LineString','LinearRing'] else geom.geoms):
  if item.geom_type not in ['LineString','LinearRing']:
   result.extend(lines(item));continue
  simple=item.simplify(.0007,preserve_topology=True)
  if simple.length>.001:
   result.append([[round(x,6),round(y,6)] for x,y in simple.coords])
 return result
map_data=json.loads((ROOT/'data/map_nl.json').read_text())
land=unary_union([Polygon(r) for c in map_data['countries'] if c['code']=='NLD' for r in c['polygons']]).difference(unary_union([Polygon(r) for r in map_data['lakes']]))
def rings(geometry):
 pending=[geometry];result=[];filled=0
 while pending:
  polygon=pending.pop()
  if polygon.is_empty:continue
  if polygon.geom_type in ['MultiPolygon','GeometryCollection']:
   pending.extend(p for p in polygon.geoms if p.geom_type in ['Polygon','MultiPolygon']);continue
  if polygon.geom_type!='Polygon' or polygon.area<.000015:continue
  big=[i for i in polygon.interiors if Polygon(i).area>MAX_HOLE]
  if big:raise ValueError('Hole of %.5f deg2 cannot be stored: the game format has no holes'%Polygon(big[0]).area)
  filled+=len(polygon.interiors)
  simple=Polygon(polygon.exterior).simplify(.0008,preserve_topology=True)
  if simple.geom_type=='Polygon' and not simple.is_empty:result.append([[round(x,6),round(y,6)] for x,y in orient(simple,-1).exterior.coords])
 return result,filled
provinces=[];holes_filled=0
for feature in sorted(provincial,key=lambda f:f['properties']['code']):
 p=feature['properties'];geometry=shape(feature['geometry'])
 parts,filled=rings(geometry.intersection(land));holes_filled+=filled
 provinces.append({'code':p['code'],'name':p['naam'],'polygons':parts})
# Simplifying each level on its own leaves ends of provincial/municipal lines ~1e-6 degrees off the
# coarser line they meet. Move every such end onto the vertex it belongs to, so the lines join exactly.
def snap_ends(paths,reference):
 points=[Point(v) for path in reference for v in path]
 tree=STRtree(points);moved=0
 for path in paths:
  for i in (0,-1):
   found=tree.nearest(Point(path[i]))
   target=points[found].coords[0]
   if path[i]!=list(target) and Point(path[i]).distance(points[found])<SNAP:
    path[i]=[target[0],target[1]];moved+=1
 return moved
line_sets={'municipal':lines(municipal_lines),'provincial':lines(province_lines),'national':lines(country_lines)}
snapped=snap_ends(line_sets['provincial'],line_sets['national'])+snap_ends(line_sets['municipal'],line_sets['provincial']+line_sets['national'])
lakes_sha=hashlib.sha1(json.dumps(map_data['lakes'],separators=(',',':')).encode()).hexdigest()[:12]
output={'format_version':1,'generator':'tools/build_admin_boundaries.py','crs':'EPSG:4326','coord_order':'lon,lat',
 'geometry_format':'provinces[].polygons: outer rings only, clockwise, no holes (islands are separate rings; enclaves under %s deg2 are filled). lines.*: open or closed paths.'%MAX_HOLE,
 'lakes_sha':lakes_sha,'holes_filled':holes_filled,'line_ends_snapped':snapped,
 'source':'PDOK / Kadaster NL, BRK Bestuurlijke Gebieden','license':'CC BY 4.0','license_url':'https://creativecommons.org/licenses/by/4.0/','source_url':'https://api.pdok.nl/kadaster/brk-bestuurlijke-gebieden/ogc/v1','changes':'Shared edges noded and deduplicated, simplified; line ends snapped onto the coarser line they meet; province fills clipped to game land mask','retrieved':max(stamps),'source_updated':options.source_updated,'municipality_count':len(municipal),'province_count':len(provincial),'provinces':provinces,'lines':line_sets}
(ROOT/'data/boundaries_nl.json').write_text(json.dumps(output,ensure_ascii=False,separators=(',',':'))+'\n')
print({key:len(value) for key,value in output['lines'].items()},'provinces',len(provinces),'municipalities',len(municipal))
