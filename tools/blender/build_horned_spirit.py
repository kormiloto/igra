"""Build the original Skyroll Horned Spirit character from a visual reference."""

import bpy
import math
import os
from mathutils import Vector


ROOT = r"C:\Users\korisnik\Documents\Kulaworld"
REFERENCE = r"C:\Users\korisnik\AppData\Local\Temp\codex-clipboard-ff86572a-e128-4949-a7d5-2daa2343b5c1.png"
BLEND_PATH = os.path.join(ROOT, "assets", "source", "blender", "horned_spirit_character.blend")
GLB_PATH = os.path.join(ROOT, "assets", "3d", "environment", "aeri_horned_spirit.glb")
PREVIEW_PATH = os.path.join(ROOT, "output", "qa", "horned_spirit_closeup.png")


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)


def material(name, color, roughness, metallic=0.0, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def move_to_collection(obj, collection):
    for source in list(obj.users_collection):
        source.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def smooth(obj):
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    return obj


def uv_part(collection, name, location, scale, mat, segments=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    move_to_collection(obj, collection)
    return smooth(obj)


def curve_part(collection, name, points, radii, bevel, mat):
    curve = bpy.data.curves.new(name + "_Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 3
    curve.bevel_depth = bevel
    curve.bevel_resolution = 4
    curve.resolution_u = 4
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, coordinate, radius in zip(spline.bezier_points, points, radii):
        point.co = coordinate
        point.radius = radius
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def cone_part(collection, name, location, radius1, radius2, depth, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=radius1, radius2=radius2, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move_to_collection(obj, collection)
    return smooth(obj)


def build_character():
    reset()
    scene = bpy.context.scene
    character = bpy.data.collections.new("HORNED_SPIRIT_CHARACTER")
    scene.collection.children.link(character)

    ivory = material("Mask_Ivory_Ceramic", (0.93, 0.95, 0.92, 1), 0.24, 0.02)
    ivory_edge = material("Horn_Pearl_Tips", (0.93, 0.96, 0.93, 1), 0.22, 0.01)
    eye_black = material("Eyes_Deep_Glass", (0.002, 0.003, 0.005, 1), 0.08, 0.12)
    body_black = material("Body_Void_Silk", (0.008, 0.012, 0.018, 1), 0.52, 0.0)
    mane_blue = material("Mane_Deep_Indigo", (0.025, 0.12, 0.32, 1), 0.32, 0.08)
    mane_edge = material("Mane_Cobalt_Edge", (0.025, 0.30, 0.70, 1), 0.26, 0.10)
    glow = material("Spirit_Cyan_Accent", (0.01, 0.20, 0.24, 1), 0.28, 0.05, (0.02, 0.70, 0.84, 1), 2.6)

    # Compact body stays within the existing spherical gameplay collider.
    uv_part(character, "Void_Torso", (0, 0, -0.27), (0.27, 0.22, 0.40), body_black, 40, 20)
    cone_part(character, "Left_Leg", (-0.13, 0.0, -0.59), 0.095, 0.045, 0.34, body_black, (0, math.radians(-7), 0))
    cone_part(character, "Right_Leg", (0.13, 0.0, -0.59), 0.095, 0.045, 0.34, body_black, (0, math.radians(7), 0))

    # Rounded mask, slightly wider at the brow than at the chin.
    head = uv_part(character, "Ivory_Mask", (0, 0.015, 0.17), (0.50, 0.40, 0.47), ivory, 64, 32)
    bevel = head.modifiers.new("Soft mask finish", "BEVEL")
    bevel.width = 0.025
    bevel.segments = 3

    # Deep inset eyes face Blender +Y, which exports as the Godot forward direction.
    for side in (-1, 1):
        eye = uv_part(character, "Eye_L" if side < 0 else "Eye_R", (0.19 * side, 0.392, 0.15), (0.125, 0.035, 0.185), eye_black, 48, 24)
        eye.rotation_euler.z = math.radians(-6 * side)
        rim = uv_part(character, "Eye_Rim_L" if side < 0 else "Eye_Rim_R", (0.19 * side, 0.375, 0.15), (0.145, 0.022, 0.205), ivory_edge, 48, 24)
        rim.rotation_euler.z = math.radians(-6 * side)
        # Keep the black glass just in front of its pale inset rim.
        eye.location.y += 0.024

    # Swept horns: broad at the mask, tapered and asymmetric at their tips.
    left_points = [(-0.31, 0.0, 0.48), (-0.48, 0.0, 0.64), (-0.52, 0.0, 0.86), (-0.42, 0.0, 1.04), (-0.31, 0.0, 1.13)]
    right_points = [(0.31, 0.0, 0.48), (0.47, 0.0, 0.67), (0.51, 0.0, 0.90), (0.42, 0.0, 1.07), (0.33, 0.0, 1.16)]
    curve_part(character, "Horn_Left", left_points, [1.25, 1.12, 0.82, 0.48, 0.08], 0.105, ivory)
    curve_part(character, "Horn_Right", right_points, [1.25, 1.12, 0.82, 0.48, 0.08], 0.105, ivory)

    # Layered scarf/mane made from tapered swept strands instead of a flat collar.
    strand_count = 18
    for index in range(strand_count):
        angle = (float(index) / strand_count) * math.tau
        front_weight = 0.88 + 0.20 * max(0.0, math.sin(angle))
        start = Vector((math.cos(angle) * 0.30, math.sin(angle) * 0.25, -0.12))
        mid = Vector((math.cos(angle) * 0.48, math.sin(angle) * 0.39, -0.20 - 0.04 * (index % 3)))
        end = Vector((math.cos(angle + 0.16) * 0.62, math.sin(angle + 0.16) * 0.50, -0.29 + 0.045 * ((index + 1) % 4)))
        mat = mane_edge if index % 4 == 0 else mane_blue
        curve_part(character, f"Mane_Strand_{index:02d}", [start, mid, end], [1.05 * front_weight, 0.70, 0.05], 0.062, mat)

    # A small chest jewel gives the character its own Skyroll identity.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.075, location=(0, 0.225, -0.31))
    jewel = bpy.context.object
    jewel.name = "Skyroll_Spirit_Core"
    jewel.scale = (0.78, 0.34, 1.12)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    jewel.data.materials.append(glow)
    move_to_collection(jewel, character)
    smooth(jewel)

    # Curves must become meshes for stable glTF export.
    for obj in list(character.objects):
        if obj.type == "CURVE":
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.object.convert(target="MESH")
            obj.select_set(False)

    root = bpy.data.objects.new("HornedSpirit_Root", None)
    character.objects.link(root)
    root["character_name"] = "Aeri, Horned Spirit"
    root["reference_note"] = "Original Skyroll adaptation from user-provided horned-mask reference"
    for obj in character.objects:
        if obj is not root and obj.parent is None:
            obj.parent = root

    # Pack the supplied image into the editable Blender source as a hidden reference.
    if os.path.exists(REFERENCE):
        image = bpy.data.images.load(REFERENCE, check_existing=True)
        image.pack()
        ref = bpy.data.objects.new("REFERENCE_Horned_Mask_Character", None)
        ref.empty_display_type = "IMAGE"
        ref.data = image
        ref.hide_render = True
        ref.hide_viewport = True
        ref.location = (0, -1.6, 0.2)
        character.objects.link(ref)

    return character, root


def export_character(character, root):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in character.objects:
        if obj.type == "MESH" or obj is root:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
    )


def preview(character):
    scene = bpy.context.scene
    preview_collection = bpy.data.collections.new("PREVIEW_ONLY")
    scene.collection.children.link(preview_collection)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.82, depth=0.14, location=(0, 0, -0.79))
    pedestal = bpy.context.object
    pedestal.name = "Preview_Pedestal"
    move_to_collection(pedestal, preview_collection)
    pedestal.data.materials.append(material("Preview_Obsidian", (0.01, 0.018, 0.03, 1), 0.28, 0.42))

    bpy.ops.object.camera_add(location=(2.45, 4.65, 1.75))
    camera = bpy.context.object
    move_to_collection(camera, preview_collection)
    direction = Vector((0, 0, 0.16)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 68
    scene.camera = camera

    for name, location, energy, size, color in (
        ("Key", (2.6, 2.8, 4.0), 950, 3.0, (0.72, 0.86, 1.0)),
        ("Rim", (-2.8, -1.2, 2.8), 780, 2.2, (0.12, 0.34, 1.0)),
        ("Fill", (-1.8, 3.2, 0.2), 420, 2.6, (0.48, 0.64, 1.0)),
    ):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        move_to_collection(light, preview_collection)
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.data.color = color

    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = PREVIEW_PATH
    scene.render.film_transparent = False
    scene.world.color = (0.08, 0.28, 0.52)
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.045, 0.22, 0.48, 1)
    bg.inputs["Strength"].default_value = 0.32
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.render.render(write_still=True)


os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
os.makedirs(os.path.dirname(GLB_PATH), exist_ok=True)
os.makedirs(os.path.dirname(PREVIEW_PATH), exist_ok=True)
character_collection, character_root = build_character()
export_character(character_collection, character_root)
preview(character_collection)
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
print(f"CHARACTER_BLEND={BLEND_PATH}")
print(f"CHARACTER_GLB={GLB_PATH}")
print(f"CHARACTER_PREVIEW={PREVIEW_PATH}")
