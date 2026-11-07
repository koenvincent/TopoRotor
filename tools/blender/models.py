"""Build TopoRotor's aircraft airframes in Blender and export them as glTF.

Run headless from the repository root:

    blender --background --factory-startup --python tools/blender/models.py -- redder

Made with Blender 4.5.15 LTS (macOS arm64, sha256 checked against
download.blender.org). Without names it builds every airframe.

Each airframe is modelled from smooth lofted cross-sections with a
subdivision surface, so bodies, canopies and tail booms flow into each other
like a real scale model. Faces carry one of the game's paint slots as their
material name (body, tail, trim, rotor, gear, glass, accent); the game swaps
those for its own lacquer, so every colour scheme still works. Rotors stay
procedural in the game, because the rotor upgrade adds blades.

Positions are written in Godot coordinates (y up, nose towards -z) and
converted here, so they line up with the anchors in scripts/helicopter.gd.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

SLOTS = ["body", "tail", "trim", "rotor", "gear", "glass", "accent"]
OUT = Path(__file__).resolve().parents[2] / "assets" / "models"


def G(x, y, z):
    """Godot (x, y up, z back) to Blender (x, y forward, z up)."""
    return Vector((x, -z, y))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for slot in SLOTS:
        m = bpy.data.materials.new(slot)
        m.diffuse_color = (.8, .8, .8, 1)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def finish(obj, subdiv=2, smooth=True):
    if subdiv:
        mod = obj.modifiers.new("Subdivision", "SUBSURF")
        mod.levels = subdiv
        mod.render_levels = subdiv
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def add_slots(obj):
    for slot in SLOTS:
        obj.data.materials.append(bpy.data.materials[slot])


def ring(w, h, yc, z, n, segments, xc=0.0):
    """A superellipse cross-section: n=2 is an ellipse, higher is boxier."""
    pts = []
    for i in range(segments):
        t = 2 * math.pi * i / segments
        c, s = math.cos(t), math.sin(t)
        x = xc + w * .5 * math.copysign(abs(c) ** (2 / n), c)
        y = yc + h * .5 * math.copysign(abs(s) ** (2 / n), s)
        pts.append(G(x, y, z))
    return pts


def loft(name, sections, paint, segments=24, n=2.3, subdiv=2):
    """Skin cross-sections (z, width, height, centre_y[, centre_x]) into a
    closed body. paint is a slot name or a function of the face centre and
    normal.

    paint(centre, normal) picks the slot of each face from its position in
    Godot coordinates, so windows and stripes follow the body's shape.
    """
    mesh = bpy.data.meshes.new(name)
    obj = link(bpy.data.objects.new(name, mesh))
    add_slots(obj)
    bm = bmesh.new()
    rings = []
    if isinstance(paint, str):
        paint = (lambda slot: (lambda c, nrm: slot))(paint)
    for section in sections:
        z, w, h, yc = section[:4]
        xc = section[4] if len(section) > 4 else 0.0
        rings.append([bm.verts.new(p) for p in ring(w, h, yc, z, n, segments, xc)])
    for a, b in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for cap, reverse in ((rings[0], True), (rings[-1], False)):
        centre = sum((v.co for v in cap), Vector()) / len(cap)
        tip = bm.verts.new(centre)
        for i in range(segments):
            j = (i + 1) % segments
            face = (cap[j], cap[i], tip) if reverse else (cap[i], cap[j], tip)
            bm.faces.new(face)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for face in bm.faces:
        c = face.calc_center_median()
        nrm = face.normal
        godot_c = (c.x, c.z, -c.y)
        godot_n = (nrm.x, nrm.z, -nrm.y)
        face.material_index = SLOTS.index(paint(godot_c, godot_n))
    bm.to_mesh(mesh)
    bm.free()
    return finish(obj, subdiv)


def plate(name, outline, thickness, slot, x=0.0, axis="x", bevel=.04, lean=0.0, pivot=None, smooth=True):
    """A flat part from a 2D outline, extruded and bevelled: fins, wings.

    outline is a list of (a, b) points; for axis "x" they are (z, y) and the
    plate is thick across x, for axis "y" they are (x, z) and it lies flat.
    """
    mesh = bpy.data.meshes.new(name)
    obj = link(bpy.data.objects.new(name, mesh))
    add_slots(obj)
    bm = bmesh.new()
    front, back = [], []
    for a, b in outline:
        if axis == "x":
            front.append(bm.verts.new(G(x - thickness / 2, b, a)))
            back.append(bm.verts.new(G(x + thickness / 2, b, a)))
        else:
            front.append(bm.verts.new(G(a, x - thickness / 2, b)))
            back.append(bm.verts.new(G(a, x + thickness / 2, b)))
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    count = len(outline)
    for i in range(count):
        j = (i + 1) % count
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for face in bm.faces:
        c = face.calc_center_median()
        nrm = face.normal
        pick = slot if isinstance(slot, str) else slot((c.x, c.z, -c.y), (nrm.x, nrm.z, -nrm.y))
        face.material_index = SLOTS.index(pick)
    bm.to_mesh(mesh)
    bm.free()
    if lean:
        # Tilt about the Godot z axis through the pivot (fins leaning out).
        from mathutils import Matrix
        at = G(*pivot)
        obj.matrix_world = Matrix.Translation(at) @ Matrix.Rotation(-lean, 4, "Y") @ Matrix.Translation(-at)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = min(bevel, thickness * .45)
    mod.segments = 3
    mod.limit_method = "ANGLE"
    if smooth:
        obj.data.shade_smooth()
        obj.data.set_sharp_from_angle(angle=math.radians(35))
    return obj


def tube(name, points, radius, slot):
    """A round tube along a smooth curve through Godot-space points: skids."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 4
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for p, at in zip(spline.points, points):
        p.co = (*G(*at), 1)
    spline.type = "NURBS"
    spline.use_endpoint_u = True
    spline.order_u = 3
    spline.resolution_u = 12
    obj = link(bpy.data.objects.new(name, curve))
    obj.data.materials.append(bpy.data.materials[slot])
    return obj


