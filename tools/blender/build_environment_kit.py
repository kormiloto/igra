"""Build Project Skyroll's complete sale-ready environment kit.

The generator deliberately favors authored silhouettes, readable gameplay
materials, and deterministic low-poly geometry over opaque AI-generated 3D.
It exports every runtime model, verifies budgets, renders a visual QA sheet,
and saves the editable Blender source used to reproduce the release assets.
"""

from __future__ import annotations

import json
import math
import random
import shutil
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets" / "source" / "blender"
OUTPUT_DIR = ROOT / "assets" / "3d" / "environment"
PREVIEW_DIR = ROOT / "assets" / "3d" / "previews"
UI_DIR = ROOT / "assets" / "ui"
QA_DIR = ROOT / "output" / "qa"
REFERENCE_DIR = ROOT / "assets" / "source" / "design_refs" / "realistic_game_assets"
MANIFEST_PATH = ROOT / "tools" / "blender" / "asset_manifest.json"

for directory in (SOURCE_DIR, OUTPUT_DIR, PREVIEW_DIR, UI_DIR, QA_DIR):
    directory.mkdir(parents=True, exist_ok=True)

with MANIFEST_PATH.open("r", encoding="utf-8") as handle:
    MANIFEST = json.load(handle)

BUDGETS = {item["name"]: item for item in MANIFEST["outputs"]}
REPORT: list[dict[str, object]] = []


def verify_design_references() -> None:
    refs = sorted(REFERENCE_DIR.glob("*.jpg"))
    if len(refs) < 15:
        raise RuntimeError(f"Expected 15 realistic design references in {REFERENCE_DIR}, found {len(refs)}")
    print(f"Verified {len(refs)} realistic design references for the Blender art pass.")


def clean_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.metaballs,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def set_input(shader: bpy.types.Node, names: tuple[str, ...], value) -> None:
    for name in names:
        socket = shader.inputs.get(name)
        if socket is not None:
            socket.default_value = value
            return


def material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float,
    metallic: float = 0.0,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
    alpha: float = 1.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color[:3], alpha)
    mat.use_backface_culling = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    set_input(shader, ("Base Color",), (*color[:3], alpha))
    set_input(shader, ("Roughness",), roughness)
    set_input(shader, ("Metallic",), metallic)
    set_input(shader, ("Alpha",), alpha)
    if emission is not None:
        set_input(shader, ("Emission Color", "Emission"), emission)
        set_input(shader, ("Emission Strength",), emission_strength)
    if alpha < 1.0:
        try:
            mat.surface_render_method = "DITHERED"
        except (AttributeError, TypeError):
            pass
    return mat


def attach_albedo_texture(mat: bpy.types.Material, path: Path, label: str) -> None:
    """Use a generated photoreal albedo map while retaining authored material response."""
    if not path.exists():
        raise FileNotFoundError(f"Missing generated albedo texture: {path}")
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    shader = nodes.get("Principled BSDF")
    if shader is None:
        return
    image = bpy.data.images.load(str(path), check_existing=True)
    image.colorspace_settings.name = "sRGB"
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = label
    texture.label = label
    texture.image = image
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    texture.location = (-420, 220)
    links.new(texture.outputs["Color"], shader.inputs["Base Color"])


def pbr_material(
    name: str,
    diffuse_path: Path,
    normal_path: Path,
    roughness_path: Path,
    ao_path: Path,
    scale: float,
) -> bpy.types.Material:
    """Create a compact glTF-friendly PBR material from checksum-pinned maps."""
    for path in (diffuse_path, normal_path, roughness_path, ao_path):
        if not path.exists():
            raise FileNotFoundError(f"Missing required PBR map: {path}")
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    texcoord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (scale, scale, scale)
    links.new(texcoord.outputs["UV"], mapping.inputs["Vector"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])

    diffuse = nodes.new("ShaderNodeTexImage")
    diffuse.image = bpy.data.images.load(str(diffuse_path), check_existing=True)
    diffuse.image.colorspace_settings.name = "sRGB"
    ao = nodes.new("ShaderNodeTexImage")
    ao.image = bpy.data.images.load(str(ao_path), check_existing=True)
    ao.image.colorspace_settings.name = "Non-Color"
    mix = nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 0.72
    links.new(mapping.outputs["Vector"], diffuse.inputs["Vector"])
    links.new(mapping.outputs["Vector"], ao.inputs["Vector"])
    links.new(diffuse.outputs["Color"], mix.inputs[1])
    links.new(ao.outputs["Color"], mix.inputs[2])
    links.new(mix.outputs["Color"], shader.inputs["Base Color"])

    roughness = nodes.new("ShaderNodeTexImage")
    roughness.image = bpy.data.images.load(str(roughness_path), check_existing=True)
    roughness.image.colorspace_settings.name = "Non-Color"
    links.new(mapping.outputs["Vector"], roughness.inputs["Vector"])
    links.new(roughness.outputs["Color"], shader.inputs["Roughness"])

    normal_texture = nodes.new("ShaderNodeTexImage")
    normal_texture.image = bpy.data.images.load(str(normal_path), check_existing=True)
    normal_texture.image.colorspace_settings.name = "Non-Color"
    normal = nodes.new("ShaderNodeNormalMap")
    normal.inputs["Strength"].default_value = 1.18
    links.new(mapping.outputs["Vector"], normal_texture.inputs["Vector"])
    links.new(normal_texture.outputs["Color"], normal.inputs["Color"])
    links.new(normal.outputs["Normal"], shader.inputs["Normal"])
    return mat


def append_source_object(source_path: Path, object_name: str) -> bpy.types.Object:
    if not source_path.exists():
        raise FileNotFoundError(f"Missing approved Blender source: {source_path}")
    with bpy.data.libraries.load(str(source_path), link=False) as (source_data, target_data):
        if object_name not in source_data.objects:
            raise RuntimeError(f"Object {object_name} was not found in {source_path}")
        target_data.objects = [object_name]
    obj = target_data.objects[0]
    if obj is None:
        raise RuntimeError(f"Could not append {object_name} from {source_path}")
    bpy.context.collection.objects.link(obj)
    return obj


def load_pbr_material_from_blend(source_path: Path, source_name: str, runtime_name: str) -> bpy.types.Material:
    """Load an approved PBR material and prepare compact runtime textures."""
    if not source_path.exists():
        raise FileNotFoundError(f"Missing PBR source blend: {source_path}")
    with bpy.data.libraries.load(str(source_path), link=False) as (source_data, target_data):
        if source_name not in source_data.materials:
            raise RuntimeError(f"Material {source_name} was not found in {source_path}")
        target_data.materials = [source_name]
    mat = target_data.materials[0]
    if mat is None:
        raise RuntimeError(f"Could not load material {source_name} from {source_path}")
    mat.name = runtime_name
    mat.use_backface_culling = True
    if mat.use_nodes and mat.node_tree is not None:
        mapping = mat.node_tree.nodes.get("Mapping")
        if mapping is not None and mapping.inputs.get("Scale") is not None:
            mapping.inputs["Scale"].default_value = (1.35, 1.35, 1.35)
        normal = next((node for node in mat.node_tree.nodes if node.type == "NORMAL_MAP"), None)
        if normal is not None and normal.inputs.get("Strength") is not None:
            normal.inputs["Strength"].default_value = 1.35
        for node in mat.node_tree.nodes:
            image = getattr(node, "image", None)
            if image is not None and max(image.size) > 1024:
                image.scale(1024, 1024)
    return mat


