"""Render the Skyroll portal as a transparent Blender-authored flipbook."""

import bpy
import math
import os
import random
import sys
from mathutils import Vector


ROOT = r"C:\Users\korisnik\Documents\Kulaworld"
OUT_DIR = os.path.join(ROOT, "assets", "vfx", "portal_flipbook")
BLEND_PATH = os.path.join(ROOT, "assets", "source", "blender", "skyroll_portal_flipbook.blend")
PREVIEW_PATH = os.path.join(ROOT, "output", "portal_flipbook_blender_preview.png")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.materials, bpy.data.curves, bpy.data.meshes, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def emission_material(name, color, strength):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (*color, 1.0)
    emission.inputs["Strength"].default_value = strength
    links.new(emission.outputs[0], output.inputs["Surface"])
    return material


def volume_material():
    material = bpy.data.materials.new("Portal_Volumetric_Plasma")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (720, 0)
    volume = nodes.new("ShaderNodeVolumePrincipled")
    volume.location = (470, 0)
    volume.inputs["Color"].default_value = (0.002, 0.10, 0.012, 1.0)
    volume.inputs["Emission Color"].default_value = (0.005, 0.48, 0.035, 1.0)
    volume.inputs["Anisotropy"].default_value = 0.18

    texcoord = nodes.new("ShaderNodeTexCoord")
    texcoord.location = (-1050, 60)
    noise = nodes.new("ShaderNodeTexNoise")
    noise.noise_dimensions = "4D"
    noise.location = (-820, 190)
    noise.inputs["Scale"].default_value = 3.1
    noise.inputs["Detail"].default_value = 7.0
    noise.inputs["Roughness"].default_value = 0.72
    noise.inputs["Distortion"].default_value = 0.55
    noise.inputs["W"].driver_add("default_value").driver.expression = "frame*0.075"

    fine = nodes.new("ShaderNodeTexNoise")
    fine.noise_dimensions = "4D"
    fine.location = (-820, -60)
    fine.inputs["Scale"].default_value = 10.0
    fine.inputs["Detail"].default_value = 4.0
    fine.inputs["Roughness"].default_value = 0.78
    fine.inputs["W"].driver_add("default_value").driver.expression = "-frame*0.11"

    multiply_noise = nodes.new("ShaderNodeMath")
    multiply_noise.operation = "MULTIPLY"
    multiply_noise.location = (-570, 110)
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.location = (-350, 120)
    ramp.color_ramp.elements[0].position = 0.18
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.54
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)

    distance = nodes.new("ShaderNodeVectorMath")
    distance.operation = "DISTANCE"
    distance.location = (-780, -300)
    distance.inputs[1].default_value = (0.5, 0.5, 0.5)
    edge_fade = nodes.new("ShaderNodeMapRange")
    edge_fade.location = (-530, -270)
    edge_fade.clamp = True
    edge_fade.inputs["From Min"].default_value = 0.28
    edge_fade.inputs["From Max"].default_value = 0.50
    edge_fade.inputs["To Min"].default_value = 1.0
    edge_fade.inputs["To Max"].default_value = 0.0

    density = nodes.new("ShaderNodeMath")
    density.operation = "MULTIPLY"
    density.location = (-95, 80)
    density_boost = nodes.new("ShaderNodeMath")
    density_boost.operation = "MULTIPLY"
    density_boost.inputs[1].default_value = 0.018
    density_boost.location = (120, 95)
    emission_boost = nodes.new("ShaderNodeMath")
    emission_boost.operation = "MULTIPLY"
    emission_boost.inputs[1].default_value = 0.065
    emission_boost.location = (120, -65)

    links.new(texcoord.outputs["Generated"], noise.inputs["Vector"])
    links.new(texcoord.outputs["Generated"], fine.inputs["Vector"])
    links.new(noise.outputs["Fac"], multiply_noise.inputs[0])
    links.new(fine.outputs["Fac"], multiply_noise.inputs[1])
    links.new(multiply_noise.outputs[0], ramp.inputs["Fac"])
    links.new(texcoord.outputs["Generated"], distance.inputs[0])
    links.new(distance.outputs["Value"], edge_fade.inputs["Value"])
    links.new(ramp.outputs["Color"], density.inputs[0])
    links.new(edge_fade.outputs["Result"], density.inputs[1])
    links.new(density.outputs[0], density_boost.inputs[0])
    links.new(density.outputs[0], emission_boost.inputs[0])
    links.new(density_boost.outputs[0], volume.inputs["Density"])
    links.new(emission_boost.outputs[0], volume.inputs["Emission Strength"])
    links.new(volume.outputs[0], output.inputs["Volume"])
    return material