def blob(name, at, size, slot, segments=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, location=G(*at))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0] / 2, size[2] / 2, size[1] / 2)
    obj.data.materials.append(bpy.data.materials[slot])
    obj.data.shade_smooth()
    return obj


def cylinder(name, a, b, radius, slot, r_end=None):
    a, b = G(*a), G(*b)
    depth = (b - a).length
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=radius, radius2=radius if r_end is None else r_end, depth=depth, location=(a + b) / 2)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    obj.data.materials.append(bpy.data.materials[slot])
    obj.data.shade_smooth()
    return obj


# --- Redder: a twin-engined rescue helicopter, a little like an EC135 ---

def redder_paint(c, n):
    x, y, z = c
    nx, ny, nz = n
    # Wrap-round windscreen at the front, two side windows per side.
    if z < -.55 and y > -.25 and ny > -.35:
        return "glass"
    if -.35 < z < .75 and .05 < y < .55 and abs(nx) > .6:
        return "glass"
    # A stripe along the lower body and the tail boom.
    if -.45 < y < -.25 and z < 1.2:
        return "trim"
    if z > 1.6:
        return "tail"
    return "body"


def build_redder():
    loft("Fuselage", [
        (-1.7, .18, .16, -.12),
        (-1.55, .7, .62, -.08),
        (-1.25, 1.35, 1.12, .02),
        (-.8, 1.72, 1.42, .1),
        (-.1, 1.86, 1.5, .14),
        (.55, 1.8, 1.44, .16),
        (1.05, 1.36, 1.1, .22),
        (1.45, .7, .62, .28),
        (1.9, .42, .42, .3),
        (2.8, .32, .36, .36),
        (3.65, .24, .3, .42),
        (3.95, .18, .24, .46),
    ], redder_paint)
    # Engine cowling on the roof with two exhaust humps.
    loft("Cowling", [
        (-.25, .3, .12, .66),
        (0.0, .9, .34, .78),
        (.7, .96, .4, .8),
        (1.35, .64, .3, .74),
        (1.7, .2, .1, .62),
    ], lambda c, n: "trim" if c[1] > .9 else "body", n=2.6)
    for side in (-1, 1):
        cylinder(f"Exhaust{side}", (side * .3, .86, 1.3), (side * .32, .9, 1.62), .1, "rotor", .085)
    # Fin with a swept leading edge and a stabiliser with end plates.
    plate("Fin", [(3.35, .35), (3.95, .32), (4.25, 1.55), (3.95, 1.6), (3.6, .9)], .12, "tail")
    plate("Stabiliser", [(-.9, 3.05), (.9, 3.05), (.85, 3.35), (-.85, 3.35)], .07, "trim", x=.32, axis="y")
    for side in (-1, 1):
        plate(f"EndPlate{side}", [(2.95, .1), (3.45, .1), (3.5, .6), (3.15, .62)], .05, "tail", x=side * .9)
    # Skids on curved cross tubes.
    for side in (-1, 1):
        x = side * 1.1
        tube(f"Skid{side}", [(x, -.86, 1.75), (x, -.9, .6), (x, -.9, -1.2), (x, -.82, -1.55), (x, -.62, -1.72)], .055, "gear")
        for lz in (-.7, .8):
            tube(f"Cross{side}{lz}", [(side * .55, -.55, lz), (side * .9, -.62, lz), (x, -.9, lz)], .05, "gear")
    # Mast fairing; the rotor itself is added by the game.
    cylinder("Mast", (0, .95, .12), (0, 1.38, .12), .1, "rotor", .07)
    # Rescue details: hoist arm, searchlight pod, nose sensor.
    blob("Searchlight", (.45, -.62, -1.0), (.24, .2, .3), "trim")
    blob("Hoist", (.98, .55, -.15), (.22, .22, .62), "trim")
    for side in (-1, 1):
        blob(f"Step{side}", (side * .96, -.55, .0), (.12, .06, .9), "gear")



