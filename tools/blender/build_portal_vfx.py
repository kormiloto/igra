"""Build an editable, animated 360-degree plasma fog portal in Blender.

Run from Blender after the BlenderKit material named "Green Portal shader"
has been downloaded.  The source material is retained in the file as a visual
reference; the final effect remaps its green energy language onto spherical,
seamless procedural coordinates so it works from every approach direction.
"""

import bpy
import math
import os
from mathutils import Vector


ROOT = r"C:\Users\korisnik\Documents\Kulaworld"
BLEND_PATH = os.path.join(ROOT, "assets", "source", "blender", "skyroll_plasma_fog_portal.blend")
PREVIEW_PATH = os.path.join(ROOT, "output", "blender_plasma_fog_portal.png")
GLB_PATH = os.path.join(ROOT, "assets", "3d", "environment", "portal_plasma_fog.glb")
SOURCE_MATERIAL = "Green Portal shader"


def clear_scene_objects():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in list(bpy.data.collections):
        if collection.name.startswith(("PORTAL_VFX_360", "SOURCE_ASSET_REFERENCE")):
            bpy.data.collections.remove(collection)
    for material in list(bpy.data.materials):
        if material.name.startswith(("Plasma_Fog_Layer_", "Selected_Green_Energy_Sparks", "Pedestal_Dark_Stone")):
            bpy.data.materials.remove(material)
    for texture in list(bpy.data.textures):
        if texture.name.startswith("Plasma_Fog_Sphere_"):
            bpy.data.textures.remove(texture)


def socket(node, names):
    for name in names:
        if name in node.inputs:
            return node.inputs[name]
    raise KeyError(f"Missing socket {names} on {node.name}")


def add_driver(socket_value, expression, index=None):
    fcurve = socket_value.driver_add("default_value", index) if index is not None else socket_value.driver_add("default_value")
    fcurve.driver.expression = expression


def make_plasma_material(name, color, scale, density, speed, detail):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.surface_render_method = "DITHERED"
    mat.use_transparency_overlap = False
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (720, 0)
    mix = nodes.new("ShaderNodeMixShader")
    mix.location = (500, 0)
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    transparent.location = (270, -120)
    emission = nodes.new("ShaderNodeEmission")
    emission.location = (270, 100)
    emission.inputs["Color"].default_value = (*color, 1.0)
    emission.inputs["Strength"].default_value = 2.15

    texcoord = nodes.new("ShaderNodeTexCoord")
    texcoord.location = (-900, 20)
    noise_large = nodes.new("ShaderNodeTexNoise")
    noise_large.noise_dimensions = "4D"
    noise_large.location = (-670, 130)
    noise_large.inputs["Scale"].default_value = scale
    noise_large.inputs["Detail"].default_value = detail
    noise_large.inputs["Roughness"].default_value = 0.72
    noise_large.inputs["Distortion"].default_value = 0.36
    add_driver(noise_large.inputs["W"], f"frame*{speed:.7f}")

    noise_fine = nodes.new("ShaderNodeTexNoise")
    noise_fine.noise_dimensions = "4D"
    noise_fine.location = (-660, -180)
    noise_fine.inputs["Scale"].default_value = scale * 3.4
    noise_fine.inputs["Detail"].default_value = 4.0
    noise_fine.inputs["Roughness"].default_value = 0.8
    add_driver(noise_fine.inputs["W"], f"frame*{-speed * 1.65:.7f}")

    multiply = nodes.new("ShaderNodeMath")
    multiply.operation = "MULTIPLY"
    multiply.location = (-350, 40)
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.location = (-110, 30)
    ramp.color_ramp.elements[0].position = 0.14 + density * 0.05
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.46 - density * 0.05
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)

    links.new(texcoord.outputs["Generated"], noise_large.inputs["Vector"])
    links.new(texcoord.outputs["Generated"], noise_fine.inputs["Vector"])
    links.new(noise_large.outputs["Fac"], multiply.inputs[0])
    links.new(noise_fine.outputs["Fac"], multiply.inputs[1])
    links.new(multiply.outputs[0], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs["Surface"])

    mat.diffuse_color = (*color, 0.65)
    mat["source_asset"] = SOURCE_MATERIAL
    mat["design"] = "Seamless 360 degree plasma fog; no central hole"
    return mat


def add_plasma_sphere(collection, name, radius, material, rotation, displacement):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=radius, location=(0, 0, 1.35))
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = rotation
    for old_collection in list(obj.users_collection):
        old_collection.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(material)
    for poly in obj.data.polygons:
        poly.use_smooth = True

    texture = bpy.data.textures.new(f"{name}_OrganicShape", type="CLOUDS")
    texture.noise_scale = 0.38
    texture.noise_depth = 2
    modifier = obj.modifiers.new("Chaotic soft boundary", "DISPLACE")
    modifier.texture = texture
    modifier.strength = displacement
    modifier.texture_coords = "GLOBAL"
    modifier.mid_level = 0.5
    obj["animation_note"] = "Material Noise W is driver-animated from frame"
    return obj


def make_spark_material():
    mat = bpy.data.materials.new("Selected_Green_Energy_Sparks")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    socket(bsdf, ("Base Color",)).default_value = (0.01, 0.42, 0.025, 1)
    socket(bsdf, ("Emission Color", "Emission")).default_value = (0.02, 1.0, 0.055, 1)
    socket(bsdf, ("Emission Strength",)).default_value = 8.0
    socket(bsdf, ("Roughness",)).default_value = 0.25
    return mat