def activate_only(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_set(False)
    obj.hide_render = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def add_stone_relief(obj: bpy.types.Object, seed: int, strength: float = 0.028, displacement_path: Path | None = None) -> None:
    """Add restrained physical relief while keeping gameplay silhouettes stable."""
    activate_only(obj)
    subdivision = obj.modifiers.new("W1_ReliefSubdivision", "SUBSURF")
    subdivision.subdivision_type = "SIMPLE"
    subdivision.levels = 2
    subdivision.render_levels = 2
    apply_modifier(obj, subdivision)
    if displacement_path is not None:
        if not displacement_path.exists():
            raise FileNotFoundError(f"Missing required displacement map: {displacement_path}")
        noise = bpy.data.textures.new(f"W1_RockyTerrainRelief_{seed}", type="IMAGE")
        noise.image = bpy.data.images.load(str(displacement_path), check_existing=True)
        noise.image.colorspace_settings.name = "Non-Color"
        noise.extension = "REPEAT"
    else:
        noise = bpy.data.textures.new(f"W1_RockRelief_{seed}", type="CLOUDS")
        noise.noise_scale = 0.24 + seed * 0.007
        noise.noise_depth = 2
    displacement = obj.modifiers.new("W1_PhysicalRockRelief", "DISPLACE")
    displacement.texture = noise
    displacement.texture_coords = "UV" if displacement_path is not None else "GLOBAL"
    displacement.strength = strength
    displacement.mid_level = 0.5
    apply_modifier(obj, displacement)


def smart_uv_project(obj: bpy.types.Object) -> bpy.types.Object:
    """Give joined procedural W1 geometry consistent rock-texture coverage."""
    activate_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.018)
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def apply_modifier(obj: bpy.types.Object, modifier: bpy.types.Modifier) -> None:
    activate_only(obj)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def smooth(obj: bpy.types.Object) -> None:
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = True


def add_mat(obj: bpy.types.Object, mat: bpy.types.Material) -> bpy.types.Object:
    obj.data.materials.append(mat)
    return obj