# --- Shared parts ---

def skid_set(x, y, z, length, leg_z, leg_top):
    """Skids with an upturned nose on curved cross tubes (as in the game)."""
    for side in (-1, 1):
        sx = side * x
        tube(f"Skid{side}", [(sx, y + .04, z + length * .5), (sx, y, z + length * .2), (sx, y, z - length * .35),
                             (sx, y + .08, z - length * .47), (sx, y + .28, z - length * .52)], .055, "gear")
        for lz in leg_z:
            tube(f"Cross{side}{lz}", [(side * (x - .5), leg_top, lz), (side * (x - .1), (leg_top + y) * .5, lz), (sx, y, lz)], .05, "gear")


def wheel(name, at, radius, width=None):
    width = width or radius * .7
    x, y, z = at
    cylinder(name, (x - width / 2, y, z), (x + width / 2, y, z), radius, "gear")
    cylinder(name + "Hub", (x - width * .55, y, z), (x + width * .55, y, z), radius * .45, "trim")


def strut(name, a, b, radius=.04, slot="gear"):
    cylinder(name, a, b, radius, slot)


def cabin_glass(front_z, low_y, side_from, side_to, win_low, win_high, side_nx=.6):
    """A paint function: wrap-round windscreen ahead of front_z, side windows
    between side_from and side_to; returns None for faces that are not glass."""
    def pick(c, n):
        x, y, z = c
        if z < front_z and y > low_y and n[1] > -.35:
            return "glass"
        if side_from < z < side_to and win_low < y < win_high and abs(n[0]) > side_nx:
            return "glass"
        return None
    return pick


def painted(glass, stripe=None, tail_from=99.0, nose_to=-99.0, nose_slot="trim"):
    def pick(c, n):
        g = glass(c, n) if glass else None
        if g:
            return g
        if z_of(c) < nose_to:
            return nose_slot
        if stripe and stripe[0] < c[1] < stripe[1] and z_of(c) < tail_from:
            return "trim"
        if z_of(c) > tail_from:
            return "tail"
        return "body"
    return pick


def z_of(c):
    return c[2]


# --- Helicopters ---

def build_libel():
    blob("Bubble", (0, .22, -.4), (1.5, 1.35, 1.6), "glass")
    loft("Fuselage", [(-1.1, .3, .2, -.42), (-.85, 1.2, .6, -.36), (-.3, 1.5, .8, -.3), (.35, 1.45, .9, -.18),
                      (.85, 1.0, .9, .08), (1.25, .55, .55, .3), (1.6, .24, .24, .4), (4.25, .13, .13, .62), (4.45, .09, .09, .64)],
         painted(None, stripe=(-.12, .0), tail_from=1.5))
    blob("Engine", (0, .32, .85), (.72, .62, .8), "rotor")
    cylinder("Mast", (0, .55, .4), (0, 1.42, .4), .07, "rotor", .05)
    plate("Fin", [(4.12, .5), (4.5, .5), (4.62, 1.28), (4.42, 1.3)], .08, "tail")
    plate("Ventral", [(4.2, .4), (4.5, .4), (4.55, .02), (4.38, .0)], .07, "tail")
    plate("Stabiliser", [(-.55, 4.05), (.55, 4.05), (.5, 4.35), (-.5, 4.35)], .06, "trim", x=.32, axis="y")
    skid_set(.85, -.95, .1, 2.8, [-.5, .6], -.4)


def build_molen():
    loft("Pod", [(-1.38, .2, .2, -.12), (-1.1, .8, .8, -.06), (-.55, 1.15, 1.15, 0), (.15, 1.05, 1.05, .04), (.55, .72, .72, .14), (.8, .34, .34, .2)],
         lambda c, n: "glass" if (c[2] < -.35 and c[1] > .12 and n[1] > -.2) else ("trim" if -.08 < c[1] < .02 else "body"))
    blob("Engine", (0, .2, .75), (.62, .58, .62), "rotor")
    cylinder("Mast", (0, .4, .1), (0, 1.7, .2), .07, "rotor", .05)
    tube("Keel", [(0, -.32, .3), (0, -.22, 1.6), (0, -.15, 3.25)], .06, "tail")
    plate("Fin", [(2.95, .0), (3.45, .0), (3.55, .95), (3.15, .95)], .08, "tail")
    plate("Stabiliser", [(-.65, 2.95), (.65, 2.95), (.62, 3.27), (-.62, 3.27)], .06, "trim", x=-.1, axis="y")
    for side in (-1, 1):
        plate(f"SideFin{side}", [(2.95, -.05), (3.3, -.05), (3.35, .55), (3.05, .55)], .06, "tail", x=side * .65)
        strut(f"Leg{side}", (side * .3, -.38, 0), (side * .65, -.72, 0), .05)
        wheel(f"Wheel{side}", (side * .65, -.72, 0), .22)
    strut("NoseLeg", (0, -.5, -.95), (0, -.78, -1.05), .04)
    wheel("NoseWheel", (0, -.78, -1.05), .16)