def plasma_shell_material():
    material = bpy.data.materials.new("Portal_Noise_Cutout_Shell")
    material.use_nodes = True
    material.surface_render_method = "DITHERED"
    material.use_transparency_overlap = False
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    mix = nodes.new("ShaderNodeMixShader")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (0.006, 0.62, 0.035, 1.0)
    emission.inputs["Strength"].default_value = 1.7
    texcoord = nodes.new("ShaderNodeTexCoord")
    broad = nodes.new("ShaderNodeTexNoise")
    broad.noise_dimensions = "4D"
    broad.inputs["Scale"].default_value = 3.4
    broad.inputs["Detail"].default_value = 8.0
    broad.inputs["Roughness"].default_value = 0.76
    broad.inputs["Distortion"].default_value = 0.55
    broad.inputs["W"].driver_add("default_value").driver.expression = "frame*0.082"
    fine = nodes.new("ShaderNodeTexNoise")
    fine.noise_dimensions = "4D"
    fine.inputs["Scale"].default_value = 9.5
    fine.inputs["Detail"].default_value = 5.0
    fine.inputs["Roughness"].default_value = 0.8
    fine.inputs["W"].driver_add("default_value").driver.expression = "-frame*0.13"
    multiply = nodes.new("ShaderNodeMath")
    multiply.operation = "MULTIPLY"
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.30
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.50
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    links.new(texcoord.outputs["Generated"], broad.inputs["Vector"])
    links.new(texcoord.outputs["Generated"], fine.inputs["Vector"])
    links.new(broad.outputs["Fac"], multiply.inputs[0])
    links.new(fine.outputs["Fac"], multiply.inputs[1])
    links.new(multiply.outputs[0], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs["Surface"])
    return material


def add_volume():
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=1.0)
    obj = bpy.context.object
    obj.name = "Portal_Animated_Volume"
    obj.scale = (1.0, 1.0, 1.0)
    obj.data.materials.append(volume_material())
    obj.hide_render = True

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=1.025)
    shell = bpy.context.object
    shell.name = "Portal_Animated_Noise_Shell"
    outer_material = plasma_shell_material()
    shell.data.materials.append(outer_material)
    texture = bpy.data.textures.new("Portal_Organic_Boundary", type="CLOUDS")
    texture.noise_scale = 0.34
    texture.noise_depth = 2
    modifier = shell.modifiers.new("Organic plasma silhouette", "DISPLACE")
    modifier.texture = texture
    modifier.strength = 0.16
    modifier.mid_level = 0.5

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=0.88)
    inner = bpy.context.object
    inner.name = "Portal_Inner_Cloud_Shell"
    inner.rotation_euler = (0.42, 0.73, 0.21)
    inner_material = plasma_shell_material()
    inner_material.name = "Portal_Inner_Cloud_Material"
    inner_emission = next(node for node in inner_material.node_tree.nodes if node.bl_idname == "ShaderNodeEmission")
    inner_emission.inputs["Color"].default_value = (0.002, 0.30, 0.018, 1.0)
    inner_emission.inputs["Strength"].default_value = 0.85
    inner_ramp = next(node for node in inner_material.node_tree.nodes if node.bl_idname == "ShaderNodeValToRGB")
    inner_ramp.color_ramp.elements[0].position = 0.14
    inner_ramp.color_ramp.elements[1].position = 0.44
    inner.data.materials.append(inner_material)


