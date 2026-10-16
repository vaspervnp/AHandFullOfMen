"""Blender pre-render pipeline for A Handful of Men.

Run headless:
    blender -b --factory-startup --python tools/blender/hfm_render.py -- <out_dir> <blend_dir> [subject ...]

Every subject (operatives, German sentry, radio tower, props, portraits,
title banner) lives in <blend_dir>/<subject>.blend. If the file exists it
is opened and rendered as it is, so the scenes can be edited in Blender;
if not, the low-poly model is built here once and saved there. Characters
are then posed by object name (root, body, hipL/R, shL/R, head) and every
frame the game needs is rendered with an orthographic camera. Workbench + flat lighting + no anti-aliasing means
each material renders as one exact colour; the colours are the CPC game
palette, so tools/renders2sheet.py can map pixels back to pens 1:1.

Anamorphic compensation: a 12x16 Mode 0 sprite covers 24x16 square units
on screen (Mode 0 pixels are 2:1), so characters render at 96x64 and are
reduced by 8x4 blocks to 12x16.

Output: <out_dir>/<subject>/<frame>.png
"""
import math
import os
import sys

import bpy
from mathutils import Vector

# Game palette (tools/cpcpal.py GAME_PENS), sRGB 0..255
PAL = {
    "black": (0, 0, 0), "white": (255, 255, 255), "snowsh": (128, 255, 255),
    "sky": (0, 128, 255), "blue": (0, 0, 128), "grey": (128, 128, 128),
    "green": (0, 128, 0), "teal": (0, 128, 128), "red": (128, 0, 0),
    "orange": (255, 128, 0), "skin": (255, 128, 128), "olive": (128, 128, 0),
    "bred": (255, 0, 0), "byel": (255, 255, 0), "bblue": (0, 0, 255),
    "pyel": (255, 255, 128),
}

DIRS = {"N": 180, "NE": 135, "E": 90, "SE": 45, "S": 0}   # model yaw (deg), camera looks north
CAM_ELEVATION = 40          # degrees above the horizon
CHAR_RES = (96, 64)         # 12x16 Mode 0 sprite * (8, 4)
TOWER_RES = (128, 128)      # 16x32 Mode 0 stamp * (8, 4)
UNIT = 2.8 / 24             # Blender units per visual unit (character framing)
SUBJECTS = ["beret", "marine", "sniper", "guard", "tower", "pine", "rock", "barrel",
            "explosion", "truck", "portraits", "banner"]

LOOKS = {
    "beret":  dict(uniform="green", shade="teal", hat="beret", hatc="teal", pack="olive", gun="grey"),
    "marine": dict(uniform="sky", shade="blue", hat="cap", hatc="blue", pack="grey", gun="grey"),
    "sniper": dict(uniform="red", shade="olive", hat="hood", hatc="olive", pack="olive", gun="black",
                   long_gun=True),
    "guard":  dict(uniform="olive", shade="grey", hat="helmet", hatc="grey", pack="red", gun="red"),
}


# ---------------------------------------------------------------------------
# Scene setup
# ---------------------------------------------------------------------------