def add_sparks(collection):
    mat = make_spark_material()
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(34):
        y = 1.0 - (i / 33.0) * 2.0
        radial = math.sqrt(max(0.0, 1.0 - y * y))
        theta = golden * i
        direction = Vector((math.cos(theta) * radial, math.sin(theta) * radial, y))
        distance = 1.05 + 0.14 * math.sin(i * 2.73)
        location = Vector((0, 0, 1.35)) + direction * distance
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.018 + 0.016 * ((i * 7) % 5) / 4, location=location)
        obj = bpy.context.object
        obj.name = f"Plasma_Spark_{i:02d}"
        for old_collection in list(obj.users_collection):
            old_collection.objects.unlink(obj)
        collection.objects.link(obj)
        obj.data.materials.append(mat)
        phase = (i * 11) % 48
        obj.scale = (0.25, 0.25, 0.25)
        obj.keyframe_insert("scale", frame=1 + phase)
        obj.scale = (1.0, 1.0, 1.0)
        obj.keyframe_insert("scale", frame=13 + phase)
        obj.scale = (0.25, 0.25, 0.25)
        obj.keyframe_insert("scale", frame=25 + phase)


def add_pedestal(collection):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=1.34, depth=0.26, location=(0, 0, 0.08))
    obj = bpy.context.object
    obj.name = "Portal_Preview_Pedestal"
    for old_collection in list(obj.users_collection):
        old_collection.objects.unlink(obj)
    collection.objects.link(obj)
    mat = bpy.data.materials.new("Pedestal_Dark_Stone")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.018, 0.028, 0.034, 1)
    bsdf.inputs["Metallic"].default_value = 0.35
    bsdf.inputs["Roughness"].default_value = 0.38
    obj.data.materials.append(mat)


def setup_scene():
    source = bpy.data.materials.get(SOURCE_MATERIAL)
    if source is None:
        raise RuntimeError(f"Required BlenderKit material not loaded: {SOURCE_MATERIAL}")

    clear_scene_objects()
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 120
    scene.frame_set(34)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = PREVIEW_PATH
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.world.color = (0.003, 0.008, 0.012)
    scene.view_settings.look = "AgX - Medium High Contrast"

    world = scene.world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.004, 0.012, 0.018, 1)
    bg.inputs["Strength"].default_value = 0.12

    portal = bpy.data.collections.new("PORTAL_VFX_360")
    scene.collection.children.link(portal)
    palette = [
        ((0.005, 1.0, 0.0), 2.6, 0.76, 0.0105, 5.0),
        ((0.00, 0.70, 0.05), 3.8, 0.66, -0.0080, 6.0),
        ((0.22, 1.00, 0.44), 6.8, 0.60, 0.0130, 4.0),
    ]
    radii = (1.06, 0.94, 0.79)
    displacements = (0.23, 0.16, 0.11)
    rotations = ((0.1, 0.0, 0.0), (0.0, 0.9, 0.35), (0.7, 0.2, 1.1))
    for i, (params, radius, disp, rot) in enumerate(zip(palette, radii, displacements, rotations), 1):
        color, scale, density, speed, detail = params
        mat = make_plasma_material(f"Plasma_Fog_Layer_{i}", color, scale, density, speed, detail)
        add_plasma_sphere(portal, f"Plasma_Fog_Sphere_{i}", radius, mat, rot, disp)
    add_sparks(portal)
    add_pedestal(portal)

    reference = bpy.data.collections.new("SOURCE_ASSET_REFERENCE")
    scene.collection.children.link(reference)
    reference.hide_render = True
    reference.hide_viewport = True
    bpy.ops.mesh.primitive_plane_add(size=2)
    ref = bpy.context.object
    ref.name = "BlenderKit_Green_Portal_Shader_REFERENCE"
    for old_collection in list(ref.users_collection):
        old_collection.objects.unlink(ref)
    reference.objects.link(ref)
    ref.data.materials.append(source)
    ref["asset_base_id"] = "ddf31609-fc9b-497f-803e-fb79bce5539a"

    bpy.ops.object.camera_add(location=(4.25, -5.15, 3.25))
    camera = bpy.context.object
    camera.name = "Portal_Preview_Camera"
    scene.camera = camera
    direction = Vector((0, 0, 1.25)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 58

    bpy.ops.object.light_add(type="AREA", location=(2.8, -2.2, 4.8))
    key = bpy.context.object
    key.name = "Soft_Key_Light"
    key.data.energy = 550
    key.data.shape = "DISK"
    key.data.size = 4.0
    key.data.color = (0.18, 0.42, 0.50)

    scene["selected_blenderkit_asset"] = "Green Portal shader"
    scene["selected_blenderkit_asset_id"] = "ddf31609-fc9b-497f-803e-fb79bce5539a"
    scene["portal_usage"] = "Animated 360 degree plasma fog volume, no hole, universal entry direction"

    os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
    os.makedirs(os.path.dirname(PREVIEW_PATH), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    bpy.ops.render.render(write_still=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.data.objects:
        if obj.name.startswith("Plasma_Fog_Sphere_"):
            obj.hide_viewport = False
            obj.hide_render = False
            obj.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects.get("Plasma_Fog_Sphere_1")
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
    )
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    print(f"PORTAL_BLEND={BLEND_PATH}")
    print(f"PORTAL_PREVIEW={PREVIEW_PATH}")
    print(f"PORTAL_GLB={GLB_PATH}")


setup_scene()
