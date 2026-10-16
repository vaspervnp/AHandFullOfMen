"""Blender pre-render pipeline for A Handful of Men.

Run headless:
    blender -b --factory-startup --python tools/blender/hfm_render.py -- <out_dir> [subject ...]

Builds low-poly models procedurally (operatives, German sentry, radio
tower), poses them and renders every frame the game needs with an
orthographic camera. Workbench + flat lighting + no anti-aliasing means
each material renders as one exact colour; the colours are the CPC game
palette, so tools/renders2sheet.py can map pixels back to pens 1:1.

Anamorphic compensation: a 12x16 Mode 0 sprite covers 24x16 square units
on screen (Mode 0 pixels are 2:1), so characters render at 96x64 and are
reduced by 8x4 blocks to 12x16.

Output: <out_dir>/<subject>/<pose>_<dir>.png  (dir in N NE E SE S)
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
        sphere("hood", 0.21, (0, 0.03, 0.03), look["hatc"], head, scale=(1, 1.05, 1.15))
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


POSES = [("stand", 0), ("walk", 1), ("walk", 2), ("crawl", 1), ("crawl", 2), ("attack", 0),
         ("corpse", 0)]


def render_character(subject, out_dir):
    sc = reset_scene()
    parts = build_character(LOOKS[subject])
    # camera: frame 24x16 visual units around the feet
    add_camera(sc, ortho_scale=2.8, target_z=0.8)
    sc.render.resolution_x, sc.render.resolution_y = CHAR_RES
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

def render_tower(out_dir):
    sc = reset_scene()
    h = 6.5
    base = 1.7
    legs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            top = Vector((sx * 0.25, sy * 0.25, h))
            bot = Vector((sx * base, sy * base, 0))
            mid = (top + bot) / 2
            d = top - bot
            ob = cyl("leg", 0.13, d.length, mid, "black", verts=4)
            ob.rotation_mode = "QUATERNION"
            ob.rotation_quaternion = d.to_track_quat("Z", "Y")
            legs.append(ob)
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
    os.makedirs(os.path.join(out_dir, "tower"), exist_ok=True)
    sc.render.filepath = os.path.join(out_dir, "tower", "tower.png")
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = argv[0] if argv else os.path.join(os.getcwd(), "renders")
    subjects = argv[1:] or ["beret", "marine", "sniper", "guard", "tower"]
    for s in subjects:
        if s == "tower":
            render_tower(out_dir)
        else:
            render_character(s, out_dir)
        print(f"HFM_RENDERED {s}")


main()