def srgb_to_linear(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


_materials = {}


def mat(name):
    if name not in _materials:
        m = bpy.data.materials.new(name)
        r, g, b = (srgb_to_linear(v) for v in PAL[name])
        m.diffuse_color = (r, g, b, 1.0)
        _materials[name] = m
    return _materials[name]


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.render_aa = "OFF"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.resolution_percentage = 100
    return sc


def add_camera(sc, ortho_scale, target_z):
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    el = math.radians(CAM_ELEVATION)
    d = 20.0
    # camera south of the origin looking north and down
    cam.location = Vector((0.0, -d * math.cos(el), target_z + d * math.sin(el)))
    direction = Vector((0.0, 0.0, target_z)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    return cam


def box(name, size, loc, material, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    ob.data.materials.append(mat(material))
    if parent:
        ob.parent = parent
    return ob


def cyl(name, radius, depth, loc, material, parent=None, verts=8, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc,
                                        rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat(material))
    if parent:
        ob.parent = parent
    return ob


def sphere(name, radius, loc, material, parent=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=radius, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    ob.data.materials.append(mat(material))
    if parent:
        ob.parent = parent
    return ob


def pivot(name, loc, parent=None):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    if parent:
        ob.parent = parent
    return ob


# ---------------------------------------------------------------------------
# Low-poly operative / sentry (1.8 units tall, feet at z = 0, facing -Y)
# ---------------------------------------------------------------------------

def build_character(look):
    root = pivot("root", (0, 0, 0))
    body = pivot("body", (0, 0, 0), root)
    hip_z = 0.9
    parts = {"root": root, "body": body}
    for side, x in (("L", -0.13), ("R", 0.13)):
        hip = pivot(f"hip{side}", (x, 0, hip_z), body)
        box(f"leg{side}", (0.2, 0.22, 0.82), (0, 0, -0.41), look["uniform"], hip)
        box(f"boot{side}", (0.22, 0.32, 0.12), (0, -0.05, -0.84), "black", hip)
        parts[f"hip{side}"] = hip
    box("torso", (0.5, 0.3, 0.6), (0, 0, 1.2), look["uniform"], body)
    box("belt", (0.52, 0.32, 0.08), (0, 0, 0.93), look["shade"], body)
    box("pack", (0.36, 0.18, 0.42), (0, 0.24, 1.2), look["pack"], body)
    for side, x in (("L", -0.32), ("R", 0.32)):
        sh = pivot(f"sh{side}", (x, 0, 1.45), body)
        box(f"arm{side}", (0.14, 0.16, 0.55), (0, 0, -0.27), look["shade"], sh)
        box(f"hand{side}", (0.13, 0.13, 0.12), (0, 0, -0.6), "skin", sh)
        parts[f"sh{side}"] = sh
    head = pivot("head", (0, 0, 1.62), body)
    sphere("face", 0.16, (0, 0, 0.0), "skin", head, scale=(1, 1, 1.15))
    sphere("hair", 0.165, (0, 0.04, 0.03), "red", head, scale=(1, 0.95, 1.12))   # back of head
    for ex in (-0.065, 0.065):                                 # eyes (show in portraits)
        box("eye", (0.05, 0.04, 0.05), (ex, -0.165, 0.03), "black", head)
    box("mouth", (0.1, 0.04, 0.03), (0, -0.16, -0.09), "red", head)
    hat = look["hat"]
    if hat == "helmet":
        sphere("helmet", 0.2, (0, 0, 0.07), look["hatc"], head, scale=(1.05, 1.05, 0.75))
        cyl("rim", 0.24, 0.04, (0, 0, 0.0), look["hatc"], head)
    elif hat == "beret":
        cyl("beret", 0.19, 0.08, (0.04, 0, 0.14), look["hatc"], head, rot=(0, 0.25, 0))
    elif hat == "cap":
        cyl("cap", 0.17, 0.1, (0, 0, 0.13), look["hatc"], head)
        box("peak", (0.24, 0.14, 0.03), (0, -0.16, 0.09), look["hatc"], head)
    elif hat == "hood":
        sphere("hood", 0.2, (0, 0.08, 0.05), look["hatc"], head, scale=(1.05, 1.0, 1.15))  # face open
    gun_len = 1.0 if look.get("long_gun") else 0.7
    gun = box("gun", (0.06, gun_len, 0.08), (0, -gun_len / 2 + 0.1, -0.55), look["gun"],
              parts["shR"])
    parts["gun"] = gun
    parts["head"] = head
    return parts


def pose(parts, name, step):
    """Reset and apply a pose."""
    for k in ("root", "body", "hipL", "hipR", "shL", "shR", "head"):
        parts[k].rotation_euler = (0, 0, parts[k].rotation_euler[2] if k == "root" else 0)
    parts["root"].location = (0, 0, 0)
    parts["body"].location = (0, 0, 0)
    swing = math.radians(28)
    if name == "walk":
        s = swing if step == 1 else -swing
        parts["hipL"].rotation_euler[0] = s
        parts["hipR"].rotation_euler[0] = -s
        parts["shL"].rotation_euler[0] = -s * 0.8
        parts["shR"].rotation_euler[0] = s * 0.8
    elif name == "attack":
        parts["shR"].rotation_euler[0] = math.radians(95)       # arm thrust forward
        parts["hipL"].rotation_euler[0] = math.radians(15)
        parts["hipR"].rotation_euler[0] = math.radians(-15)
    elif name == "crawl":
        parts["body"].rotation_euler[0] = math.radians(90)      # prone, head forward (-Y)
        parts["body"].location = (0, 0.8, 0.18)
        s = math.radians(20) if step == 1 else -math.radians(20)
        parts["hipL"].rotation_euler[0] = s
        parts["hipR"].rotation_euler[0] = -s
        parts["shL"].rotation_euler[0] = math.radians(160) + s
        parts["shR"].rotation_euler[0] = math.radians(160) - s
    elif name == "corpse":
        parts["body"].rotation_euler[0] = math.radians(-90)     # on the back, head behind
        parts["body"].location = (0, -0.8, 0.18)
        parts["shL"].rotation_euler[1] = math.radians(-60)
        parts["shR"].rotation_euler[1] = math.radians(70)


def open_or_build(subject, blend_dir, builder):
    """Open <blend_dir>/<subject>.blend, or build the scene and save it."""
    path = os.path.join(blend_dir, subject + ".blend")
    if os.path.exists(path):
        bpy.ops.wm.open_mainfile(filepath=path)
        return bpy.context.scene, False
    sc = reset_scene()
    builder(sc)
    os.makedirs(blend_dir, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path, copy=True)
    return sc, True


def ground_target(height):
    """Camera aim height that puts the ground line at the bottom of a frame
    `height` units tall."""
    return (height / 2 - 0.05) / math.cos(math.radians(CAM_ELEVATION))


def render_still(sc, out_dir, subject, name):
    os.makedirs(os.path.join(out_dir, subject), exist_ok=True)
    sc.render.filepath = os.path.join(out_dir, subject, name + ".png")
    bpy.ops.render.render(write_still=True)


POSES = [("stand", 0), ("walk", 1), ("walk", 2), ("crawl", 1), ("crawl", 2), ("attack", 0),
         ("corpse", 0)]


def render_character(subject, out_dir, blend_dir):
    def build(sc):
        build_character(LOOKS[subject])
        # camera: frame 24x16 visual units around the feet
        add_camera(sc, ortho_scale=2.8, target_z=0.8)
        sc.render.resolution_x, sc.render.resolution_y = CHAR_RES
    sc, _ = open_or_build(subject, blend_dir, build)
    parts = {k: bpy.data.objects[k] for k in ("root", "body", "hipL", "hipR", "shL", "shR", "head")}
    os.makedirs(os.path.join(out_dir, subject), exist_ok=True)
    for pname, step in POSES:
        for dname, yaw in DIRS.items():
            if pname == "corpse" and dname != "S":
                continue
            if pname == "corpse":
                yaw = 90                # lying across the screen reads best
            parts["root"].rotation_euler = (0, 0, math.radians(yaw))
            pose(parts, pname, step)
            bpy.context.view_layer.update()
            tag = pname if not step else f"{pname}{step}"
            sc.render.filepath = os.path.join(out_dir, subject, f"{tag}_{dname}.png")
            bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------------------
# Radio tower (2x4 tiles = 16x32 Mode 0 pixels = 32x32 visual units)
# ---------------------------------------------------------------------------

def build_tower(sc):
    h = 6.5
    base = 1.7
    for sx in (-1, 1):
        for sy in (-1, 1):
            top = Vector((sx * 0.25, sy * 0.25, h))
            bot = Vector((sx * base, sy * base, 0))
            d = top - bot
            ob = cyl("leg", 0.13, d.length, (top + bot) / 2, "black", verts=4)
            ob.rotation_mode = "QUATERNION"
            ob.rotation_quaternion = d.to_track_quat("Z", "Y")
    for i in range(1, 5):
        z = i * h / 5
        w = base * (1 - z / h) + 0.25
        colour = "bred" if i % 2 else "grey"      # white would vanish on snow
        for (a, b) in (((-w, -w), (w, -w)), ((-w, w), (w, w)), ((-w, -w), (-w, w)), ((w, -w), (w, w))):
            p, q = Vector((*a, z)), Vector((*b, z))
            ob = cyl("rung", 0.12, (q - p).length, (p + q) / 2, colour, verts=4)
            ob.rotation_mode = "QUATERNION"
            ob.rotation_quaternion = (q - p).to_track_quat("Z", "Y")
    cyl("mast", 0.1, 1.0, (0, 0, h + 0.5), "bred", verts=4)
    sphere("beacon", 0.25, (0, 0, h + 1.0), "byel")
    add_camera(sc, ortho_scale=6.6, target_z=3.3)
    sc.render.resolution_x, sc.render.resolution_y = TOWER_RES


# ---------------------------------------------------------------------------
# Props. Sizes are chosen so 1 visual unit = UNIT Blender units everywhere.
# ---------------------------------------------------------------------------

def frame_camera(sc, px_w, px_h):
    """Camera + resolution for a px_w x px_h Mode 0 image, ground at bottom."""
    vis_w, vis_h = px_w * 2, px_h
    add_camera(sc, ortho_scale=vis_w * UNIT, target_z=ground_target(vis_h * UNIT))
    sc.render.resolution_x, sc.render.resolution_y = px_w * 8, px_h * 4


def build_pine(sc):                               # 2x3 tiles: 16x24 Mode 0 px
    cyl("trunk", 0.15, 0.8, (0, 0, 0.4), "red", verts=6)
    for i, (z, r) in enumerate(((0.6, 0.95), (1.45, 0.75), (2.25, 0.52))):
        bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=r, depth=1.35, location=(0, 0, z + 0.67))
        cone = bpy.context.active_object
        cone.data.materials.append(mat("green" if i != 1 else "teal"))
        bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=r * 0.5, radius2=0, depth=0.55,
                                        location=(0, 0, z + 1.2))
        cap = bpy.context.active_object                  # snow on the bough
        cap.data.materials.append(mat("white"))
    frame_camera(sc, 16, 24)


def build_rock(sc):                               # 1 tile: 8x8 Mode 0 px
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.5, location=(0, 0, 0.18))
    rock = bpy.context.active_object
    rock.scale = (1.0, 0.8, 0.5)
    rock.data.materials.append(mat("grey"))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.36, location=(-0.08, 0.05, 0.32))
    snow = bpy.context.active_object
    snow.scale = (1.0, 0.8, 0.35)
    snow.data.materials.append(mat("white"))
    frame_camera(sc, 8, 8)


