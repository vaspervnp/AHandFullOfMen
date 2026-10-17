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
SUBJECTS = ["beret", "marine", "sniper", "sapper", "spy", "guard", "tower", "pine", "rock",
            "barrel", "trap", "bomb", "explosion", "truck", "depot", "uboat", "railbridge", "gun", "plant", "train", "portraits", "banner"]
OPERATIVES = ("beret", "marine", "sniper", "sapper", "spy")      # portrait order = ROLE_*

LOOKS = {
    "beret":  dict(uniform="green", shade="teal", hat="beret", hatc="teal", pack="olive", gun="grey"),
    "marine": dict(uniform="sky", shade="blue", hat="cap", hatc="blue", pack="grey", gun="grey"),
    "sniper": dict(uniform="red", shade="olive", hat="hood", hatc="olive", pack="olive", gun="black",
                   long_gun=True),
    "sapper": dict(uniform="orange", shade="red", hat="cap", hatc="red", pack="grey", gun="black",
                   big_pack=True),
    "spy":    dict(uniform="blue", shade="black", hat="fedora", hatc="black", pack=None, gun="grey",
                   short_gun=True),
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
# Chibi operative / sentry (about 1.7 units tall, feet at z = 0, facing -Y):
# a big round head (half the height) with large shiny eyes, a short round
# body, stubby limbs.
# ---------------------------------------------------------------------------

HEAD_Z = 1.22                   # head centre
HEAD_R = 0.42


def build_character(look):
    root = pivot("root", (0, 0, 0))
    body = pivot("body", (0, 0, 0), root)
    hip_z = 0.42
    parts = {"root": root, "body": body}
    for side, x in (("L", -0.11), ("R", 0.11)):
        hip = pivot(f"hip{side}", (x, 0, hip_z), body)
        cyl(f"leg{side}", 0.1, 0.3, (0, 0, -0.17), look["uniform"], hip, verts=8)
        sphere(f"boot{side}", 0.12, (0, -0.04, -0.34), "black", hip, scale=(1, 1.25, 0.7))
        parts[f"hip{side}"] = hip
    cyl("torso", 0.24, 0.44, (0, 0, 0.62), look["uniform"], body, verts=10)
    sphere("tummy", 0.25, (0, 0, 0.5), look["uniform"], body, scale=(1, 0.95, 0.7))
    cyl("belt", 0.255, 0.07, (0, 0, 0.47), look["shade"], body, verts=10)
    if look["pack"]:
        if look.get("big_pack"):                      # demolition charges
            box("pack", (0.4, 0.22, 0.42), (0, 0.27, 0.66), look["pack"], body)
            box("charge", (0.42, 0.08, 0.1), (0, 0.39, 0.52), "bred", body)
        else:
            box("pack", (0.32, 0.16, 0.32), (0, 0.24, 0.66), look["pack"], body)
    for side, x in (("L", -0.29), ("R", 0.29)):
        sh = pivot(f"sh{side}", (x, 0, 0.8), body)
        cyl(f"arm{side}", 0.075, 0.28, (0, 0, -0.14), look["shade"], sh, verts=8)
        sphere(f"hand{side}", 0.085, (0, 0, -0.32), "skin", sh)
        parts[f"sh{side}"] = sh
    head = pivot("head", (0, 0, HEAD_Z), body)
    sphere("face", HEAD_R, (0, 0, 0), "skin", head, scale=(1.08, 1, 0.95))
    sphere("hair", HEAD_R + 0.02, (0, 0.06, 0.05), "red", head, scale=(1.08, 0.95, 0.95))
    sphere("fringe", 0.2, (0, -0.3, 0.24), "red", head, scale=(1.6, 0.6, 0.55))
    for ex in (-0.16, 0.16):                          # big shiny eyes
        sphere("eye", 0.085, (ex, -0.37, -0.03), "black", head, scale=(0.8, 0.45, 1.3))
        sphere("shine", 0.03, (ex + 0.025, -0.415, 0.03), "white", head)
        sphere("blush", 0.06, (ex * 1.6, -0.33, -0.15), "bred", head, scale=(1.1, 0.35, 0.6))
    sphere("mouth", 0.035, (0, -0.405, -0.18), "red", head, scale=(1.4, 0.5, 0.8))
    hat = look["hat"]
    if hat == "helmet":
        sphere("helmet", HEAD_R + 0.06, (0, 0.02, 0.12), look["hatc"], head, scale=(1.08, 1.05, 0.72))
        cyl("rim", HEAD_R + 0.1, 0.05, (0, 0.02, 0.06), look["hatc"], head, verts=12)
    elif hat == "beret":
        cyl("beret", 0.4, 0.13, (0.07, 0.02, 0.36), look["hatc"], head, verts=12, rot=(0, 0.25, 0))
        sphere("bobble", 0.05, (0.1, 0.02, 0.45), look["hatc"], head)
    elif hat == "cap":
        cyl("cap", 0.4, 0.18, (0, 0.02, 0.32), look["hatc"], head, verts=12)
        box("peak", (0.5, 0.3, 0.05), (0, -0.4, 0.25), look["hatc"], head)
    elif hat == "fedora":
        cyl("brim", 0.56, 0.05, (0, 0.02, 0.3), look["hatc"], head, verts=12)
        cyl("crown", 0.34, 0.28, (0, 0.02, 0.45), look["hatc"], head, verts=12)
        cyl("band", 0.345, 0.06, (0, 0.02, 0.35), "red", head, verts=12)
    elif hat == "hood":
        sphere("hood", HEAD_R + 0.07, (0, 0.13, 0.04), look["hatc"], head, scale=(1.1, 1.0, 1.05))
    gun_len = 0.6 if look.get("long_gun") else 0.18 if look.get("short_gun") else 0.42
    gun = box("gun", (0.06, gun_len, 0.08), (0, -gun_len / 2 + 0.08, -0.32), look["gun"],
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
    parts["head"].rotation_euler[0] = math.radians(-22)    # chibi: face up to the camera
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
        parts["body"].location = (0, 1.0, HEAD_R - 0.05)    # head stays in frame
        s = math.radians(20) if step == 1 else -math.radians(20)
        parts["hipL"].rotation_euler[0] = s
        parts["hipR"].rotation_euler[0] = -s
        parts["shL"].rotation_euler[0] = math.radians(160) + s
        parts["shR"].rotation_euler[0] = math.radians(160) - s
    elif name == "corpse":
        parts["body"].rotation_euler[0] = math.radians(-90)     # on the back, head behind
        parts["body"].location = (0, -0.6, HEAD_R - 0.05)
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

def build_tower(sc):                              # candy-striped mast, 2x4 tiles
    cyl("base", 1.0, 0.8, (0, 0, 0.4), "grey", verts=16)
    sphere("base_top", 1.0, (0, 0, 0.8), "grey", scale=(1, 1, 0.3))
    cute_face(0, -0.99, 0.55, 6.0)
    h0, seg = 0.9, 0.82
    for i in range(6):                               # red and cream stripes
        cyl("stripe", 0.3, seg, (0, 0, h0 + seg * (i + 0.5)), "bred" if i % 2 == 0 else "pyel", verts=12)
    top = h0 + seg * 6
    sphere("ball", 0.5, (0, 0, top + 0.35), "byel")
    sphere("shine", 0.13, (-0.18, -0.4, top + 0.5), "white")
    cyl("aerial", 0.06, 0.7, (0, 0, top + 1.1), "grey", verts=6)
    sphere("tip", 0.14, (0, 0, top + 1.5), "bred")
    add_camera(sc, ortho_scale=6.6, target_z=3.3)
    sc.render.resolution_x, sc.render.resolution_y = TOWER_RES


# ---------------------------------------------------------------------------
# Props. Sizes are chosen so 1 visual unit = UNIT Blender units everywhere.
# ---------------------------------------------------------------------------

def cute_face(cx, cy, cz, s=1.0):
    """Kawaii face on a surface that faces the camera (-Y): shiny eyes,
    blush and a little mouth, centred at (cx, cy, cz), scaled by s. One
    Mode 0 pixel is about 0.23 units wide, so props need s >= 2.5 or so."""
    cy -= 0.03 * s                                   # stand proud of the surface
    for ex in (-1, 1):
        x = cx + ex * 0.13 * s
        sphere("eye", 0.07 * s, (x, cy, cz), "black", scale=(0.8, 0.5, 1.3))
        sphere("shine", 0.025 * s, (x + 0.02 * s, cy - 0.04 * s, cz + 0.05 * s), "white")
        sphere("blush", 0.05 * s, (cx + ex * 0.25 * s, cy + 0.01 * s, cz - 0.1 * s), "bred",
               scale=(1.1, 0.35, 0.6))
    sphere("mouth", 0.03 * s, (cx, cy - 0.01 * s, cz - 0.12 * s), "red", scale=(1.4, 0.5, 0.8))


def frame_camera(sc, px_w, px_h):
    """Camera + resolution for a px_w x px_h Mode 0 image, ground at bottom.
    The frame's bottom edge is the ground at y = 0, so anything nearer the
    camera would be cut off: the whole prop moves back until its front is
    at y = 0 (that's where the faces are)."""
    bpy.context.view_layer.update()
    front = min((ob.matrix_world @ Vector(c)).y
                for ob in sc.objects if ob.type == "MESH" for c in ob.bound_box)
    tops = [ob for ob in sc.objects if ob.parent is None and ob.type in ("MESH", "EMPTY")]
    if front < 0:
        for ob in tops:
            ob.location.y -= front
    # ... and shrinks, about the origin, until it fits the frame
    el = math.radians(CAM_ELEVATION)
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ Vector(c) for ob in sc.objects if ob.type == "MESH" for c in ob.bound_box]
    high = max(p.y * math.sin(el) + p.z * math.cos(el) for p in pts)
    wide = max(abs(p.x) for p in pts)
    fit = min(1.0, px_h * UNIT * 0.97 / high, px_w * UNIT * 0.97 / wide)
    if fit < 1.0:
        for ob in tops:
            ob.location *= fit
            ob.scale *= fit
    vis_w, vis_h = px_w * 2, px_h
    add_camera(sc, ortho_scale=vis_w * UNIT, target_z=ground_target(vis_h * UNIT))
    sc.render.resolution_x, sc.render.resolution_y = px_w * 8, px_h * 4


def build_pine(sc):                               # 2x3 tiles: 16x24 Mode 0 px, fluffy tree
    cyl("trunk", 0.22, 0.5, (0, 0, 0.25), "red", verts=8)
    for i, (z, r) in enumerate(((0.95, 0.85), (1.85, 0.68), (2.6, 0.5))):
        sphere("puff", r, (0, 0, z), "green" if i != 1 else "teal")
        sphere("snow", r * 0.75, (0, 0.05, z + r * 0.62), "white", scale=(1, 1, 0.4))
    cute_face(0, -0.68, 1.42, 3.2)              # upper front: faces the camera
    frame_camera(sc, 16, 24)


def build_rock(sc):                               # 1 tile: 8x8 Mode 0 px, a round pebble
    sphere("rock", 0.6, (0, 0, 0.3), "grey", scale=(1.0, 0.85, 0.6))
    sphere("snow", 0.44, (-0.05, 0.05, 0.53), "white", scale=(1.0, 0.85, 0.35))
    for ex in (-0.2, 0.2):
        sphere("eye", 0.13, (ex, -0.5, 0.26), "black", scale=(0.9, 0.5, 1.0))
    frame_camera(sc, 8, 8)


def build_barrel(sc):                             # in a 12x16 sprite cell, a chubby barrel
    cyl("barrel", 0.42, 0.62, (0, 0, 0.36), "bred", verts=14)
    sphere("top", 0.42, (0, 0, 0.67), "orange", scale=(1, 1, 0.3))
    sphere("bottom", 0.42, (0, 0, 0.06), "bred", scale=(1, 1, 0.2))
    for z in (0.12, 0.62):
        cyl("band", 0.43, 0.06, (0, 0, z), "byel", verts=14)
    cute_face(0, -0.42, 0.48, 2.6)
    frame_camera(sc, 12, 16)


def build_explosion(sc):                          # 3 frames in 12x16 cells: puffy cartoon clouds
    puffs = ((-0.55, 0.0), (0.55, 0.0), (0.0, 0.0), (-0.3, 0.45), (0.3, 0.45), (0.0, 0.75))
    for f, (r, core, mid, outer) in enumerate(((0.35, "byel", "orange", "bred"),
                                               (0.6, "pyel", "byel", "orange"),
                                               (0.8, "orange", "bred", "grey"))):
        coll = bpy.data.collections.new(f"frame{f + 1}")
        sc.collection.children.link(coll)
        obs = []
        for dx, dz in puffs:                             # the cloud: round puffs
            obs.append(sphere(f"puff{f}", r * 0.55, (dx * r, 0.1, r * 0.6 + dz * r), outer))
        obs.append(sphere(f"mid{f}", r * 0.6, (0, -r * 0.35, r * 0.85), mid))
        obs.append(sphere(f"core{f}", r * 0.35, (0, -r * 0.7, r * 0.9), core))
        if f < 2:                                        # sparkles
            for dx, dz in ((-1.1, 1.4), (1.1, 1.2), (0.0, 1.8)):
                obs.append(sphere("spark", 0.1, (dx * r, -0.4, dz * r), "byel"))
        else:                                            # smoke puffs drifting up
            for dx, dz in ((-0.4, 1.4), (0.35, 1.55), (0.0, 1.8)):
                obs.append(sphere("smoke", 0.3, (dx, 0.1, dz), "grey"))
        for ob in obs:
            for c in ob.users_collection:
                c.objects.unlink(ob)
            coll.objects.link(ob)
    frame_camera(sc, 12, 16)


def build_truck(sc):                              # 3x2 tiles: 24x16 Mode 0 px, faces west, chubby
    box("chassis", (4.2, 1.4, 0.25), (0.1, 0, 0.45), "black")
    box("cab", (1.2, 1.5, 0.8), (-1.45, 0, 0.95), "olive")
    sphere("cab_top", 0.75, (-1.45, 0, 1.3), "olive", scale=(0.85, 1.0, 0.55))
    sphere("screen", 0.42, (-1.95, 0, 1.25), "sky", scale=(0.4, 1.4, 0.6))
    cyl("cover", 0.78, 2.8, (0.75, 0, 1.0), "olive", verts=14, rot=(0, math.radians(90), 0))
    box("cover_base", (2.8, 1.56, 0.4), (0.75, 0, 0.8), "olive")
    for x in (0.0, 0.75, 1.5):
        cyl("rib", 0.8, 0.07, (x, 0, 1.0), "teal", verts=14, rot=(0, math.radians(90), 0))
    cute_face(-1.45, -0.76, 0.98, 2.8)
    sphere("lamp", 0.16, (-2.05, -0.55, 0.75), "byel")
    for x in (-1.5, 0.6, 1.5):                       # big round wheels
        for y in (-0.72, 0.72):
            cyl("wheel", 0.4, 0.28, (x, y, 0.4), "black", verts=12, rot=(math.radians(90), 0, 0))
            cyl("hub", 0.16, 0.3, (x, y, 0.4), "grey", verts=8, rot=(math.radians(90), 0, 0))
    frame_camera(sc, 24, 16)


def build_depot(sc):                              # 3x2 tiles: 24x16 Mode 0 px, two round tanks
    for y in (0.55, -0.55):                          # back tank first, the face on the front one
        cyl("tank", 0.5, 2.6, (0, y, 0.75), "grey", verts=14, rot=(0, math.radians(90), 0))
        for x in (-1.3, 1.3):
            sphere("end", 0.5, (x, y, 0.75), "grey", scale=(0.5, 1, 1))
            sphere("foot", 0.22, (x * 0.8, y, 0.18), "black", scale=(1, 2, 0.8))
        cyl("stripe", 0.51, 0.3, (0.75, y, 0.75), "bred", verts=14, rot=(0, math.radians(90), 0))
    cute_face(-0.3, -0.95, 1.05, 3.4)          # upper front of the front tank
    cyl("pipe", 0.07, 1.4, (1.3, 0, 1.3), "black", verts=6, rot=(math.radians(90), 0, 0))
    sphere("valve", 0.17, (1.3, 0, 1.45), "byel")
    frame_camera(sc, 24, 16)


def build_uboat(sc):                              # 16x6 tiles: 128x48 Mode 0 px, bow east, chubby
    sphere("hull", 1.0, (0, 0, 0.3), "grey", scale=(3.1, 0.58, 0.58))
    box("deck", (4.4, 0.36, 0.1), (0, 0, 0.86), "black")
    cyl("tower", 0.38, 0.6, (-0.3, 0, 1.15), "grey", verts=12)
    sphere("tower_top", 0.38, (-0.3, 0, 1.45), "grey", scale=(1, 1, 0.45))
    box("number", (0.5, 0.05, 0.18), (-0.3, -0.39, 1.12), "white")
    cyl("periscope", 0.04, 0.5, (-0.15, 0, 1.85), "black", verts=6)
    sphere("lens", 0.07, (-0.15, -0.03, 2.1), "byel")
    for x in (-1.9, -1.2, 0.6, 1.2):                 # portholes
        sphere("porthole", 0.09, (x, -0.55 * (1 - (x / 3.1) ** 2) ** 0.5, 0.4), "white",
               scale=(1, 0.5, 1))
    cute_face(2.0, -0.43, 0.42, 1.3)
    bpy.ops.object.empty_add(location=(0, 0, 0))     # modelled at 4x2 tiles:
    rig = bpy.context.active_object                  # 4x as long, 3x as wide/tall
    for ob in sc.objects:
        if ob.type == "MESH":
            ob.parent = rig
    rig.scale = (4, 3, 3)
    frame_camera(sc, 128, 48)


def build_railbridge(sc):                             # 4x3 tiles: 32x24 Mode 0 px, spans north
    deck_d, half = 3.9, 3.3                          # the deck runs from y=0 (south bank) north
    box("deck", (2 * half, deck_d, 0.12), (0, deck_d / 2, 0.2), "red")
    for i in range(9):                               # sleepers under the rails
        box("sleeper", (2.2, 0.2, 0.05), (0, 0.25 + i * 0.43, 0.285), "black")
    for x in (-0.7, 0.7):
        box("rail", (0.08, deck_d, 0.06), (x, deck_d / 2, 0.33), "grey")
    for x in (-half, half):                          # steel girders with cross bracing
        box("girder", (0.4, deck_d, 0.14), (x, deck_d / 2, 0.62), "grey")
        box("chord", (0.4, deck_d, 0.14), (x, deck_d / 2, 0.24), "grey")
        for i in range(5):
            y = 0.1 + i * (deck_d - 0.2) / 4
            box("post", (0.3, 0.16, 0.42), (x, y, 0.43), "grey")
            sphere("cap", 0.16, (x, y, 0.72), "byel")
            if i < 4:
                ob = box("brace", (0.14, 1.1, 0.1), (x, y + (deck_d - 0.2) / 8, 0.43), "black")
                ob.rotation_euler = (math.radians(22 if i % 2 else -22), 0, 0)
    for y in (0.9, deck_d - 0.9):                    # stone piers in the river
        box("pier", (2 * half + 0.3, 0.5, 0.25), (0, y, 0.02), "white")
    frame_camera(sc, 32, 24)


def build_gun(sc):                                # 4x3 tiles: 32x24 Mode 0 px, coastal gun aimed west
    cy = 1.7                                         # the pit's centre, north of the front edge
    cyl("pit", 1.75, 0.45, (0, cy, 0.22), "white", verts=16)         # concrete emplacement
    cyl("floor", 1.4, 0.52, (0, cy, 0.26), "grey", verts=16)
    sphere("dome", 0.75, (0.15, cy, 0.55), "olive", scale=(1, 1, 0.75))   # round gun house
    sphere("hatch", 0.25, (0.25, cy + 0.1, 1.08), "teal", scale=(1, 1, 0.4))
    cute_face(0.15, cy - 0.72, 0.6, 3.0)
    cyl("barrel", 0.16, 1.7, (-1.35, cy, 0.75), "black", verts=10, rot=(0, math.radians(90), 0))
    sphere("muzzle", 0.22, (-2.2, cy, 0.75), "grey")
    for x, y in ((2.4, cy - 0.8), (2.6, cy), (2.4, cy + 0.8)):     # shell crates by the rim
        box("crate", (0.4, 0.3, 0.3), (x, y, 0.15), "red")
        sphere("shell", 0.1, (x, y, 0.36), "byel")
    frame_camera(sc, 32, 24)


def build_plant(sc):                              # 4x3 tiles: 32x24 Mode 0 px, heavy water plant
    box("hall", (4.6, 1.6, 0.9), (0.2, 1.6, 0.45), "white")          # concrete hall
    cyl("roof", 0.82, 4.7, (0.2, 1.6, 0.9), "teal", verts=16, rot=(0, math.radians(90), 0))
    for x in (-1.75, -1.0, 1.4):                                     # round lit windows
        sphere("window", 0.17, (x, 0.79, 0.55), "byel", scale=(1, 0.3, 1))
    cute_face(0.2, 0.8, 0.5, 3.0)
    sphere("door", 0.28, (2.0, 0.79, 0.25), "red", scale=(1, 0.3, 1.3))
    cyl("chimney", 0.25, 1.0, (-1.6, 1.6, 1.4), "red", verts=10)
    for dx, dz, r in ((0.0, 2.05, 0.22), (0.3, 2.3, 0.17)):          # a puff of smoke
        sphere("smoke", r, (-1.6 + dx, 1.6, dz), "snowsh")
    for y in (1.0, 2.0):                                             # the heavy water cells
        cyl("tank", 0.45, 0.9, (-2.8, y, 0.45), "grey", verts=12)
        sphere("tank_top", 0.45, (-2.8, y, 0.9), "grey", scale=(1, 1, 0.5))
    frame_camera(sc, 32, 24)


def build_train(sc):                              # 10x3 tiles: 80x24 Mode 0 px, ammunition train
    y = 0.75                                         # on the track, facing west
    cyl("boiler", 0.52, 3.0, (-6.2, y, 1.0), "blue", verts=14, rot=(0, math.radians(90), 0))
    sphere("nose", 0.52, (-7.7, y, 1.0), "grey", scale=(0.35, 1, 1))
    cyl("funnel", 0.22, 0.45, (-7.1, y, 1.65), "black", verts=10)
    sphere("funnel_top", 0.3, (-7.1, y, 1.9), "black", scale=(1, 1, 0.45))
    sphere("dome", 0.25, (-6.0, y, 1.55), "byel")
    cute_face(-6.8, y - 0.52, 1.0, 3.0)
    box("cab", (1.3, 1.1, 1.2), (-4.1, y, 1.1), "blue")
    sphere("cab_roof", 0.8, (-4.1, y, 1.72), "red", scale=(1, 0.8, 0.3))
    sphere("cab_window", 0.25, (-4.1, y - 0.56, 1.35), "byel", scale=(1, 0.3, 1))
    box("chassis", (14.6, 0.9, 0.3), (-0.4, y, 0.45), "grey")
    for x in (-7.0, -6.2, -5.4, -4.4):                               # driving wheels
        cyl("wheel", 0.38, 1.0, (x, y, 0.38), "red", verts=12, rot=(math.radians(90), 0, 0))
    box("tender", (1.6, 1.1, 0.9), (-2.6, y, 0.95), "blue")
    for x0 in (0.4, 4.4):                                            # two ammunition wagons
        box("wagon", (3.4, 1.2, 1.1), (x0 + 0.7, y, 1.1), "olive")
        cyl("roof", 0.66, 3.5, (x0 + 0.7, y, 1.62), "grey", verts=14, rot=(0, math.radians(90), 0))
        sphere("door", 0.4, (x0 + 0.7, y - 0.6, 1.05), "red", scale=(1, 0.2, 1.1))
        sphere("mark", 0.15, (x0 - 0.4, y - 0.61, 1.3), "byel", scale=(1, 0.2, 1))
        for x in (x0 - 0.5, x0 + 1.9):
            cyl("wheel", 0.3, 1.0, (x, y, 0.3), "black", verts=10, rot=(math.radians(90), 0, 0))
    bpy.ops.object.empty_add(location=(0, 0, 0))     # centre, then stretch to fill
    rig = bpy.context.active_object                  # all ten tiles
    for ob in sc.objects:
        if ob.type == "MESH":
            ob.location.x += 0.75
            ob.parent = rig
    rig.scale = (1.25, 1, 1)
    frame_camera(sc, 80, 24)


def build_trap(sc):                               # bear trap, in a 12x16 sprite cell
    cyl("plate", 0.45, 0.05, (0, 0, 0.03), "grey", verts=12)
    for y in (-0.36, 0.36):                          # open jaws, round teeth up
        box("jaw", (1.0, 0.1, 0.18), (0, y, 0.12), "black")
        for x in (-0.38, -0.13, 0.13, 0.38):
            sphere("tooth", 0.08, (x, y * 0.85, 0.27), "white", scale=(1, 1, 1.3))
    sphere("spring", 0.12, (0, 0, 0.1), "byel")
    frame_camera(sc, 12, 16)


def build_bomb(sc):                               # a round cartoon bomb with a lit fuse, 12x16 cell
    sphere("bomb", 0.46, (0, 0, 0.46), "black")
    sphere("shine", 0.1, (-0.2, -0.36, 0.66), "grey")
    cyl("cap", 0.14, 0.14, (0, 0, 0.94), "grey", verts=8)
    cyl("fuse", 0.04, 0.3, (0.08, 0, 1.1), "orange", verts=6, rot=(0, 0.5, 0))
    sphere("spark", 0.12, (0.17, 0, 1.25), "byel")
    for ex in (-0.17, 0.17):
        sphere("eye", 0.1, (ex, -0.44, 0.46), "white", scale=(0.9, 0.5, 1.3))
    frame_camera(sc, 12, 16)


PORTRAIT_RES = (16, 24)


def build_portraits(sc):
    """Head-and-shoulders busts of the operatives side by side; each is
    rendered with its own camera framing (cameras cam_beret...)."""
    for i, subject in enumerate(OPERATIVES):
        parts = build_character(LOOKS[subject])
        parts["root"].location = (i * 3.0, 0, 0)
        for k in ("shL", "shR"):                         # arms down by the sides
            parts[k].rotation_euler = (0, 0, 0)
        cam_data = bpy.data.cameras.new(f"cam_{subject}")
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = 1.45                      # the big chibi head
        cam = bpy.data.objects.new(f"cam_{subject}", cam_data)
        sc.collection.objects.link(cam)
        el = math.radians(8)
        cz = HEAD_Z - 0.08
        cam.location = Vector((i * 3.0, -10 * math.cos(el), cz + 10 * math.sin(el)))
        cam.rotation_euler = (Vector((i * 3.0, 0, cz)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    box("backdrop", (20, 0.1, 6), (6.0, 3.0, 1.5), "grey")
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
    # (the logo is pixel art: assets/aseprite/logo.aseprite, added by assemble_art)
    # the squad on the left, a sentry on the right
    for x, subject, yaw in ((-16.8, "beret", 25), (-14.6, "marine", 15), (15.6, "guard", -25)):
        parts = build_character(LOOKS[subject])
        parts["root"].location = (x, -2, 0)
        parts["root"].rotation_euler = (0, 0, math.radians(yaw))
        parts["hipL"].rotation_euler[0] = math.radians(25)
        parts["hipR"].rotation_euler[0] = math.radians(-25)
        parts["root"].scale = (2.3, 2.3, 2.3)
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
                "barrel": build_barrel, "truck": build_truck, "banner": build_banner,
                "depot": build_depot, "trap": build_trap, "bomb": build_bomb,
                "uboat": build_uboat, "railbridge": build_railbridge, "gun": build_gun, "plant": build_plant, "train": build_train}
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
    for subject in OPERATIVES:
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