def build_pijl():
    loft("Fuselage", [(-1.6, .22, .18, -.18), (-1.4, .9, .7, -.06), (-.95, 1.45, 1.1, .04), (-.25, 1.7, 1.32, .1), (.55, 1.66, 1.3, .15),
                      (1.15, 1.12, .92, .24), (1.6, .56, .52, .26), (2.3, .46, .44, .28), (3.7, .34, .34, .34), (4.05, .3, .42, .46)],
         painted(cabin_glass(-.55, -.22, -.3, .55, .05, .5), stripe=(-.42, -.24), tail_from=1.5))
    loft("Cowling", [(-.3, .3, .1, .58), (0, .92, .32, .7), (.85, .96, .38, .72), (1.45, .6, .26, .66), (1.8, .2, .1, .56)], "trim", n=2.6)
    bpy.ops.mesh.primitive_torus_add(major_radius=.56, minor_radius=.15, major_segments=40, minor_segments=12, location=G(0, .75, 4.4))
    duct = bpy.context.active_object
    duct.name = "Fenestron"
    duct.rotation_euler = (0, math.radians(90), 0)
    duct.scale = (1.0, 1.0, .9)
    duct.data.materials.append(bpy.data.materials["tail"])
    duct.data.shade_smooth()
    plate("Fin", [(4.25, 1.2), (4.85, 1.2), (5.0, 1.95), (4.68, 1.95)], .12, "tail")
    plate("Stabiliser", [(-.8, 3.68), (.8, 3.68), (.76, 4.0), (-.76, 4.0)], .07, "trim", x=.32, axis="y")
    for side in (-1, 1):
        plate(f"EndPlate{side}", [(3.65, .15), (4.05, .15), (4.08, .72), (3.8, .74)], .05, "tail", x=side * .8)
    cylinder("Mast", (0, .85, .3), (0, 1.32, .3), .09, "rotor", .07)
    skid_set(1.0, -.95, .1, 3.0, [-.6, .7], -.45)


def window_row(start, step, length, low, high):
    def pick(c, n):
        z = c[2]
        if start < z < start + step * 5 and low < c[1] < high and abs(n[0]) > .7 and (z - start) % step < length:
            return "glass"
        return None
    return pick


def build_tandem():
    windows = window_row(-2.25, .9, .45, .18, .52)
    def paint(c, n):
        if c[2] < -3.25 and c[1] > -.12 and n[1] > -.4:
            return "glass"
        return windows(c, n) or ("trim" if -.62 < c[1] < -.45 else "body")
    loft("Fuselage", [(-3.98, .4, .38, -.22), (-3.78, 1.25, 1.0, -.12), (-3.4, 1.72, 1.5, 0), (-2.8, 1.8, 1.7, 0), (2.7, 1.8, 1.7, 0),
                      (3.25, 1.62, 1.5, .1), (3.55, 1.15, .95, .32), (3.68, .4, .3, .45)], paint, n=3.2)
    loft("RearPylon", [(1.9, .5, .3, .85), (2.3, 1.0, 1.0, 1.2), (3.4, 1.0, 1.3, 1.35), (3.72, .6, .8, 1.4), (3.86, .2, .3, 1.42)], "tail", n=2.8)
    loft("FrontPylon", [(-3.1, .2, .1, .82), (-2.85, .62, .3, .9), (-2.3, .66, .34, .95), (-1.9, .3, .14, .88)], "trim", n=2.8)
    loft("Spine", [(-2.2, .3, .1, .84), (-1.8, .56, .3, .9), (1.8, .56, .3, .95), (2.1, .3, .1, .9)], "trim", n=2.8)
    for side in (-1, 1):
        x = side * 1.0
        loft(f"Sponson{side}", [(-1.6, .1, .1, -.55, x), (-1.3, .42, .5, -.55, x), (2.0, .42, .5, -.55, x), (2.3, .1, .1, -.5, x)], "trim", n=2.8)
        blob(f"Engine{side}", (side * .7, 1.3, 2.6), (.45, .45, 1.4), "rotor")
        for wz in (-2.2, 2.0):
            strut(f"Strut{side}{wz}", (x, -.7, wz), (x, -1.0, wz), .06)
            wheel(f"Wheel{side}{wz}", (x, -1.05, wz), .28, .18)
    cylinder("MastFront", (0, 1.15, -2.6), (0, 1.35, -2.6), .1, "rotor")
    cylinder("MastRear", (0, 1.9, 2.9), (0, 2.0, 2.9), .1, "rotor")