def build_barrel(sc):                             # in a 12x16 sprite cell
    cyl("barrel", 0.26, 0.8, (0, 0, 0.4), "bred", verts=10)
    for z in (0.15, 0.65):
        cyl("band", 0.27, 0.07, (0, 0, z), "byel", verts=10)
    cyl("lid", 0.22, 0.02, (0, 0, 0.81), "orange", verts=10)
    frame_camera(sc, 12, 16)


def build_explosion(sc):                          # 3 frames in 12x16 cells
    groups = []
    for f, (r, core, mid, outer) in enumerate(((0.35, "byel", "orange", "bred"),
                                               (0.6, "pyel", "byel", "orange"),
                                               (0.8, "orange", "bred", "grey"))):
        coll = bpy.data.collections.new(f"frame{f + 1}")
        sc.collection.children.link(coll)
        for rad, colour, z in ((r, outer, r), (r * 0.75, mid, r * 1.05), (r * 0.45, core, r * 1.1)):
            ob = sphere(f"ball{f}", rad, (0, -(r - rad) * 1.4, z), colour)   # hotter layers in front
            for c in ob.users_collection:
                c.objects.unlink(ob)
            coll.objects.link(ob)
        if f == 2:                                       # smoke puffs
            for dx, dz in ((-0.4, 1.3), (0.35, 1.45), (0.0, 1.7)):
                ob = sphere("smoke", 0.3, (dx, 0.1, dz), "grey")
                for c in ob.users_collection:
                    c.objects.unlink(ob)
                coll.objects.link(ob)
        groups.append(coll)
    frame_camera(sc, 12, 16)


