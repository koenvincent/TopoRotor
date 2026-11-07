"""Bundle simplified PDOK/Kadaster boundaries for offline game/minimap use.

uv run --with shapely python tools/build_admin_boundaries.py work/admin-source
Source GeoJSON collections: gemeentegebied, provinciegebied, landgebied.
CC BY 4.0, Kadaster NL. Shared edges are noded/deduplicated before simplification.
"""
import json,sys
from pathlib import Path
from shapely.geometry import Polygon,LineString,shape
from shapely.ops import split,unary_union,linemerge
ROOT=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1])
def features(name):return json.loads((source/(name+'.geojson')).read_text())['features']
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
 pending=[geometry];result=[]
 while pending:
  polygon=pending.pop()
  if polygon.is_empty:continue
  if polygon.geom_type in ['MultiPolygon','GeometryCollection']:
   pending.extend(p for p in polygon.geoms if p.geom_type in ['Polygon','MultiPolygon']);continue
  if polygon.geom_type!='Polygon' or polygon.area<.000015:continue
  if polygon.interiors:
   point=Polygon(polygon.interiors[0]).representative_point()
   pieces=split(polygon,LineString([(-25,point.y),(45,point.y)]))
   if len(pieces.geoms)<2:raise ValueError('Could not split interior ring')
   pending.extend(pieces.geoms)
  else:
   simple=polygon.simplify(.0008,preserve_topology=True)
   result.append([[round(x,6),round(y,6)] for x,y in simple.exterior.coords])
 return result
provinces=[]
for feature in sorted(provincial,key=lambda f:f['properties']['code']):
 p=feature['properties'];geometry=shape(feature['geometry'])
 provinces.append({'code':p['code'],'name':p['naam'],'polygons':rings(geometry.intersection(land))})
output={'source':'PDOK / Kadaster NL, BRK Bestuurlijke Gebieden','license':'CC BY 4.0','license_url':'https://creativecommons.org/licenses/by/4.0/','source_url':'https://api.pdok.nl/kadaster/brk-bestuurlijke-gebieden/ogc/v1','changes':'Shared edges deduplicated, simplified; province fills clipped to game land mask','retrieved':'2026-11-07','source_updated':'2026-01-28','municipality_count':len(municipal),'province_count':len(provincial),'provinces':provinces,'lines':{'municipal':lines(municipal_lines),'provincial':lines(province_lines),'national':lines(country_lines)}}
(ROOT/'data/boundaries_nl.json').write_text(json.dumps(output,ensure_ascii=False,separators=(',',':'))+'\n')
print({key:len(value) for key,value in output['lines'].items()},'provinces',len(provinces),'municipalities',len(municipal))