def build_wesp():
    loft("Fuselage", [(-1.78, .14, .14, -.22), (-1.5, .6, .7, -.12), (-1.0, .9, 1.05, -.02), (-.2, 1.0, 1.3, .06), (.6, .96, 1.2, .1),
                      (1.2, .62, .72, .15), (1.6, .42, .44, .18), (2.3, .36, .36, .2), (4.15, .18, .2, .33), (4.32, .12, .14, .34)],
         painted(None, stripe=(-.3, -.2), tail_from=1.5))
    blob("FrontCanopy", (0, .42, -.95), (.72, .6, 1.05), "glass")
    blob("RearCanopy", (0, .62, -.15), (.74, .66, 1.0), "glass")
    blob("CanopyFrame", (0, .66, -.58), (.76, .1, .14), "rotor")
    for side in (-1, 1):
        x = side * .55
        loft(f"Engine{side}", [(-.2, .1, .1, .55, x), (0, .42, .42, .55, x), (1.0, .46, .46, .55, x), (1.25, .3, .3, .55, x)], "rotor")
        plate(f"Wing{side}", [(side * .4, -.1), (side * 1.55, 0.0), (side * 1.55, .45), (side * .4, .5)], .09, "body", x=0.0, axis="y")
        cylinder(f"Pod{side}", (side * 1.25, -.25, -.3), (side * 1.25, -.25, .7), .14, "trim")
        blob(f"PodNose{side}", (side * 1.25, -.25, -.3), (.26, .26, .22), "rotor")
        strut(f"Pylon{side}", (side * 1.25, -.08, .2), (side * 1.25, -.02, .2), .05, "body")
        strut(f"Leg{side}", (side * .45, -.45, -.6), (side * .62, -.92, -.6), .05)
        wheel(f"Wheel{side}", (side * .62, -.92, -.6), .2)
    blob("Turret", (0, -.6, -1.1), (.32, .26, .32), "rotor")
    cylinder("Gun", (0, -.65, -1.2), (0, -.65, -1.85), .04, "rotor")
    plate("Fin", [(3.8, .3), (4.4, .3), (4.55, 1.45), (4.25, 1.45)], .11, "tail")
    plate("Stabiliser", [(-.8, 3.72), (.8, 3.72), (.75, 4.05), (-.75, 4.05)], .07, "trim", x=.3, axis="y")
    strut("TailLeg", (0, .1, 3.9), (0, -.2, 3.9), .04)
    wheel("TailWheel", (0, -.2, 3.9), .12)
    cylinder("Mast", (0, .85, 0), (0, 1.15, 0), .08, "rotor")


def build_kraan():
    loft("Fuselage", [(-2.48, .3, .3, .12), (-2.25, 1.0, .95, .2), (-1.8, 1.4, 1.3, .2), (-1.2, 1.3, 1.2, .3), (-.8, .8, .78, .5),
                      (-.4, .72, .62, .55), (1.9, .72, .62, .6), (2.4, .42, .42, .65), (4.7, .2, .22, .78), (4.95, .14, .16, .8)],
         painted(cabin_glass(-1.75, .02, -1.7, -1.05, .25, .6), stripe=(.48, .58), tail_from=2.2))
    loft("Engines", [(-.4, .3, .1, .88), (-.2, 1.12, .46, 1.0), (1.2, 1.12, .46, 1.02), (1.45, .5, .2, .95)], "trim", n=2.6)
    plate("Fin", [(4.45, .7), (5.0, .72), (5.15, 2.0), (4.85, 2.0)], .12, "tail")
    plate("Stabiliser", [(-.7, 4.45), (.7, 4.45), (.65, 4.75), (-.65, 4.75)], .07, "trim", x=.9, axis="y")
    for side in (-1, 1):
        strut(f"FrontLeg{side}", (side * .55, .1, -1.3), (side * 1.1, -1.35, -1.3), .06)
        strut(f"RearLeg{side}", (side * .4, .45, 1.4), (side * 1.5, -1.4, 1.4), .07)
        strut(f"Brace{side}", (side * .45, .3, -1.1), (side * 1.3, -.9, 1.2), .04)
        wheel(f"FrontWheel{side}", (side * 1.1, -1.35, -1.3), .2, .14)
        wheel(f"RearWheel{side}", (side * 1.5, -1.4, 1.4), .24, .16)
    cylinder("Mast", (0, 1.15, .4), (0, 1.55, .4), .09, "rotor")


def build_coax():
    def paint(c, n):
        if c[2] < -1.25 and c[1] > -.15 and n[1] > -.35:
            return "glass"
        if .1 < c[1] < .42 and abs(n[0]) > .7 and (-.75 < c[2] < -.3 or -.05 < c[2] < .4):
            return "glass"
        if c[2] > 1.5:
            return "tail"
        return "trim" if -.48 < c[1] < -.32 else "body"
    loft("Fuselage", [(-1.98, .3, .3, -.12), (-1.75, 1.1, .95, -.06), (-1.35, 1.55, 1.35, 0), (-.8, 1.62, 1.5, 0), (.9, 1.62, 1.5, 0),
                      (1.35, 1.2, 1.1, .1), (1.8, .5, .5, .15), (3.6, .26, .26, .24), (3.82, .18, .18, .25)], paint, n=2.8)
    loft("Engine", [(-.4, .4, .15, .78), (-.1, 1.0, .46, .92), (.9, 1.0, .46, .95), (1.3, .4, .2, .85)], "rotor", n=2.6)
    plate("Stabiliser", [(-1.0, 3.35), (1.0, 3.35), (.98, 3.85), (-.98, 3.85)], .08, "trim", x=.25, axis="y")
    for side in (-1, 1):
        plate(f"Fin{side}", [(3.3, .2), (3.85, .2), (3.95, 1.05), (3.5, 1.08)], .08, "tail", x=side * 1.0)
        for wz in (-.9, .8):
            strut(f"Leg{side}{wz}", (side * .62, -.65, wz), (side * .78, -.95, wz), .05)
            wheel(f"Wheel{side}{wz}", (side * .78, -.95, wz), .2)
    cylinder("Mast", (0, .95, 0), (0, 1.9, 0), .09, "rotor")
    cylinder("Hub", (0, 1.42, 0), (0, 1.58, 0), .16, "trim")