def build_truck(sc):                              # 3x2 tiles: 24x16 Mode 0 px, faces west
    box("chassis", (4.4, 1.5, 0.25), (0.1, 0, 0.42), "black")
    box("cab", (1.1, 1.5, 0.95), (-1.55, 0, 0.98), "olive")
    box("screen", (0.05, 1.2, 0.4), (-2.11, 0, 1.15), "sky")
    box("cover", (3.0, 1.55, 1.25), (0.75, 0, 1.15), "olive")
    for x in (-0.4, 0.4, 1.2, 1.9):
        box("rib", (0.08, 1.58, 1.28), (x, 0, 1.15), "grey")
    for x in (-1.5, 0.9, 1.7):
        for y in (-0.75, 0.75):
            cyl("wheel", 0.33, 0.25, (x, y, 0.33), "black", verts=10, rot=(math.radians(90), 0, 0))
    frame_camera(sc, 24, 16)


PORTRAIT_RES = (16, 24)


def build_portraits(sc):
    """Head-and-shoulders busts of the three operatives side by side; each is
    rendered with its own camera framing (cameras cam_beret...)."""
    for i, subject in enumerate(("beret", "marine", "sniper")):
        parts = build_character(LOOKS[subject])
        parts["root"].location = (i * 3.0, 0, 0)
        for k in ("shL", "shR"):                         # arms down by the sides
            parts[k].rotation_euler = (0, 0, 0)
        cam_data = bpy.data.cameras.new(f"cam_{subject}")
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = 0.72
        cam = bpy.data.objects.new(f"cam_{subject}", cam_data)
        sc.collection.objects.link(cam)
        el = math.radians(8)
        cam.location = Vector((i * 3.0, -10 * math.cos(el), 1.56 + 10 * math.sin(el)))
        cam.rotation_euler = (Vector((i * 3.0, 0, 1.56)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    box("backdrop", (12, 0.1, 6), (3.0, 3.0, 1.5), "grey")
    sc.render.resolution_x, sc.render.resolution_y = PORTRAIT_RES[0] * 8, PORTRAIT_RES[1] * 4


def build_banner(sc):
    """Title banner, 160x56 Mode 0 px (= 320x56 visual units)."""
    vis_w, vis_h = 320, 56
    u = 0.125                                        # units per visual unit here
    w, h = vis_w * u, vis_h * u                      # 40 x 7 units
    el = math.radians(6)
    box("sky", (w * 1.4, 0.2, h * 3), (0, 30, 0), "blue")
    import random
    random.seed(21)
    for _ in range(45):                              # stars on the backdrop
        sx = random.uniform(-w / 2, w / 2)
        sz = random.uniform(h * 0.45, h * 1.1)
        box("star", (0.2, 0.05, 0.2), (sx, 29.8, sz), random.choice(("white", "snowsh", "pyel")))
    # low-poly mountain range
    import bmesh
    me = bpy.data.meshes.new("mountains")
    bm = bmesh.new()
    peaks = [(-24, 0), (-19, 3.4), (-15, 1.9), (-11, 4.6), (-7, 2.4), (-3, 4.2), (1, 2.1),
             (5, 4.9), (9, 2.6), (13, 4.0), (17, 2.2), (21, 3.8), (25, 0)]
    for (x0, z0), (x1, z1) in zip(peaks, peaks[1:]):
        v = [bm.verts.new((x0, 18, 0)), bm.verts.new((x1, 18, 0)), bm.verts.new((x1, 18, z1)),
             bm.verts.new((x0, 18, z0))]
        bm.faces.new(v)
    bm.to_mesh(me)
    mtn = bpy.data.objects.new("mountains", me)
    sc.collection.objects.link(mtn)
    mtn.data.materials.append(mat("grey"))
    cme = bpy.data.meshes.new("caps")                # snow caps: the top 30% of each peak
    bm = bmesh.new()
    for (xa, za), (x, z), (xb, zb) in zip(peaks, peaks[1:], peaks[2:]):
        t = 0.3
        v = [bm.verts.new((x + (xa - x) * t, 17.9, z + (za - z) * t)),
             bm.verts.new((x + (xb - x) * t, 17.9, z + (zb - z) * t)),
             bm.verts.new((x, 17.9, z))]
        bm.faces.new(v)
    bm.to_mesh(cme)
    caps = bpy.data.objects.new("caps", cme)
    sc.collection.objects.link(caps)
    caps.data.materials.append(mat("white"))
    box("snowfield", (w * 1.4, 40, 0.1), (0, 0, -0.05), "white")
    # logo
    for text, z in (("A HANDFUL", 4.05), ("OF MEN", 1.25)):
        for colour, dx, dz, dy in (("red", 0.16, -0.2, 0.15), ("byel", 0, 0, 0)):
            bpy.ops.object.text_add(location=(dx, -4 + dy, z + dz), rotation=(math.radians(90), 0, 0))
            t = bpy.context.active_object
            t.data.body = text
            t.data.align_x = "CENTER"
            t.data.size = 2.85
            t.data.extrude = 0.05
            t.data.offset = 0.07          # bolder strokes survive Mode 0 pixels
            t.data.space_character = 1.1
            t.data.materials.append(mat(colour))
    # the squad on the left, a sentry on the right
    for x, subject, yaw in ((-16.5, "beret", 90), (-15, "marine", 90), (15.5, "guard", -90)):
        parts = build_character(LOOKS[subject])
        parts["root"].location = (x, -2, 0)
        parts["root"].rotation_euler = (0, 0, math.radians(yaw))
        parts["hipL"].rotation_euler[0] = math.radians(25)
        parts["hipR"].rotation_euler[0] = math.radians(-25)
        parts["root"].scale = (1.6, 1.6, 1.6)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = w
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    cam.location = Vector((0, -40 * math.cos(el), h / 2 + 40 * math.sin(el)))
    cam.rotation_euler = (Vector((0, 0, h / 2)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = 160 * 8, 56 * 4


def render_prop(subject, out_dir, blend_dir):
    builders = {"tower": build_tower, "pine": build_pine, "rock": build_rock,
                "barrel": build_barrel, "truck": build_truck, "banner": build_banner}
    sc, _ = open_or_build(subject, blend_dir, builders[subject])
    render_still(sc, out_dir, subject, subject)


def render_explosion(out_dir, blend_dir):
    sc, _ = open_or_build("explosion", blend_dir, build_explosion)
    frames = sorted((c for c in bpy.data.collections if c.name.startswith("frame")), key=lambda c: c.name)
    for coll in frames:
        for other in frames:
            other.hide_render = other is not coll
        render_still(sc, out_dir, "explosion", coll.name)


def render_portraits(out_dir, blend_dir):
    sc, _ = open_or_build("portraits", blend_dir, build_portraits)
    for subject in ("beret", "marine", "sniper"):
        sc.camera = bpy.data.objects[f"cam_{subject}"]
        render_still(sc, out_dir, "portraits", subject)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = argv[0] if argv else os.path.join(os.getcwd(), "renders")
    blend_dir = argv[1] if len(argv) > 1 else os.path.join(os.getcwd(), "blender")
    for s in argv[2:] or SUBJECTS:
        if s in LOOKS:
            render_character(s, out_dir, blend_dir)
        elif s == "explosion":
            render_explosion(out_dir, blend_dir)
        elif s == "portraits":
            render_portraits(out_dir, blend_dir)
        else:
            render_prop(s, out_dir, blend_dir)
        print(f"HFM_RENDERED {s}")


main()