def cube(
    name: str,
    location: tuple[float, float, float],
    size: tuple[float, float, float],
    mat: bpy.types.Material,
    bevel: float = 0.04,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        mod = obj.modifiers.new("AuthoredEdgeWear", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        apply_modifier(obj, mod)
        smooth(obj)
    return add_mat(obj, mat)


def cylinder(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    mat: bpy.types.Material,
    vertices: int = 16,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.025,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    if bevel > 0.0:
        mod = obj.modifiers.new("MachinedBevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        apply_modifier(obj, mod)
    smooth(obj)
    return add_mat(obj, mat)


def cone(
    name: str,
    location: tuple[float, float, float],
    radius1: float,
    radius2: float,
    depth: float,
    mat: bpy.types.Material,
    vertices: int = 12,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    smooth(obj)
    return add_mat(obj, mat)


def sphere(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    mat: bpy.types.Material,
    segments: int = 24,
    rings: int = 12,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    smooth(obj)
    return add_mat(obj, mat)


def ico(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    mat: bpy.types.Material,
    subdivisions: int = 2,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    smooth(obj)
    return add_mat(obj, mat)


def torus(
    name: str,
    location: tuple[float, float, float],
    major_radius: float,
    minor_radius: float,
    mat: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    major_segments: int = 24,
    minor_segments: int = 8,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=major_segments,
        minor_segments=minor_segments,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    smooth(obj)
    return add_mat(obj, mat)


def flat_pentagon(
    name: str,
    normal: tuple[float, float, float],
    radius: float,
    mat: bpy.types.Material,
    surface_radius: float = 0.695,
    rotation_offset: float = math.pi / 2,
) -> bpy.types.Object:
    direction = Vector(normal).normalized()
    guide = Vector((0, 0, 1)) if abs(direction.z) < 0.92 else Vector((0, 1, 0))
    tangent = guide.cross(direction).normalized()
    bitangent = direction.cross(tangent).normalized()
    center = direction * surface_radius
    vertices = []
    for index in range(5):
        angle = rotation_offset + index / 5.0 * math.tau
        vertices.append(tuple(center + tangent * math.cos(angle) * radius + bitangent * math.sin(angle) * radius))
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], [(0, 1, 2, 3, 4)])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return add_mat(obj, mat)


def join_asset(name: str, parts: list[bpy.types.Object]) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj["skyroll_asset"] = name
    obj["collision"] = "none"
    return obj


def triangle_count(obj: bpy.types.Object) -> int:
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def create_temple_block(name: str, seed: int, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    rng = random.Random(seed * 71)
    base = cube(name, (0, 0, -0.03), (1.78, 1.78, 1.72), mats["w1_rocky"], 0.105)
    smart_uv_project(base)
    add_stone_relief(base, seed, 0.072, mats["w1_rocky_displacement"])
    top = cube("AncientPavingCap", (0, 0, 0.865), (1.73, 1.73, 0.13), mats["w1_rocky"], 0.055)
    parts = [base, top]
    # Shallow strata, broken corners, and restrained moss keep the collision
    # silhouette readable while avoiding a repeated perfect cube.
    for index, z in enumerate((-0.58, 0.50)):
        parts.append(cube(
            f"RockStratum{index}",
            (rng.uniform(-0.05, 0.05), -0.902, z),
            (1.42 + rng.uniform(-0.12, 0.12), 0.026, 0.045),
            mats["w1_rocky"],
            0.016,
            (0.0, 0.0, rng.uniform(-0.12, 0.12)),
        ))
    for index, (x, y, z) in enumerate(((-0.76, -0.76, 0.72), (0.77, 0.76, -0.70), (-0.78, 0.75, -0.04))):
        parts.append(ico(
            f"ChippedStone{index}",
            (x, y, z),
            (0.16, 0.13, 0.12),
            mats["w1_rocky"],
            1,
        ))
    moss_side = -1.0 if seed % 2 else 1.0
    for patch_index, (dx, dy, size) in enumerate(((0.0, 0.0, 0.20), (0.18, -0.08, 0.14), (-0.14, 0.10, 0.11))):
        parts.append(ico(
            f"MossTopPatch{patch_index}",
            (moss_side * 0.52 + dx, 0.48 + dy, 0.944),
            (size, size * 0.72, 0.014),
            mats["moss"],
            1,
        ))
    parts.append(cube("MossJoint", (moss_side * 0.895, 0.30, 0.36), (0.018, 0.28, 0.055), mats["moss"], 0.012, (0, 0, 0.18)))
    for index in range(3 + seed):
        x = moss_side * (0.91 + rng.uniform(-0.01, 0.01))
        y = 0.10 + index * 0.12 + rng.uniform(-0.03, 0.03)
        z = 0.18 - index * 0.17
        parts.append(ico(f"HangingLeaf{index}", (x, y, z), (0.020, 0.065, 0.105), mats["moss"], 1))
    return smart_uv_project(join_asset(name, parts))


def create_machine_block(name: str, seed: int, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    base = cube(name, (0, 0, 0), (1.74, 1.74, 1.74), mats["machine"], 0.16)
    parts = [base]
    edge = 0.075
    span = 1.56
    for a in (-0.78, 0.78):
        for b in (-0.78, 0.78):
            parts.extend([
                cube("BrassEdge", (0, a, b), (span, edge, edge), mats["brass"], 0.025),
                cube("CyanEdge", (a, 0, b), (edge, span, edge), mats["cyan"], 0.025),
                cube("BrassEdge", (a, b, 0), (edge, edge, span), mats["brass"], 0.025),
            ])
    return join_asset(name, parts)


def create_ember_block(name: str, seed: int, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    base = cube(name, (0, 0, 0), (1.79, 1.79, 1.79), mats["basalt"], 0.13)
    parts = [base]
    rng = random.Random(900 + seed)
    for face in (-1.0, 1.0):
        angle = rng.uniform(-0.55, 0.55)
        parts.append(cube("MagmaFissure", (0.12, face * 0.901, -0.05), (0.055, 0.022, 1.18), mats["lava"], 0.018, (0, angle, rng.uniform(-0.28, 0.28))))
        parts.append(cube("MagmaFissure", (face * 0.901, -0.18, 0.18), (0.022, 0.055, 0.92), mats["lava"], 0.018, (rng.uniform(-0.35, 0.35), 0, -angle)))
    return join_asset(name, parts)


def create_ice_tile(mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    parts = [cylinder("CrystalIceSurface", (0, 0, -0.10), 0.52, 0.055, mats["ice"], 12, bevel=0.018)]
    for index, (x, y, height) in enumerate(((-0.28, -0.18, 0.17), (0.18, -0.28, 0.24), (0.31, 0.18, 0.13), (-0.12, 0.31, 0.19))):
        parts.append(cone(f"IceRidge{index}", (x, y, -0.07 + height * 0.5), 0.07, 0.0, height, mats["ice_glow"], 6, (0.10 * index, 0.14 * (index - 1), 0)))
    return join_asset("w2_tile_ice", parts)


def create_hazard_tile(mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    parts = []
    for index, (x, y, height) in enumerate(((0, 0, 0.58), (-0.38, -0.30, 0.42), (0.38, -0.30, 0.42), (-0.38, 0.30, 0.42), (0.38, 0.30, 0.42))):
        # Jagged volcanic stone instead of smooth neon-yellow toy cones.
        parts.append(cone(f"HazardSpike{index}", (x, y, -0.10 + height * 0.5), 0.14 if index else 0.19, 0.025, height, mats["obsidian"], 7, (0.05 * index, -0.08 * index, 0.12 * index)))
        if index < 3:
            parts.append(cube(f"SpikeEmber{index}", (x + 0.025, y - 0.02, -0.10 + height * 0.38), (0.018, 0.012, height * 0.44), mats["lava_dark"], 0.006, (0.04 * index, 0.02, 0.10)))
        parts.append(torus(f"SpikeCollar{index}", (x, y, -0.09), 0.16 if index == 0 else 0.12, 0.022, mats["obsidian"], (0, 0, 0), 16, 5))
    return join_asset("w3_tile_hazard", parts)


def create_collapse_tile(mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    parts = []
    for index, (x, y, rotation) in enumerate(((-0.42, -0.42, -0.04), (0.42, -0.42, 0.05), (-0.42, 0.42, 0.07), (0.42, 0.42, -0.06))):
        parts.append(cube(f"FracturedSurface{index}", (x, y, -0.075), (0.72, 0.72, 0.06), mats["basalt"], 0.035, (0, 0, rotation)))
    parts.extend([
        cube("CollapseCrack", (0, 0, -0.04), (0.08, 1.30, 0.025), mats["lava"], 0.012, (0, 0, 0.14)),
        cube("CollapseCrack", (0, 0, -0.039), (1.25, 0.065, 0.025), mats["lava"], 0.012, (0, 0, -0.18)),
    ])
    return join_asset("w3_tile_collapse", parts)


def create_sky_core(mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    parts = [ico("sky_core", (0, 0, 0), (0.27, 0.27, 0.45), mats["core"], 3)]
    parts.append(ico("CoreInner", (0, 0, 0), (0.13, 0.13, 0.29), mats["core_hot"], 2))
    parts.append(torus("CoreOrbitHorizontal", (0, 0, 0), 0.43, 0.022, mats["core_ring"], (0, 0, 0), 28, 6))
    parts.append(torus("CoreOrbitTilted", (0, 0, 0), 0.43, 0.018, mats["core_ring"], (0.55, 0.20, 0.10), 28, 6))
    return join_asset("sky_core", parts)


def create_sunfruit(_mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    """Import the approved photoreal apple and normalize it for gameplay."""
    source_path = ROOT / "assets" / "source" / "models" / "polyhaven" / "food_apple_01_4k" / "food_apple_01_4k.blend"
    if not source_path.exists():
        raise RuntimeError(f"Missing approved Sunfruit source model: {source_path}")

    with bpy.data.libraries.load(str(source_path), link=False) as (source_data, target_data):
        if "food_apple_01" not in source_data.objects:
            raise RuntimeError(f"food_apple_01 was not found in {source_path}")
        target_data.objects = ["food_apple_01"]

    obj = target_data.objects[0]
    if obj is None or obj.type != "MESH":
        raise RuntimeError("The approved Sunfruit source is not a mesh object")
    bpy.context.collection.objects.link(obj)
    obj.name = "sunfruit"
    obj.data.name = "sunfruit_Mesh"
    obj.animation_data_clear()
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)

    bounds = [Vector(corner) for corner in obj.bound_box]
    center = sum(bounds, Vector()) / len(bounds)
    obj.data.transform(Matrix.Translation(-center))
    bpy.context.view_layer.update()
    diameter = max(float(axis) for axis in obj.dimensions)
    if diameter <= 0.0:
        raise RuntimeError("The approved Sunfruit source has invalid dimensions")
    scale = 0.80 / diameter
    obj.scale = (scale, scale, scale)
    activate_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # Preserve the authored silhouette while bringing the source under the
    # sale-ready Sunfruit triangle budget.
    decimate = obj.modifiers.new("Sunfruit_RuntimeOptimization", "DECIMATE")
    decimate.ratio = 0.47
    decimate.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=decimate.name)

    for material_slot in obj.material_slots:
        material = material_slot.material
        if material is None:
            continue
        material.name = "Sunfruit_Apple4K_Runtime"
        if not material.use_nodes or material.node_tree is None:
            continue
        for node in material.node_tree.nodes:
            image = getattr(node, "image", None)
            if image is not None and max(image.size) > 1024:
                image.scale(1024, 1024)

    return obj


def create_portal(name: str, palette: dict[str, bpy.types.Material]) -> bpy.types.Object:
    # The Blender asset supplies the physical frame. Animated plasma is added
    # by the runtime shader so it can flow and flicker like the VFX reference.
    if name == "portal_w1":
        parts = [cube(name, (0, 0, 0.07), (1.70, 0.82, 0.14), palette["base"], 0.08)]
        for x in (-0.58, 0.58):
            parts.extend([
                cube("AncientPortalPillar", (x, 0, 0.72), (0.30, 0.34, 1.32), palette["base"], 0.065, (0.0, 0.0, -0.035 if x < 0 else 0.035)),
                cube("AncientPortalCapital", (x, 0, 1.40), (0.43, 0.42, 0.19), palette["base"], 0.045),
            ])
        parts.extend([
            cube("BrokenPortalLintelLeft", (-0.35, 0, 1.55), (0.78, 0.38, 0.24), palette["base"], 0.055, (0, 0.03, 0.06)),
            cube("BrokenPortalLintelRight", (0.39, 0, 1.56), (0.66, 0.38, 0.24), palette["base"], 0.055, (0, -0.04, -0.08)),
            ico("PortalCrystal", (0, -0.075, 0.83), (0.28, 0.14, 0.48), palette["surface"], 3),
            torus("GoldenOrbitA", (0, -0.10, 0.83), 0.48, 0.022, palette["trim"], (math.pi / 2, 0, 0), 32, 6),
            torus("GoldenOrbitB", (0, -0.11, 0.83), 0.48, 0.017, palette["trim"], (math.pi / 2, 0.62, 0), 32, 6),
        ])
        return smart_uv_project(join_asset(name, parts))
    parts = [cube(name, (0, 0, 0.07), (1.65, 0.82, 0.14), palette["base"], 0.08)]
    parts.extend([
        torus("PortalFrame", (0, -0.045, 0.72), 0.50, 0.095, palette["frame"], (math.pi / 2, 0, 0), 40, 8),
        torus("PortalInnerBezel", (0, -0.070, 0.72), 0.34, 0.030, palette["trim"], (math.pi / 2, 0, 0), 36, 6),
        cylinder("PortalEnergyVortex", (0, -0.096, 0.72), 0.39, 0.025, palette["surface"], 40, (math.pi / 2, 0, 0), 0.004),
        cube("PortalFootStone", (-0.48, -0.015, 0.24), (0.24, 0.28, 0.30), palette["base"], 0.045),
        cube("PortalFootStone", (0.48, -0.015, 0.24), (0.24, 0.28, 0.30), palette["base"], 0.045),
    ])
    for index, angle in enumerate((-0.78, 0.78, -2.18, 2.18)):
        x = math.cos(angle) * 0.58
        z = 0.72 + math.sin(angle) * 0.58
        parts.append(cylinder(f"PortalBolt{index}", (x, -0.16, z), 0.040, 0.030, palette["trim"], 12, (math.pi / 2, 0, 0), 0.008))
    for x in (-0.78, 0.78):
        parts.append(cone("PortalStonePylon", (x, -0.02, 0.74), 0.13, 0.045, 0.92, palette["trim"], 7, (0.05, 0.0, -0.10 if x < 0 else 0.10)))
    portal = join_asset(name, parts)
    return smart_uv_project(portal) if name == "portal_w1" else portal


def create_aeri(_mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    """Import the original horned spirit and normalize it for gameplay."""
    source_path = ROOT / "assets" / "source" / "blender" / "horned_spirit_character.blend"
    if not source_path.exists():
        raise RuntimeError(f"Missing horned spirit source model: {source_path}")

    with bpy.data.libraries.load(str(source_path), link=False) as (source_data, target_data):
        mesh_names = [name for name in source_data.objects if name not in {"Preview_Pedestal"} and not name.startswith("REFERENCE_")]
        target_data.objects = mesh_names

    parts: list[bpy.types.Object] = []
    for imported in target_data.objects:
        if imported is not None and imported.type == "MESH":
            bpy.context.collection.objects.link(imported)
            imported.parent = None
            parts.append(imported)
    if not parts:
        raise RuntimeError("The horned spirit source did not contain mesh objects")
    obj = join_asset("aeri", parts)
    obj.name = "aeri"
    obj.data.name = "aeri_Mesh"
    obj.animation_data_clear()
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)

    # Center the authored mesh and keep its body inside the existing spherical
    # collider while allowing the horns to define a slightly taller silhouette.
    bounds = [Vector(corner) for corner in obj.bound_box]
    center = sum(bounds, Vector()) / len(bounds)
    obj.data.transform(Matrix.Translation(-center))
    bpy.context.view_layer.update()
    diameter = max(float(axis) for axis in obj.dimensions)
    if diameter <= 0.0:
        raise RuntimeError("The approved Aeri source has invalid dimensions")
    scale = 1.52 / diameter
    obj.scale = (scale, scale, scale)
    activate_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    current_triangles = triangle_count(obj)
    if current_triangles > 11500:
        decimate = obj.modifiers.new("HornedSpirit_RuntimeOptimization", "DECIMATE")
        decimate.ratio = 11500.0 / float(current_triangles)
        decimate.use_collapse_triangulate = True
        apply_modifier(obj, decimate)

    for material_slot in obj.material_slots:
        material = material_slot.material
        if material is None:
            continue
        if not material.use_nodes or material.node_tree is None:
            continue
        for node in material.node_tree.nodes:
            image = getattr(node, "image", None)
            if image is not None and max(image.size) > 1024:
                image.scale(1024, 1024)

    return obj


def metaball_mesh(name: str, points: list[tuple[float, float, float, float]], mat: bpy.types.Material, resolution: float = 0.18) -> bpy.types.Object:
    data = bpy.data.metaballs.new(f"{name}_Volume")
    data.resolution = resolution
    data.render_resolution = max(0.09, resolution * 0.62)
    data.threshold = 0.62
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for x, y, z, radius in points:
        element = data.elements.new()
        element.co = (x, y, z)
        element.radius = radius
    activate_only(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    decimate = obj.modifiers.new("CloudSilhouetteBudget", "DECIMATE")
    decimate.ratio = 0.42
    apply_modifier(obj, decimate)
    smooth(obj)
    return add_mat(obj, mat)


def create_cloud(name: str, points: list[tuple[float, float, float, float]], mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    # Long, muted cloud banks read less like cartoon puffs in the game's distant camera.
    main_points = [(x * 1.12, y, z * 0.62, radius * 0.74) for x, y, z, radius in points]
    main = metaball_mesh(name, main_points, mats["cloud"], 0.24)
    underside_points = [(x * 1.12, y + 0.10, z * 0.56 - 0.31, radius * 0.48) for x, y, z, radius in points[1:-1]]
    under = metaball_mesh("CloudUnderside", underside_points, mats["cloud_shadow"], 0.25)
    wisp = cube("CloudMistShelf", (0, 0.18, -0.36), (6.8, 0.09, 0.12), mats["cloud_shadow"], 0.05)
    return join_asset(name, [main, under, wisp])


def create_cloudy_mountain(mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    source_path = ROOT / "assets" / "source" / "models" / "sketchfab" / "cloudy_mountain_4k.glb"
    if not source_path.exists():
        raise RuntimeError(f"Missing user-provided cloudy mountain source: {source_path}")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(source_path))
    imported = [obj for obj in bpy.data.objects if obj not in before and obj.type == "MESH"]
    parts: list[bpy.types.Object] = []
    for obj in imported:
        material_names = {material.name.lower() for material in obj.data.materials if material is not None}
        if len(obj.data.polygons) == 0 or obj.name == "Cube" or "cloud" in material_names:
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        activate_only(obj)
        decimate = obj.modifiers.new("DistantAtmosphereLOD", "DECIMATE")
        decimate.ratio = 0.14
        apply_modifier(obj, decimate)
        parts.append(obj)
    if not parts:
        raise RuntimeError("Cloudy mountain source contains no renderable meshes")
    mountain = join_asset("cloudy_mountain_w1", parts)
    minimum = Vector((min(vertex.co.x for vertex in mountain.data.vertices), min(vertex.co.y for vertex in mountain.data.vertices), min(vertex.co.z for vertex in mountain.data.vertices)))
    maximum = Vector((max(vertex.co.x for vertex in mountain.data.vertices), max(vertex.co.y for vertex in mountain.data.vertices), max(vertex.co.z for vertex in mountain.data.vertices)))
    center = (minimum + maximum) * 0.5
    scale = 10.0 / max(maximum - minimum)
    for vertex in mountain.data.vertices:
        vertex.co = (vertex.co - center) * scale
    mountain.data.update()
    cloud_ring = metaball_mesh("MountainCloudRing", [
        (-4.7, -0.2, -1.6, 1.55), (-3.2, -1.0, -1.45, 1.75), (-1.4, -1.7, -1.55, 1.65),
        (0.7, -1.9, -1.45, 1.80), (2.8, -1.4, -1.55, 1.65), (4.6, -0.4, -1.50, 1.50),
        (4.2, 1.2, -1.60, 1.55), (2.3, 1.8, -1.45, 1.72), (0.0, 2.0, -1.55, 1.82),
        (-2.3, 1.7, -1.50, 1.70), (-4.2, 1.0, -1.55, 1.52),
    ], mats["cloud"], 0.30)
    return join_asset("cloudy_mountain_w1", [mountain, cloud_ring])


def rock_island(name: str, radius: float, height: float, stone: bpy.types.Material, seed: int) -> bpy.types.Object:
    rng = random.Random(seed)
    segments = 18
    rings = [(0.0, radius), (-0.28, radius * 0.92), (-height * 0.48, radius * 0.64), (-height, radius * 0.16)]
    vertices: list[tuple[float, float, float]] = []
    for ring_index, (z, ring_radius) in enumerate(rings):
        for index in range(segments):
            angle = index / segments * math.tau
            jitter = rng.uniform(-0.13, 0.13) * (1.0 if ring_index else 0.35)
            value = ring_radius + jitter
            vertices.append((math.cos(angle) * value, math.sin(angle) * value, z + rng.uniform(-0.05, 0.05)))
    faces: list[tuple[int, ...]] = [tuple(range(segments - 1, -1, -1))]
    for ring_index in range(len(rings) - 1):
        start = ring_index * segments
        following = (ring_index + 1) * segments
        for index in range(segments):
            nxt = (index + 1) % segments
            faces.append((start + index, start + nxt, following + nxt, following + index))
    faces.append(tuple(range((len(rings) - 1) * segments, len(rings) * segments)))
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    add_mat(obj, stone)
    bevel = obj.modifiers.new("IslandEdgeWear", "BEVEL")
    bevel.width = 0.055
    bevel.segments = 2
    apply_modifier(obj, bevel)
    smooth(obj)
    return obj


def create_temple_landmark(mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    base = rock_island("landmark_w1", 2.15, 2.45, mats["w1_cliff"], 141)
    smart_uv_project(base)
    parts = [base, cylinder("AncientPavingDais", (0, 0, 0.09), 2.03, 0.20, mats["w1_floor"], 24, bevel=0.06)]
    for index, (x, y) in enumerate(((-1.08, -0.68), (1.08, -0.68), (-1.08, 0.68), (1.08, 0.68))):
        column_height = 1.60 if index != 2 else 1.18
        parts.append(cylinder("TempleColumn", (x, y, column_height * 0.5 + 0.18), 0.18, column_height, mats["w1_wall"], 10, bevel=0.035))
        parts.append(cylinder("TempleCapital", (x, y, column_height + 0.18), 0.27, 0.16, mats["w1_wall"], 10, bevel=0.025))
    parts.extend([
        cube("TempleLintelLeft", (-0.61, -0.68, 1.87), (1.18, 0.30, 0.24), mats["w1_wall"], 0.065, (0, 0.03, 0.045)),
        cube("TempleLintelRight", (0.71, -0.68, 1.83), (1.02, 0.30, 0.24), mats["w1_wall"], 0.065, (0, -0.04, -0.07)),
        ico("AnchorBloom", (0, -0.12, 1.20), (0.30, 0.24, 0.54), mats["core"], 3),
        torus("AnchorHalo", (0, -0.12, 1.20), 0.58, 0.028, mats["core_ring"], (math.pi / 2, 0, 0), 28, 6),
    ])
    # Use the approved fern source sparingly so vegetation enriches the island
    # silhouette without obscuring gameplay paths.
    fern_source = ROOT / "assets" / "source" / "models" / "polyhaven" / "fern_02_1k" / "fern_02_1k.blend"
    shared_fern_material: bpy.types.Material | None = None
    for index, (source_name, location, rotation) in enumerate((
        ("fern_02_a", (-1.48, 0.85, 0.22), 0.25),
        ("fern_02_b", (1.42, 0.72, 0.22), -0.55),
        ("fern_02_c", (-1.35, -0.95, 0.22), 1.10),
    )):
        fern = append_source_object(fern_source, source_name)
        fern.name = f"TempleFern{index}"
        fern.location = location
        fern.rotation_euler.z = rotation
        fern.scale = (0.18, 0.18, 0.18)
        if fern.material_slots:
            if shared_fern_material is None:
                shared_fern_material = fern.material_slots[0].material
                if shared_fern_material is not None:
                    shared_fern_material.name = "W1_Fern02_1K"
            elif shared_fern_material is not None:
                for slot in fern.material_slots:
                    slot.material = shared_fern_material
        activate_only(fern)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        parts.append(fern)
    rng = random.Random(441)
    for index in range(14):
        angle = -0.55 + index * 0.075
        x = -2.08 + rng.uniform(-0.04, 0.04)
        y = math.sin(angle * 3.0) * 0.35
        z = 0.02 - index * 0.15
        parts.append(ico(f"IslandVineLeaf{index}", (x, y, z), (0.035, 0.085, 0.13), mats["moss"], 1))
    return join_asset("landmark_w1", parts)


def create_machine_landmark(mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    base = rock_island("landmark_w2", 2.28, 1.95, mats["machine"], 242)
    parts = [base, cylinder("MachinePlatform", (0, 0, 0.12), 2.12, 0.28, mats["machine_light"], 18, bevel=0.08)]
    parts.extend([
        torus("WeatherTurbine", (0, -0.02, 1.28), 0.98, 0.16, mats["brass"], (math.pi / 2, 0, 0), 32, 8),
        torus("WeatherCore", (0, -0.06, 1.28), 0.66, 0.05, mats["cyan"], (math.pi / 2, 0, 0), 30, 6),
        cylinder("TurbineMast", (0, 0, 0.82), 0.20, 1.46, mats["machine"], 12, bevel=0.035),
        cube("PortalMonolith", (0, -0.14, 1.26), (0.22, 0.18, 0.86), mats["machine"], 0.025),
    ])
    for angle in (0, math.pi / 2, math.pi, math.pi * 1.5):
        x = math.cos(angle) * 0.50
        z = 1.28 + math.sin(angle) * 0.50
        parts.append(cube("TurbineBlade", (x, -0.05, z), (0.11, 0.08, 0.64), mats["cyan"], 0.035, (0, angle, -angle)))
    for x in (-1.25, 1.25):
        parts.append(cylinder("SkyCoil", (x, 0, 0.78), 0.16, 1.26, mats["brass"], 12, bevel=0.03))
        parts.append(ico("CoilNode", (x, 0, 1.46), (0.22, 0.22, 0.30), mats["cyan"], 2))
    for x in (-1.06, 1.06):
        parts.append(cylinder("BeaconPost", (x, 0.02, 0.78), 0.12, 1.00, mats["wood_dark"], 10, bevel=0.02))
        parts.append(ico("BeaconGlow", (x, 0.02, 1.34), (0.18, 0.18, 0.24), mats["ice_glow"], 1))
    return join_asset("landmark_w2", parts)


def create_ember_landmark(mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    base = rock_island("landmark_w3", 2.22, 2.55, mats["basalt"], 343)
    parts = [base, cylinder("ObsidianDais", (0, 0, 0.11), 1.82, 0.28, mats["obsidian"], 10, bevel=0.055)]
    for index, angle in enumerate((0.2, 2.3, 4.4)):
        radius = 1.22
        x, y = math.cos(angle) * radius, math.sin(angle) * radius
        height = 1.30 + index * 0.24
        parts.append(cone("BasaltSpire", (x, y, height * 0.5), 0.34, 0.08, height, mats["basalt"], 7, (0.10 * index, -0.08 * index, angle)))
        parts.append(cube("MagmaVein", (x, y - 0.025, height * 0.55), (0.055, 0.035, height * 0.58), mats["lava"], 0.018, (0, 0.12 * index, angle)))
    parts.extend([
        ico("EmberAnchor", (0, 0, 1.22), (0.34, 0.34, 0.86), mats["lava"], 2),
        torus("EmberCage", (0, 0, 1.20), 0.76, 0.055, mats["gold"], (math.pi / 2, 0, 0), 24, 6),
        torus("EmberCage", (0, 0, 1.20), 0.76, 0.04, mats["gold"], (0, math.pi / 2, 0), 24, 6),
        cone("CrystalShardA", (-0.22, 0.18, 1.04), 0.12, 0.02, 0.72, mats["lava"], 5, (-0.20, 0.10, 0.12)),
        cone("CrystalShardB", (0.18, -0.10, 1.00), 0.11, 0.02, 0.68, mats["lava"], 5, (0.14, -0.18, -0.08)),
        cone("CrystalShardC", (0.02, 0.24, 0.95), 0.09, 0.02, 0.52, mats["lava"], 5, (0.08, 0.12, 0.02)),
    ])
    return join_asset("landmark_w3", parts)


def export_asset(obj: bpy.types.Object, asset_name: str) -> None:
    activate_only(obj)
    output_path = OUTPUT_DIR / f"{asset_name}.glb"
    staging_path = OUTPUT_DIR / f".{asset_name}.building.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(staging_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
    )
    staging_path.replace(output_path)
    triangles = triangle_count(obj)
    materials = len(obj.data.materials)
    budget = BUDGETS[asset_name]
    if triangles > budget["max_triangles"]:
        raise RuntimeError(f"{asset_name} has {triangles} triangles; budget is {budget['max_triangles']}")
    if materials > budget["max_materials"]:
        raise RuntimeError(f"{asset_name} has {materials} materials; budget is {budget['max_materials']}")
    if not output_path.exists() or output_path.stat().st_size < 2048:
        raise RuntimeError(f"Invalid GLB output: {output_path}")
    REPORT.append({
        "name": asset_name,
        "path": output_path.relative_to(ROOT).as_posix(),
        "triangles": triangles,
        "materials": materials,
        "bytes": output_path.stat().st_size,
        "triangle_budget": budget["max_triangles"],
    })


def look_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_preview(objects: dict[str, bpy.types.Object], backdrop: bpy.types.Material) -> None:
    placements = {
        "w1_block_a": (-7.0, 0.0, 0.0), "w1_block_b": (-5.1, 0.0, 0.0),
        "portal_w1": (-8.1, -1.55, -0.82), "landmark_w1": (-4.8, 3.8, 1.15),
        "w2_block_a": (-1.0, 0.0, 0.0), "w2_block_b": (0.9, 0.0, 0.0),
        "w2_tile_ice": (1.2, -2.1, -0.80), "portal_w2": (-2.0, -1.55, -0.82), "landmark_w2": (1.0, 3.9, 0.95),
        "w3_block_a": (5.0, 0.0, 0.0), "w3_block_b": (6.9, 0.0, 0.0),
        "w3_tile_hazard": (6.4, -2.1, -0.80), "w3_tile_collapse": (8.2, -2.1, -0.80), "portal_w3": (4.2, -1.55, -0.82),
        "landmark_w3": (7.3, 4.0, 1.20), "aeri": (0.0, -4.0, -0.05), "sky_core": (-1.35, -4.0, 0.0), "sunfruit": (1.35, -4.0, 0.0),
        "cloud_bank_a": (-6.0, 7.2, 5.5), "cloud_bank_b": (0.0, 8.0, 6.2), "cloud_bank_c": (6.5, 7.3, 5.6),
    }
    for name, obj in objects.items():
        obj.hide_render = name not in placements
        if name in placements:
            obj.location = placements[name]
    bpy.ops.mesh.primitive_plane_add(size=40.0, location=(0, 1.0, -0.91))
    ground = bpy.context.active_object
    ground.name = "PreviewGround"
    ground.data.materials.append(backdrop)
    bpy.ops.object.light_add(type="AREA", location=(-7.0, -7.0, 13.0))
    key = bpy.context.active_object
    key.data.energy = 1750.0
    key.data.shape = "DISK"
    key.data.size = 7.0
    key.data.color = (1.0, 0.78, 0.57)
    look_at(key, (0.0, 1.0, 0.5))
    bpy.ops.object.light_add(type="AREA", location=(10.0, -1.0, 9.0))
    fill = bpy.context.active_object
    fill.data.energy = 1350.0
    fill.data.size = 8.0
    fill.data.color = (0.30, 0.62, 1.0)
    look_at(fill, (0.0, 1.0, 1.0))
    bpy.ops.object.light_add(type="AREA", location=(0.0, 10.0, 12.0))
    rim = bpy.context.active_object
    rim.data.energy = 1050.0
    rim.data.size = 6.0
    rim.data.color = (0.40, 0.95, 0.85)
    look_at(rim, (0.0, 2.0, 1.0))
    bpy.ops.object.camera_add(location=(18.5, -27.0, 15.5))
    camera = bpy.context.active_object
    camera.data.lens = 54.0
    look_at(camera, (0.0, 1.1, 0.8))
    bpy.context.scene.camera = camera
    world = bpy.context.scene.world or bpy.data.worlds.new("SkyrollPreviewWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.08, 0.30, 0.58, 1.0)
    background.inputs["Strength"].default_value = 0.52
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_DIR / "sale_ready_kit.png")
    scene.render.film_transparent = False
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.render.render(write_still=True)


def render_world1_preview(objects: dict[str, bpy.types.Object]) -> None:
    """Render the bright Ancient Sky Temple vertical slice for visual QA."""
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.hide_render = True
    placements = {
        "w1_block_a": (-1.9, -1.0, 0.0),
        "w1_block_b": (0.0, 0.9, 0.0),
        "w1_block_c": (1.9, 2.8, 0.0),
        "portal_w1": (1.9, 2.8, 1.02),
        "landmark_w1": (5.6, 7.6, 2.4),
        "aeri": (-1.9, -1.0, 1.60),
        "sky_core": (0.0, 0.9, 1.55),
        "sunfruit": (1.9, 2.8, 1.65),
        "cloud_bank_a": (-9.0, 9.0, -1.0),
        "cloud_bank_b": (4.0, 15.0, 4.0),
        "cloud_bank_c": (10.0, 12.0, -2.0),
        "cloudy_mountain_w1": (-8.0, 15.0, -0.5),
    }
    for name, location in placements.items():
        obj = objects[name]
        obj.hide_render = False
        obj.location = location
        obj.rotation_euler = (0.0, 0.0, 0.0)
        obj.scale = Vector((1.0, 1.0, 1.0))
    for cloud_name in ("cloud_bank_a", "cloud_bank_b", "cloud_bank_c"):
        objects[cloud_name].scale = Vector((1.8, 0.85, 1.25))
    objects["cloudy_mountain_w1"].scale = Vector((1.25, 1.25, 1.25))

    scene = bpy.context.scene
    world = scene.world or bpy.data.worlds.new("World1_AncientSky")
    scene.world = world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    links = world.node_tree.links
    nodes.clear()
    world_output = nodes.new("ShaderNodeOutputWorld")
    background = nodes.new("ShaderNodeBackground")
    background.inputs["Color"].default_value = (0.035, 0.30, 0.68, 1.0)
    background.inputs["Strength"].default_value = 0.72
    links.new(background.outputs["Background"], world_output.inputs["Surface"])

    bpy.ops.object.light_add(type="SUN", location=(0, 0, 10))
    sun = bpy.context.active_object
    sun.rotation_euler = (math.radians(28), math.radians(-22), math.radians(-32))
    sun.data.energy = 2.2
    sun.data.color = (1.0, 0.84, 0.66)
    sun.data.angle = math.radians(7.0)
    bpy.ops.object.light_add(type="AREA", location=(-4.0, -3.0, 8.0))
    fill = bpy.context.active_object
    fill.data.energy = 1100.0
    fill.data.size = 8.0
    fill.data.color = (0.40, 0.72, 1.0)
    look_at(fill, (0.0, 2.0, 1.0))

    camera = scene.camera
    camera.location = (10.8, -15.5, 8.5)
    camera.data.lens = 48.0
    look_at(camera, (0.8, 2.5, 1.3))
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(QA_DIR / "world1_ancient_sky_temple.png")
    scene.render.film_transparent = False
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.render.render(write_still=True)


def render_app_icon(objects: dict[str, bpy.types.Object]) -> None:
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.hide_render = True
    aeri = objects["aeri"]
    aeri.hide_render = False
    aeri.location = (0.0, 0.0, 0.0)
    aeri.rotation_euler = (0.0, 0.0, 0.0)
    aeri.scale = (1.35, 1.35, 1.35)
    camera = bpy.context.scene.camera
    camera.location = (0.0, -5.6, 0.42)
    camera.data.lens = 61.0
    look_at(camera, (0.0, 0.0, 0.02))
    scene = bpy.context.scene
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(UI_DIR / "app_icon.png")
    scene.render.film_transparent = True
    bpy.ops.render.render(write_still=True)


def make_materials() -> dict[str, bpy.types.Material]:
    mats = {
        "sand": material("W1_Sandstone", (0.38, 0.21, 0.075, 1), 0.89),
        "sand_light": material("W1_SunlitStone", (0.63, 0.39, 0.14, 1), 0.84),
        "sand_dark": material("W1_DeepCarving", (0.115, 0.072, 0.045, 1), 0.96),
        "wood": material("W1_WeatheredCrateWood", (0.29, 0.135, 0.050, 1), 0.82),
        "wood_dark": material("W1_DarkWoodGaps", (0.075, 0.040, 0.022, 1), 0.94),
        "iron": material("W1_AgedIronStraps", (0.075, 0.070, 0.064, 1), 0.55, 0.58),
        "moss": material("W1_SkyMoss", (0.065, 0.27, 0.15, 1), 0.93),
        "gold": material("W1_AncientGold", (0.72, 0.34, 0.045, 1), 0.34, 0.55, (0.72, 0.15, 0.01, 1), 0.9),
        "machine": material("W2_NavyMachine", (0.035, 0.11, 0.20, 1), 0.36, 0.72),
        "machine_light": material("W2_CeramicBlue", (0.12, 0.37, 0.52, 1), 0.27, 0.52),
        "brass": material("W2_Brass", (0.72, 0.43, 0.12, 1), 0.26, 0.84),
        "cyan": material("W2_EnergyCyan", (0.10, 0.80, 0.95, 1), 0.18, 0.28, (0.03, 0.82, 1.0, 1), 2.1),
        "ice": material("W2_PrismaticIce", (0.38, 0.86, 1.0, 1), 0.08, 0.12, (0.08, 0.48, 0.72, 1), 0.55, 0.72),
        "ice_glow": material("W2_IceEdge", (0.71, 0.97, 1.0, 1), 0.12, 0.18, (0.18, 0.82, 1.0, 1), 1.2, 0.86),
        "basalt": material("W3_Basalt", (0.075, 0.055, 0.09, 1), 0.89),
        "obsidian": material("W3_Obsidian", (0.12, 0.055, 0.15, 1), 0.22, 0.38),
        "lava": material("W3_Magma", (0.95, 0.18, 0.035, 1), 0.23, 0.10, (1.0, 0.055, 0.005, 1), 3.1),
        "lava_dark": material("W3_MagmaDepth", (0.20, 0.015, 0.025, 1), 0.44, 0.1, (0.45, 0.008, 0.004, 1), 1.2),
        "core": material("Core_Crystal", (0.25, 0.92, 1.0, 1), 0.12, 0.18, (0.05, 0.82, 1.0, 1), 2.4),
        "core_hot": material("Core_Heart", (1.0, 0.75, 0.18, 1), 0.10, 0.12, (1.0, 0.31, 0.02, 1), 4.2),
        "core_ring": material("Core_Orbit", (0.98, 0.85, 0.38, 1), 0.25, 0.65, (1.0, 0.42, 0.06, 1), 1.8),
        "fruit": material("Fruit_NaturalRed", (0.56, 0.030, 0.022, 1), 0.52, 0.06),
        "fruit_hot": material("Fruit_NaturalWarmPatch", (0.72, 0.16, 0.020, 1), 0.50, 0.04),
        "fruit_dark": material("Fruit_SubtleSkinSpeckles", (0.19, 0.015, 0.010, 1), 0.74),
        "stem": material("Fruit_Stem", (0.08, 0.12, 0.025, 1), 0.92),
        "leaf": material("Fruit_Leaf", (0.12, 0.28, 0.07, 1), 0.84),
        "aeri_shell": material("Aeri_WhiteVolleyballShell", (0.92, 0.91, 0.88, 1), 0.34, 0.02),
        "aeri_seam": material("Aeri_VolleyballSeam", (0.055, 0.065, 0.080, 1), 0.58, 0.02),
        "aeri_band_blue": material("Aeri_VolleyballBandBlue", (0.10, 0.42, 0.82, 1), 0.36, 0.06),
        "aeri_band_gold": material("Aeri_VolleyballBandGold", (0.86, 0.66, 0.16, 1), 0.34, 0.08),
        "portal_glass": material("Portal_TintedGlass", (0.055, 0.16, 0.21, 1), 0.18, 0.08, (0.01, 0.07, 0.10, 1), 0.28, 0.78),
        "cloud": material("Cloud_AtmosphericWhite", (0.88, 0.94, 1.0, 1), 0.98, alpha=0.62),
        "cloud_shadow": material("Cloud_AtmosphericShadow", (0.30, 0.46, 0.62, 1), 1.0, alpha=0.26),
        "preview": material("Preview_Navy", (0.012, 0.026, 0.055, 1), 0.88),
    }
    generated = ROOT / "assets" / "source" / "textures" / "generated"
    wall = ROOT / "assets" / "source" / "textures" / "polyhaven" / "mossy_stone_wall"
    rocky = ROOT / "assets" / "source" / "textures" / "polyhaven" / "rocky_terrain"
    floor = ROOT / "assets" / "source" / "textures" / "polyhaven" / "rock_tile_floor"
    cliff = ROOT / "assets" / "source" / "models" / "polyhaven" / "rock_face_02_1k" / "textures"
    mats["w1_wall"] = pbr_material(
        "W1_MossyStoneWall_2K",
        wall / "mossy_stone_wall_diff_2k.jpg",
        wall / "mossy_stone_wall_nor_gl_2k.jpg",
        wall / "mossy_stone_wall_rough_2k.jpg",
        wall / "mossy_stone_wall_ao_2k.jpg",
        1.55,
    )
    mats["w1_floor"] = pbr_material(
        "W1_RockTileFloor_2K",
        floor / "rock_tile_floor_diff_2k.jpg",
        floor / "rock_tile_floor_nor_gl_2k.jpg",
        floor / "rock_tile_floor_rough_2k.jpg",
        floor / "rock_tile_floor_ao_2k.jpg",
        1.30,
    )
    mats["w1_rocky"] = pbr_material(
        "W1_RockyTerrain_2K",
        rocky / "rocky_terrain_diff_2k.jpg",
        rocky / "rocky_terrain_nor_gl_2k.jpg",
        rocky / "rocky_terrain_rough_2k.jpg",
        rocky / "rocky_terrain_ao_2k.jpg",
        0.92,
    )
    mats["w1_rocky_displacement"] = rocky / "rocky_terrain_disp_2k.png"
    mats["w1_cliff"] = pbr_material(
        "W1_RockFace02_1K",
        cliff / "rock_face_02_diff_1k.jpg",
        cliff / "rock_face_02_nor_gl_1k.exr",
        cliff / "rock_face_02_rough_1k.exr",
        cliff / "rock_face_02_rough_1k.exr",
        0.80,
    )
    mats["w1_crack"] = material("W1_DeepStoneCrack", (0.025, 0.038, 0.034, 1), 0.98)
    attach_albedo_texture(mats["wood"], generated / "w1_terracotta_albedo.png", "W1_ReusedOrganicWoodGrain_Albedo")
    attach_albedo_texture(mats["sand"], generated / "w1_terracotta_albedo.png", "W1_RealTerracotta_Albedo")
    attach_albedo_texture(mats["machine"], generated / "w2_aged_metal_albedo.png", "W2_RealAgedMetal_Albedo")
    attach_albedo_texture(mats["basalt"], generated / "w3_basalt_albedo.png", "W3_RealBasalt_Albedo")
    return mats


def main() -> None:
    clean_scene()
    verify_design_references()
    sky_source = ROOT / "assets" / "source" / "textures" / "sky" / "sunflowers_puresky_4k.hdr"
    sky_runtime = ROOT / "assets" / "textures" / "sky" / "sunflowers_puresky_4k.hdr"
    sky_runtime.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(sky_source, sky_runtime)
    mats = make_materials()
    portal_palettes = {
        1: {"base": mats["w1_wall"], "trim": mats["gold"], "frame": mats["w1_wall"], "surface": mats["core"], "glow": mats["core"]},
        2: {"base": mats["machine"], "trim": mats["brass"], "frame": mats["brass"], "surface": mats["portal_glass"], "glow": mats["cyan"]},
        3: {"base": mats["basalt"], "trim": mats["basalt"], "frame": mats["gold"], "surface": mats["portal_glass"], "glow": mats["lava"]},
    }
    objects: dict[str, bpy.types.Object] = {}
    for index, suffix in enumerate(("a", "b", "c"), start=1):
        objects[f"w1_block_{suffix}"] = create_temple_block(f"w1_block_{suffix}", index, mats)
        objects[f"w2_block_{suffix}"] = create_machine_block(f"w2_block_{suffix}", index, mats)
        objects[f"w3_block_{suffix}"] = create_ember_block(f"w3_block_{suffix}", index, mats)
    objects.update({
        "w2_tile_ice": create_ice_tile(mats),
        "w3_tile_hazard": create_hazard_tile(mats),
        "w3_tile_collapse": create_collapse_tile(mats),
        "sky_core": create_sky_core(mats),
        "sunfruit": create_sunfruit(mats),
        "portal_w1": create_portal("portal_w1", portal_palettes[1]),
        "portal_w2": create_portal("portal_w2", portal_palettes[2]),
        "portal_w3": create_portal("portal_w3", portal_palettes[3]),
        "aeri": create_aeri(mats),
        "cloud_bank_a": create_cloud("cloud_bank_a", [
            (-3.6, 0, 0.0, 1.30), (-2.5, 0.1, 0.28, 1.65), (-1.2, -0.1, 0.56, 1.85),
            (0.2, 0.1, 0.38, 1.72), (1.6, -0.1, 0.52, 1.55), (2.8, 0.0, 0.18, 1.38), (3.8, 0, -0.04, 0.90),
            (-0.5, 0.9, -0.16, 1.28), (1.1, 0.8, -0.20, 1.15),
        ], mats),
        "cloud_bank_b": create_cloud("cloud_bank_b", [
            (-3.0, 0, -0.05, 1.15), (-2.0, 0.1, 0.32, 1.48), (-0.8, 0, 0.70, 1.76),
            (0.5, -0.1, 0.44, 1.62), (1.7, 0.1, 0.58, 1.48), (2.8, 0, 0.12, 1.28),
            (-0.2, 0.92, -0.18, 1.20), (1.2, 0.76, -0.25, 1.02),
        ], mats),
        "cloud_bank_c": create_cloud("cloud_bank_c", [
            (-4.0, 0, -0.12, 0.90), (-3.1, 0, 0.02, 1.22), (-2.0, 0.1, 0.25, 1.54),
            (-0.8, 0, 0.60, 1.68), (0.5, -0.1, 0.50, 1.58), (1.8, 0.1, 0.30, 1.42),
            (2.9, 0, 0.14, 1.12), (3.8, 0, -0.10, 0.82), (0.0, 0.9, -0.18, 1.18),
        ], mats),
        "cloudy_mountain_w1": create_cloudy_mountain(mats),
        "landmark_w1": create_temple_landmark(mats),
        "landmark_w2": create_machine_landmark(mats),
        "landmark_w3": create_ember_landmark(mats),
    })

    missing = sorted(set(BUDGETS) - set(objects))
    if missing:
        raise RuntimeError("Manifest outputs without generators: " + ", ".join(missing))
    for asset_name in BUDGETS:
        export_asset(objects[asset_name], asset_name)

    render_preview(objects, mats["preview"])
    render_world1_preview(objects)
    bpy.ops.file.pack_all()
    source_path = SOURCE_DIR / "skyroll_sale_ready_kit.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path), compress=True)
    render_app_icon(objects)
    with (OUTPUT_DIR / "asset_report.json").open("w", encoding="utf-8") as handle:
        json.dump({
            "pipeline": MANIFEST["pipeline"],
            "blender_version": bpy.app.version_string,
            "source": source_path.relative_to(ROOT).as_posix(),
            "preview": "assets/3d/previews/sale_ready_kit.png",
            "assets": REPORT,
        }, handle, indent=2)
    print(f"Built {len(REPORT)} sale-ready assets; report: {OUTPUT_DIR / 'asset_report.json'}")


if __name__ == "__main__":
    main()