# --- Aeroplanes ---

def wing(name, y, span, root, tip, z_lead, slot="body", thick=.14, tip_slot="trim", sweep=0.0):
    """A tapered wing with rounded tips and painted tip caps."""
    half = span / 2
    lead_tip = z_lead + sweep + (root - tip) * .3
    outline = [(-half, lead_tip), (-half * .4, z_lead), (half * .4, z_lead), (half, lead_tip), (half + .08, lead_tip + tip * .5),
               (half, lead_tip + tip), (half * .4, z_lead + root), (-half * .4, z_lead + root), (-half, lead_tip + tip), (-half - .08, lead_tip + tip * .5)]
    plate(name, outline, thick, lambda c, n: tip_slot if abs(c[0]) > half - .45 else slot, x=y, axis="y", bevel=thick * .45)


def plane_fuselage(paint):
    loft("Fuselage", [(-2.15, .42, .42, -.12), (-1.9, .9, .9, -.1), (-1.4, 1.1, 1.15, -.02), (-.6, 1.2, 1.3, .05), (.4, 1.02, 1.02, .1),
                      (1.4, .64, .64, .15), (3.2, .25, .3, .25), (3.45, .12, .16, .28)], paint)


def plane_paint(c, n):
    x, y, z = c
    if z < -1.35:
        return "trim"
    if -1.2 < z < 0 and y > .3 and n[1] > -.2:
        return "glass"
    if -1.1 < z < -.1 and .1 < y < .55 and abs(n[0]) > .6:
        return "glass"
    if -.28 < y < -.12 and z < 2.6:
        return "trim"
    return "tail" if z > 2.4 else "body"


def plane_common(floats):
    plane_fuselage(plane_paint)
    wing("Wing", .78, 9.0, 1.3, 1.1, -1.05)
    plate("Stabiliser", [(-1.5, 2.75), (1.5, 2.75), (1.42, 3.45), (-1.42, 3.45)], .08, "tail", x=.2, axis="y")
    plate("Fin", [(2.55, .3), (3.5, .3), (3.62, 1.45), (3.2, 1.45)], .08, "tail")
    blob("Spinner", (0, -.1, -2.2), (.3, .3, .34), "trim")
    for side in (-1, 1):
        strut(f"WingStrut{side}", (side * .55, -.15, -.45), (side * 2.0, .72, -.4), .045)
        if not floats:
            strut(f"Leg{side}", (side * .4, -.4, -.3), (side * .8, -.9, -.3), .05)
            wheel(f"Wheel{side}", (side * .8, -.9, -.3), .25)
            blob(f"Spat{side}", (side * .8, -.82, -.3), (.2, .3, .6), "body")
    if not floats:
        strut("NoseLeg", (0, -.45, -1.6), (0, -.95, -1.6), .045)
        wheel("NoseWheel", (0, -.95, -1.6), .18)


def build_sport():
    plane_common(False)


def build_zee():
    plane_common(True)
    for side in (-1, 1):
        x = side * .95
        loft(f"Float{side}", [(-2.15, .08, .08, -1.22, x), (-1.8, .45, .42, -1.2, x), (-.5, .6, .55, -1.25, x), (1.0, .5, .45, -1.27, x), (1.7, .1, .1, -1.24, x)], "trim", n=2.6)
        for fz in (-1.2, .4):
            strut(f"FloatStrut{side}{fz}", (side * .45, -.3, fz), (x, -1.0, fz), .045)
        strut(f"TipStrut{side}", (side * 4.1, .72, -.4), (side * 4.1, .22, -.4), .04)
        blob(f"TipFloat{side}", (side * 4.1, .12, -.4), (.26, .22, .72), "trim")


