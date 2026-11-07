class_name CompassWords
extends RefCounted

# Eight-wind names in the words Dutch school topography uses (N, O, Z, W).
# Index 0 is north, counting clockwise in steps of 45 degrees.
const SHORT = ["N","NO","O","ZO","Z","ZW","W","NW"]
const AREA = ["noorden","noordoosten","oosten","zuidoosten","zuiden","zuidwesten","westen","noordwesten"]
const HEADING = ["noord","noordoost","oost","zuidoost","zuid","zuidwest","west","noordwest"]

# Map or world delta with x to the east and y to the south (Godot's z).
static func index_for_map_delta(delta: Vector2) -> int:
	return posmod(int(round(rad_to_deg(atan2(delta.x,-delta.y))/45.0)),8)

# Direction between two (lon, lat) points, with longitude shrunk by latitude
# so east-west distances are not overstated.
static func index_between(from: Vector2,to: Vector2) -> int:
	var shrink=cos(deg_to_rad((from.y+to.y)*.5))
	return index_for_map_delta(Vector2((to.x-from.x)*shrink,-(to.y-from.y)))

static func km_between(from: Vector2,to: Vector2) -> float:
	var shrink=cos(deg_to_rad((from.y+to.y)*.5))
	return Vector2((to.x-from.x)*shrink,to.y-from.y).length()*111.195

# Screen direction of a compass index on a north-up map (y points down).
static func map_direction(index: int) -> Vector2:
	var angle=deg_to_rad(index*45.0)
	return Vector2(sin(angle),-cos(angle))