def add_filaments(parent):
    random.seed(260818)
    material = emission_material("Portal_Electric_Filaments", (0.01, 0.52, 0.055), 1.45)
    for index in range(12):
        curve = bpy.data.curves.new(f"PlasmaFilament_{index:02d}", "CURVE")
        curve.dimensions = "3D"
        curve.resolution_u = 2
        curve.bevel_depth = 0.004 + random.random() * 0.004
        curve.bevel_resolution = 2
        spline = curve.splines.new("POLY")
        point_count = 8
        spline.points.add(point_count - 1)
        start = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))).normalized()
        tangent = start.cross(Vector((random.random(), random.random(), random.random())).normalized()).normalized()
        bitangent = start.cross(tangent).normalized()
        arc = random.uniform(0.42, 0.95)
        for point_index, point in enumerate(spline.points):
            t = point_index / (point_count - 1) - 0.5
            direction = (start + tangent * math.sin(t * arc) + bitangent * math.sin(t * arc * 2.1) * 0.10).normalized()
            radius = 0.92 + 0.055 * math.sin(point_index * 2.3 + index)
            coordinate = direction * radius
            point.co = (*coordinate, 1.0)
        obj = bpy.data.objects.new(f"PlasmaFilament_{index:02d}", curve)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(material)
        obj.parent = parent


def add_sparks(parent):
    random.seed(180826)
    material = emission_material("Portal_Sparks", (0.08, 0.72, 0.12), 2.8)
    for index in range(24):
        direction = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))).normalized()
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=random.uniform(0.010, 0.025), location=direction * random.uniform(0.92, 1.13))
        obj = bpy.context.object
        obj.name = f"PortalSpark_{index:02d}"
        obj.data.materials.append(material)
        obj.parent = parent
        phase = index % 16 + 1
        obj.scale = Vector((0.2, 0.2, 0.2))
        obj.keyframe_insert("scale", frame=phase)
        obj.scale = Vector((1.0, 1.0, 1.0))
        obj.keyframe_insert("scale", frame=phase + 5)
        obj.scale = Vector((0.2, 0.2, 0.2))
        obj.keyframe_insert("scale", frame=phase + 10)


def setup_scene():
    clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.frame_start = 1
    scene.frame_end = 8
    scene.render.resolution_x = 288
    scene.render.resolution_y = 288
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.filepath = os.path.join(OUT_DIR, "portal_")
    scene.view_settings.look = "AgX - Medium High Contrast"

    add_volume()
    parent = bpy.data.objects.new("Portal_Orbiting_Details", None)
    bpy.context.collection.objects.link(parent)
    parent.rotation_euler = (0.0, 0.0, 0.0)
    parent.keyframe_insert("rotation_euler", frame=1)
    parent.rotation_euler = (math.radians(24), math.radians(-18), math.tau)
    parent.keyframe_insert("rotation_euler", frame=9)
    add_filaments(parent)
    add_sparks(parent)

    bpy.ops.object.camera_add(location=(0, -5.0, 0))
    camera = bpy.context.object
    camera.name = "Portal_Flipbook_Camera"
    camera.rotation_euler = (math.radians(90), 0, 0)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.65
    scene.camera = camera

    world = scene.world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0, 0, 0, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0

    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    return scene


scene = setup_scene()
if "--animation" in sys.argv:
    bpy.ops.render.render(animation=True)
    print(f"PORTAL_FLIPBOOK={OUT_DIR}")
else:
    scene.frame_set(6)
    scene.render.filepath = PREVIEW_PATH
    bpy.ops.render.render(write_still=True)
    print(f"PORTAL_PREVIEW={PREVIEW_PATH}")