def build_dubbel():
    loft("Fuselage", [(-2.62, 1.06, 1.06, 0), (-2.1, 1.1, 1.1, 0), (-1.0, 1.06, 1.06, .02), (.5, .96, .96, .05), (2.0, .62, .64, .12), (3.3, .26, .3, .2), (3.5, .12, .14, .22)],
         lambda c, n: "rotor" if (-.15 < c[2] < .6 and c[1] > .42 and n[1] > .3) else ("trim" if c[2] < -1.95 else ("tail" if c[2] > 2.5 else "body")), n=2.8)
    cylinder("Cowl", (0, 0, -2.75), (0, 0, -2.2), .58, "trim", .55)
    blob("Spinner", (0, 0, -2.72), (.32, .32, .34), "rotor")
    wing("UpperWing", 1.15, 8.0, 1.2, 1.1, -1.2, thick=.12)
    wing("LowerWing", -.45, 7.4, 1.1, 1.0, -.95, thick=.12)
    blob("Windscreen", (0, .66, -.2), (.5, .26, .06), "glass")
    plate("Stabiliser", [(-1.3, 2.78), (1.3, 2.78), (1.22, 3.45), (-1.22, 3.45)], .07, "tail", x=.1, axis="y")
    plate("Fin", [(2.75, .35), (3.5, .35), (3.6, 1.15), (3.2, 1.2)], .07, "tail")
    for side in (-1, 1):
        for x in (1.1, 3.0):
            strut(f"Strut{side}{x}a", (side * x, -.4, -.75), (side * x, 1.1, -.75), .04, "trim")
            strut(f"Strut{side}{x}b", (side * x, -.4, -.2), (side * x, 1.1, -.2), .04, "trim")
        strut(f"Wire{side}", (side * 1.1, 1.1, -.5), (side * 3.0, -.4, -.5), .012, "rotor")
        strut(f"Wire2{side}", (side * 1.1, -.4, -.5), (side * 3.0, 1.1, -.5), .012, "rotor")
        strut(f"Cabane{side}", (side * .3, .45, -.6), (side * .35, 1.1, -.6), .04, "trim")
        strut(f"Leg{side}", (side * .3, -.45, -1.0), (side * .72, -1.05, -1.0), .05)
        wheel(f"Wheel{side}", (side * .72, -1.05, -1.0), .3, .14)
    strut("Axle", (-.72, -1.05, -1.0), (.72, -1.05, -1.0), .03)
    strut("TailSkid", (0, -.2, 3.0), (0, -.45, 3.15), .03)


def build_dakota():
    def paint(c, n):
        if c[2] < -3.3 and c[1] > .12 and n[1] > -.2:
            return "glass"
        if -2.15 < c[2] < 1.4 and .14 < c[1] < .4 and abs(n[0]) > .7 and (c[2] + 2.15) % .65 < .32:
            return "glass"
        if -.22 < c[1] < -.06:
            return "trim"
        return "tail" if c[2] > 3.0 else "body"
    loft("Fuselage", [(-4.08, .3, .3, -.06), (-3.86, .9, .95, 0), (-3.4, 1.36, 1.45, .02), (-2.6, 1.5, 1.6, .02), (1.2, 1.5, 1.6, .05),
                      (2.4, 1.15, 1.25, .16), (3.6, .62, .72, .33), (4.4, .26, .36, .42), (4.62, .12, .15, .43)], paint)
    wing("Wing", -.45, 11.0, 1.7, 1.0, -1.65, thick=.18)
    plate("Stabiliser", [(-1.9, 3.5), (1.9, 3.6), (1.8, 4.3), (-1.8, 4.3)], .09, "tail", x=.4, axis="y")
    plate("Fin", [(3.0, .55), (4.35, .5), (4.55, 2.0), (4.2, 2.15), (3.8, 1.6)], .1, "tail")
    for side in (-1, 1):
        x = side * 2.2
        loft(f"Nacelle{side}", [(-2.42, .3, .3, -.3, x), (-2.25, .72, .72, -.3, x), (-1.0, .74, .74, -.34, x), (-.3, .42, .42, -.4, x), (0, .14, .14, -.42, x)], "trim")
        blob(f"Spinner{side}", (x, -.3, -2.42), (.3, .3, .3), "rotor")
        strut(f"Leg{side}", (x, -.55, -1.1), (x, -1.1, -1.1), .07)
        wheel(f"Wheel{side}", (x, -1.1, -1.1), .35, .2)
    strut("TailLeg", (0, -.05, 3.8), (0, -.32, 3.8), .04)
    wheel("TailWheel", (0, -.32, 3.8), .15)


# --- Jets ---

def jet_fuselage(length, radius, tail_from):
    nose = .2 - length * .5 - 1.2
    end = .2 + length * .5 + .4
    loft("Fuselage", [(nose, .03, .03, 0), (nose + .55, radius * .8, radius * .8, -.02), (nose + 1.3, radius * 1.8, radius * 1.7, 0),
                      (nose + 2.6, radius * 2.05, radius * 2.0, .04), (0, radius * 2.1, radius * 2.0, 0), (end - 1.2, radius * 2.0, radius * 1.95, 0),
                      (end - .3, radius * 1.75, radius * 1.75, 0), (end, radius * 1.6, radius * 1.6, 0)],
         lambda c, n: "rotor" if c[2] > end - .35 else ("tail" if c[2] > tail_from else "body"))
    blob("Canopy", (0, radius * .95, -length * .3), (.6, .55, 1.6), "glass")
    for side in (-1, 1):
        strut(f"Leg{side}", (side * .4, -.3, .3), (side * .6, -.8, .3), .05)
        wheel(f"Wheel{side}", (side * .6, -.8, .3), .18)
    strut("NoseLeg", (0, -.35, -length * .32), (0, -.82, -length * .32), .04)
    wheel("NoseWheel", (0, -.82, -length * .32), .14)


