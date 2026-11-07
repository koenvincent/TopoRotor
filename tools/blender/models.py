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
    """Skin cross-sections (z, width, height, centre_y) into a closed body.

    paint(centre, normal) picks the slot of each face from its position in
    Godot coordinates, so windows and stripes follow the body's shape.
    """
    mesh = bpy.data.meshes.new(name)
    obj = link(bpy.data.objects.new(name, mesh))
    add_slots(obj)
    bm = bmesh.new()
    rings = []
    for z, w, h, yc in sections:
        rings.append([bm.verts.new(p) for p in ring(w, h, yc, z, n, segments)])
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


def plate(name, outline, thickness, slot, x=0.0, axis="x", bevel=.04):
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
        face.material_index = SLOTS.index(slot)
    bm.to_mesh(mesh)
    bm.free()
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = min(bevel, thickness * .45)
    mod.segments = 3
    mod.limit_method = "ANGLE"
    for poly in obj.data.polygons:
        poly.use_smooth = True
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


BUILDERS = {"redder": build_redder}


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