def build_valk():
    jet_fuselage(6.4, .45, 2.0)
    loft("Intake", [(-1.5, .5, .2, -.45), (-1.25, .66, .46, -.5), (.4, .62, .42, -.42), (.85, .3, .2, -.3)], "rotor", n=2.8)
    for side in (-1, 1):
        plate(f"Wing{side}", [(side * .4, -.75), (side * 3.0, 1.05), (side * 3.05, 1.75), (side * .4, 1.95)], .12, "body", x=-.05, axis="y")
        plate(f"Tailplane{side}", [(side * .35, 2.4), (side * 1.6, 3.3), (side * 1.62, 3.62), (side * .35, 3.68)], .09, "tail", x=0.0, axis="y")
        cylinder(f"Missile{side}", (side * 3.08, -.05, .5), (side * 3.08, -.05, 2.3), .06, "trim")
        blob(f"Seeker{side}", (side * 3.08, -.05, .5), (.12, .12, .3), "accent")
    plate("Fin", [(1.8, .35), (3.4, .35), (3.6, 2.05), (3.05, 2.05)], .1, "tail")


def build_delta():
    jet_fuselage(6.0, .45, 2.0)
    plate("Wing", [(0, -.95), (3.2, 3.15), (3.15, 3.32), (-3.15, 3.32), (-3.2, 3.15)], .12,
          lambda c, n: "trim" if (c[1] > 0 and abs(c[0]) < 2.2 - (3.3 - c[2]) * .55 and c[2] > 1.6) else "body", x=-.05, axis="y")
    plate("Canards", [(0, -1.6), (1.1, -.75), (1.05, -.65), (-1.05, -.65), (-1.1, -.75)], .06, "trim", x=.08, axis="y")
    for side in (-1, 1):
        loft(f"Intake{side}", [(-1.4, .1, .2, -.05, side * .55), (-1.2, .3, .5, -.05, side * .55), (.2, .3, .5, -.05, side * .5), (.5, .1, .2, -.05, side * .45)], "rotor", n=3)
    plate("Fin", [(1.4, .35), (3.3, .35), (3.45, 1.9), (2.8, 1.9)], .1, "tail")


def build_schaduw():
    plate("Wing", [(0, -2.15), (3.5, 3.35), (2.4, 2.9), (1.2, 3.35), (0, 2.9), (-1.2, 3.35), (-2.4, 2.9), (-3.5, 3.35)], .2,
          lambda c, n: "trim" if c[2] > 2.6 else "body", x=0.0, axis="y", bevel=.03, smooth=False)
    loft("Hump", [(-2.0, .2, .1, .1), (-1.2, 1.4, .45, .18), (.5, 2.2, .5, .2), (2.2, 1.6, .35, .15), (2.9, .8, .18, .1)], "body", n=1.7, subdiv=1)
    blob("Canopy", (0, .42, -.9), (.55, .3, 1.3), "glass")
    for side in (-1, 1):
        plate(f"Fin{side}", [(1.85, .25), (2.95, .25), (3.15, 1.25), (2.6, 1.25)], .08, "tail", x=side * .75, lean=side * .5, pivot=(side * .75, .25, 2.4))
        cylinder(f"Exhaust{side}", (side * .5, .12, 2.7), (side * .5, .12, 3.0), .14, "rotor", .12)
        strut(f"Leg{side}", (side * .9, -.1, .6), (side * .9, -.48, .6), .04)
        wheel(f"Wheel{side}", (side * .9, -.48, .6), .18)
    strut("NoseLeg", (0, -.1, -1.2), (0, -.5, -1.2), .035)
    wheel("NoseWheel", (0, -.5, -1.2), .14)


BUILDERS = {"redder": build_redder, "libel": build_libel, "molen": build_molen, "pijl": build_pijl, "tandem": build_tandem,
            "wesp": build_wesp, "kraan": build_kraan, "coax": build_coax, "sport": build_sport, "zee": build_zee,
            "dubbel": build_dubbel, "dakota": build_dakota, "valk": build_valk, "delta": build_delta, "schaduw": build_schaduw}



def export(name):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_apply=True,
                              export_yup=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False)
    print("exported", path)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(BUILDERS)
    for name in args:
        reset()
        BUILDERS[name]()
        # Curves become meshes so the exporter applies their bevel.
        for obj in list(bpy.context.scene.objects):
            if obj.type == "CURVE":
                bpy.context.view_layer.objects.active = obj
                obj.select_set(True)
        if any(o.type == "CURVE" for o in bpy.context.scene.objects):
            bpy.ops.object.convert(target="MESH")
        export(name)


main()
