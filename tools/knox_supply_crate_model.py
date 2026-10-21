"""Generate and export the Knox supply crate model and texture in Blender."""

from __future__ import annotations

import math
import os
from typing import Dict, List, Optional, Sequence, Set, Tuple

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils import noise as mnoise
from mathutils.bvhtree import BVHTree

Point3D = Tuple[float, float, float]
UVRect = Tuple[float, float, float, float]
RGBColor = Tuple[float, float, float]

try:
    MOD_ROOT: str = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
except NameError:
    MOD_ROOT = r"C:\Users\Zerik\Zomboid\mods\Knox-Air-Support"

MODEL_NAME: str = "KnoxSupplyCrate"
MODEL_DIR: str = os.path.join(MOD_ROOT, "42", "media", "models_X", "WorldItems")
TEXTURE_DIR: str = os.path.join(MOD_ROOT, "42", "media", "textures", "WorldItems")
FBX_OUTPUT_PATH: str = os.path.join(MODEL_DIR, MODEL_NAME + ".fbx")
TEXTURE_OUTPUT_PATH: str = os.path.join(TEXTURE_DIR, MODEL_NAME + ".png")

TEXTURE_WIDTH: int = 1024
TEXTURE_HEIGHT: int = 1024

WIDTH: float = 1.02
DEPTH: float = 0.82
HEIGHT: float = 0.78
DOME_HEIGHT: float = 0.035
SKID_HEIGHT: float = 0.045
BASE_HEIGHT: float = 0.030
CANVAS_BASE_Z: float = SKID_HEIGHT + BASE_HEIGHT

STRAP_X_OFFSET: float = 0.34
LOWER_BELT_HEIGHT: float = 0.20
UPPER_BELT_HEIGHT: float = 0.60
STRAP_WIDTH: float = 0.045
STRAP_THICKNESS: float = 0.010
INCLUDE_LIFTING_RIG: bool = True

for scene_object in list(bpy.data.objects):
    bpy.data.objects.remove(scene_object, do_unlink=True)
for data_block in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.lights,
               bpy.data.cameras, bpy.data.collections, bpy.data.images):
    for item in list(data_block):
        try:
            data_block.remove(item)
        except Exception:
            pass

DOUBLE_SIDED_MATERIALS: Set[bpy.types.Material] = set()
SMOOTH_SHADING_MATERIALS: Set[bpy.types.Material] = set()


def hex_to_linear_rgba(hex_color: str) -> Tuple[float, float, float, float]:
    """
    Convert a hexadecimal sRGB color to linear RGBA.

    Args:
        hex_color: Color in ``#RRGGBB`` format.

    Returns:
        The linear red, green, blue, and opaque alpha components.
    """
    hex_color = hex_color.lstrip('#')
    color_components = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]

    def linearize_channel(channel: float) -> float:
        """
        Convert one sRGB channel to linear light.

        Args:
            channel: An sRGB channel in the range 0..1.

        Returns:
            The corresponding linear-light channel.
        """
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4

    return (linearize_channel(color_components[0]), linearize_channel(color_components[1]), linearize_channel(color_components[2]), 1.0)


def create_material(name: str, hex_color: str, roughness: float = 0.6, emission: float = 0.0, alpha: float = 1.0,
        double_sided: bool = False, metallic: float = 0.0, smooth_shading: bool = False) -> bpy.types.Material:
    """
    Create a Principled BSDF material and register its shading flags.

    Args:
        name: Name assigned to the new material.
        hex_color: Base color in ``#RRGGBB`` format.
        roughness: Surface roughness.
        emission: Emission strength; zero disables emission.
        alpha: Material opacity.
        double_sided: Whether to disable backface culling for the material.
        metallic: Metallic shader value.
        smooth_shading: Whether generated mesh faces should use smooth shading.

    Returns:
        The created Blender material.
    """
    material = bpy.data.materials.new(name)
    linear_rgba = hex_to_linear_rgba(hex_color)
    material.diffuse_color = linear_rgba
    try:
        material.use_nodes = True
    except Exception:
        pass
    bsdf_node = material.node_tree.nodes.get("Principled BSDF")
    bsdf_node.inputs["Base Color"].default_value = linear_rgba
    bsdf_node.inputs["Roughness"].default_value = roughness
    bsdf_node.inputs["Metallic"].default_value = metallic
    if emission > 0:
        try:
            bsdf_node.inputs["Emission Color"].default_value = linear_rgba
            bsdf_node.inputs["Emission Strength"].default_value = emission
        except Exception:
            pass
    if alpha < 1.0:
        bsdf_node.inputs["Alpha"].default_value = alpha
        material.diffuse_color = (linear_rgba[0], linear_rgba[1], linear_rgba[2], alpha)
        for attr, val in (("surface_render_method", 'BLENDED'), ("blend_method", 'BLEND')):
            try:
                setattr(material, attr, val)
            except Exception:
                pass
    if double_sided:
        material.use_backface_culling = False
        DOUBLE_SIDED_MATERIALS.add(material)
    if smooth_shading:
        SMOOTH_SHADING_MATERIALS.add(material)
    return material


_material_bmeshes: Dict[bpy.types.Material, bmesh.types.BMesh] = {}


def _get_material_bmesh(material: bpy.types.Material) -> bmesh.types.BMesh:
    """
    Return the BMesh that accumulates geometry for a material.

    Args:
        material: Material whose geometry is being accumulated.

    Returns:
        The existing BMesh for the material, creating it when necessary.
    """
    if material not in _material_bmeshes:
        _material_bmeshes[material] = bmesh.new()
    return _material_bmeshes[material]


def _build_transform(location: Sequence[float], rotation: Optional[Matrix] = None,
       scale: Sequence[float] = (1, 1, 1)) -> Matrix:
    """
    Build a translation, rotation, and scale matrix.

    Args:
        location: Translation vector.
        rotation: Optional rotation matrix; identity is used when omitted.
        scale: Scale factors along the three axes.

    Returns:
        The composed 4x4 transformation matrix.
    """
    rotation_matrix = rotation if rotation is not None else Matrix.Identity(4)
    return Matrix.Translation(Vector(location)) @ rotation_matrix @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))


def rotation_x(degrees: float) -> Matrix:
    """
    Create a rotation around the X axis.

    Args:
        degrees: Rotation angle in degrees.

    Returns:
        The corresponding 4x4 rotation matrix.
    """
    return Matrix.Rotation(math.radians(degrees), 4, 'X')


def rotation_y(degrees: float) -> Matrix:
    """
    Create a rotation around the Y axis.

    Args:
        degrees: Rotation angle in degrees.

    Returns:
        The corresponding 4x4 rotation matrix.
    """
    return Matrix.Rotation(math.radians(degrees), 4, 'Y')


def rotation_z(degrees: float) -> Matrix:
    """
    Create a rotation around the Z axis.

    Args:
        degrees: Rotation angle in degrees.

    Returns:
        The corresponding 4x4 rotation matrix.
    """
    return Matrix.Rotation(math.radians(degrees), 4, 'Z')


def add_box(material: bpy.types.Material, location: Sequence[float], size_x: float, size_y: float, size_z: float,
         rotation: Optional[Matrix] = None) -> None:
    """
    Add a box centered at a location to the material mesh.

    Args:
        material: Material receiving the box geometry.
        location: Box center.
        size_x: Box size along X.
        size_y: Box size along Y.
        size_z: Box size along Z.
        rotation: Optional box rotation.

    Returns:
        None.
    """
    bm = _get_material_bmesh(material)
    value = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.transform(bm, matrix=_build_transform(location, rotation, (size_x, size_y, size_z)), verts=value['verts'])


def add_rounded_box(material: bpy.types.Material, location: Sequence[float], size_x: float, size_y: float, size_z: float,
           radius: float, segments: int = 3, rotation: Optional[Matrix] = None) -> None:
    """
    Add a box with rounded edges to the material mesh.

    Args:
        material: Material receiving the box geometry.
        location: Box center.
        size_x: Box size along X.
        size_y: Box size along Y.
        size_z: Box size along Z.
        radius: Bevel radius, clamped to the box dimensions.
        segments: Number of segments in each bevel.
        rotation: Optional box rotation.

    Returns:
        None.
    """
    temporary_bmesh = bmesh.new()
    bmesh.ops.create_cube(temporary_bmesh, size=1.0)
    bmesh.ops.scale(temporary_bmesh, vec=(size_x, size_y, size_z), verts=temporary_bmesh.verts[:])
    radius = min(radius, size_x * 0.49, size_y * 0.49, size_z * 0.49)
    try:
        bmesh.ops.bevel(temporary_bmesh, geom=temporary_bmesh.edges[:] + temporary_bmesh.verts[:], offset=radius, segments=segments,
                        affect='EDGES', profile=0.5, clamp_overlap=True)
    except Exception:
        pass
    bmesh.ops.transform(temporary_bmesh, matrix=_build_transform(location, rotation), verts=temporary_bmesh.verts[:])
    mesh = bpy.data.meshes.new("_tmp")
    temporary_bmesh.to_mesh(mesh)
    temporary_bmesh.free()
    _get_material_bmesh(material).from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


def add_sphere(material: bpy.types.Material, location: Sequence[float], radius: float,
        scale: Sequence[float] = (1, 1, 1), segments: int = 16, rings: int = 10) -> None:
    """
    Add a UV sphere, optionally scaled along each axis.

    Args:
        material: Material receiving the sphere geometry.
        location: Sphere center.
        radius: Sphere radius.
        scale: Scale factors along the three axes.
        segments: Number of longitudinal segments.
        rings: Number of latitude rings.

    Returns:
        None.
    """
    bm = _get_material_bmesh(material)
    value = bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    bmesh.ops.transform(bm, matrix=_build_transform(location, None, scale), verts=value['verts'])


def add_cylinder(material: bpy.types.Material, start_point: Sequence[float], end_point: Sequence[float], radius: float,
         segments: int = 10) -> None:
    """
    Add a capped cylinder between two points.

    Args:
        material: Material receiving the cylinder geometry.
        start_point: Starting endpoint.
        end_point: Ending endpoint.
        radius: Cylinder radius.
        segments: Number of radial segments.

    Returns:
        None.
    """
    start_vector, end_vector = Vector(start_point), Vector(end_point)
    depth = end_vector - start_vector
    if depth.length < 1e-6:
        return
    rotation_matrix = depth.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    bm = _get_material_bmesh(material)
    value = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=depth.length)
    bmesh.ops.transform(bm, matrix=Matrix.Translation((start_vector + end_vector) / 2) @ rotation_matrix, verts=value['verts'])


def add_torus(material: bpy.types.Material, major_radius: float, minor_radius: float, location: Sequence[float],
         rotation: Optional[Matrix] = None, segments: int = 48, minor_segments: int = 8) -> None:
    """
    Add a torus with its axis initially aligned to Z.

    Args:
        material: Material receiving the torus geometry.
        major_radius: Major radius.
        minor_radius: Minor radius.
        location: Torus center.
        rotation: Optional rotation applied to the torus.
        segments: Number of segments around the major radius.
        minor_segments: Number of segments around the minor radius.

    Returns:
        None.
    """
    bm = _get_material_bmesh(material)
    vertex_rows: List[List[bmesh.types.BMVert]] = []
    all_vertices: List[bmesh.types.BMVert] = []
    for i in range(segments):
        major_angle = 2 * math.pi * i / segments
        row = []
        for j in range(minor_segments):
            minor_angle = 2 * math.pi * j / minor_segments
            ring_radius = major_radius + minor_radius * math.cos(minor_angle)
            value = bm.verts.new((ring_radius * math.cos(major_angle), ring_radius * math.sin(major_angle), minor_radius * math.sin(minor_angle)))
            row.append(value)
            all_vertices.append(value)
        vertex_rows.append(row)
    for i in range(segments):
        for j in range(minor_segments):
            try:
                bm.faces.new((vertex_rows[i][j], vertex_rows[(i + 1) % segments][j],
                              vertex_rows[(i + 1) % segments][(j + 1) % minor_segments], vertex_rows[i][(j + 1) % minor_segments]))
            except ValueError:
                pass
    bmesh.ops.transform(bm, matrix=_build_transform(location, rotation), verts=all_vertices)


def create_loft(material: bpy.types.Material, rings: Sequence[Sequence[Sequence[float]]],
         cap_ends: Tuple[bool, bool] = (True, True), is_closed: bool = True,
         transform: Optional[Matrix] = None, wrap_rings: bool = False) -> List[List[bmesh.types.BMVert]]:
    """
    Join point rings with quads and optionally cap their ends.

    Args:
        material: Material whose BMesh receives the geometry.
        rings: Rings of 3D points, each with the same number of points.
        cap_ends: Whether to cap the first and last rings.
        is_closed: Whether each ring forms a closed perimeter.
        transform: Optional transformation applied to every point.
        wrap_rings: Whether to connect the final ring back to the first.

    Returns:
        Created vertices grouped by ring.
    """
    bm = _get_material_bmesh(material)
    transformation = transform if transform is not None else Matrix.Identity(4)
    vertex_rows = [[bm.verts.new(transformation @ Vector(point)) for point in ring_points] for ring_points in rings]
    count = len(rings[0])
    loop_limit = count if is_closed else count - 1
    ring_pairs = list(zip(vertex_rows, vertex_rows[1:]))
    if wrap_rings:
        ring_pairs.append((vertex_rows[-1], vertex_rows[0]))
    for first_ring, second_ring in ring_pairs:
        for i in range(loop_limit):
            j = (i + 1) % count
            try:
                bm.faces.new((first_ring[i], first_ring[j], second_ring[j], second_ring[i]))
            except ValueError:
                pass
    if is_closed and not wrap_rings:
        if cap_ends[0]:
            try:
                bm.faces.new(vertex_rows[0][::-1])
            except ValueError:
                pass
        if cap_ends[1]:
            try:
                bm.faces.new(vertex_rows[-1])
            except ValueError:
                pass
    return vertex_rows


def _smoothstep(t: float) -> float:
    """
    Evaluate smoothstep after clamping the input to 0..1.

    Args:
        t: Input value.

    Returns:
        The smoothstep interpolation value.
    """
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def _atlas_cell_uv(column: int, row: int, margin: float = 0.008) -> UVRect:
    """
    Calculate the UV bounds of a padded atlas cell.

    Args:
        column: Zero-based atlas column.
        row: Zero-based atlas row.
        margin: Padding applied inside each cell to prevent texture bleeding.

    Returns:
        The cell bounds as ``(u0, v0, u1, v1)``.
    """
    return (column / 3 + margin, row / 3 + margin, (column + 1) / 3 - margin, (row + 1) / 3 - margin)


UV_FRONT: UVRect = _atlas_cell_uv(0, 2)
UV_BACK: UVRect = _atlas_cell_uv(1, 2)
UV_TOP: UVRect = _atlas_cell_uv(2, 2)
UV_RIGHT: UVRect = _atlas_cell_uv(0, 1)
UV_LEFT: UVRect = _atlas_cell_uv(1, 1)
UV_WOOD: UVRect = _atlas_cell_uv(2, 1)
UV_METAL: UVRect = _atlas_cell_uv(0, 0)
UV_WEBBING: UVRect = _atlas_cell_uv(1, 0)
UV_ROPE: UVRect = _atlas_cell_uv(2, 0)

MAT_CANVAS: bpy.types.Material = create_material("Knox_Lona", "#6A6A50", 0.85, smooth_shading=True)
MAT_WEBBING: bpy.types.Material = create_material("Knox_Cincha", "#2E3024", 0.80)
MAT_METAL: bpy.types.Material = create_material("Knox_Metal", "#4A4A4C", 0.40, metallic=0.75)
MAT_ROPE: bpy.types.Material = create_material("Knox_Cuerda", "#8A7650", 0.90, smooth_shading=True)
MAT_WOOD: bpy.types.Material = create_material("Knox_Madera", "#6E5236", 0.85)

MATERIAL_UV_REGIONS: Dict[bpy.types.Material, UVRect] = {
    MAT_WEBBING: UV_WEBBING, MAT_METAL: UV_METAL, MAT_ROPE: UV_ROPE, MAT_WOOD: UV_WOOD,
}

HALF_WIDTH: float = WIDTH / 2
HALF_DEPTH: float = DEPTH / 2

BODY_PROFILE: List[Tuple[float, float]] = [
    (0.00, 0.935), (0.03, 0.975), (0.12, 0.995), (0.45, 1.000),
    (0.80, 0.992), (0.93, 0.965), (1.00, 0.880),
]
BODY_HEIGHT_RINGS: List[float] = [0.0, 0.03, 0.08, 0.15, 0.25, 0.35, 0.45, 0.55,
                          0.65, 0.75, 0.83, 0.90, 0.95, 1.0]
DOME_RINGS: List[Tuple[float, float]] = [(0.70, 0.45), (0.50, 0.75), (0.28, 0.92), (0.10, 1.0)]
CORNER_RADIUS: float = 0.07


def _profile_scale(height: float) -> float:
    """
    Interpolate the canvas body scale at a normalized height.

    Args:
        height: Normalized height along the canvas body.

    Returns:
        The interpolated cross-section scale.
    """
    for (height_start, scale_start), (height_end, scale_end) in zip(BODY_PROFILE, BODY_PROFILE[1:]):
        if height <= height_end:
            t = (height - height_start) / ((height_end - height_start) or 1.0)
            return scale_start + (scale_end - scale_start) * t
    return BODY_PROFILE[-1][1]


def _rounded_rectangle_ring(width: float, depth: float, radius: float, count: int = 5,
              edge_subdivisions: int = 0) -> List[Tuple[float, float, float, float]]:
    """
    Generate a counter-clockwise rounded rectangle in the XY plane.

    Args:
        width: Rectangle width along X.
        depth: Rectangle depth along Y.
        radius: Corner radius.
        count: Number of subdivisions per corner arc.
        edge_subdivisions: Number of additional points along each straight edge.

    Returns:
        Points as ``(x_coord, y_coord, nx, ny)`` tuples, where ``(nx, ny)`` is the
        outward normal at each point.
    """
    radius = min(radius, width / 2 * 0.999, depth / 2 * 0.999)
    corner_signs = ((1, 1), (-1, 1), (-1, -1), (1, -1))
    out: List[Tuple[float, float, float, float]] = []
    for k, (x_sign, y_sign) in enumerate(corner_signs):
        center_x, center_y = x_sign * (width / 2 - radius), y_sign * (depth / 2 - radius)
        angle_start = math.pi / 2 * k
        for i in range(count + 1):
            corner_angle = angle_start + (math.pi / 2) * i / count
            out.append((center_x + radius * math.cos(corner_angle), center_y + radius * math.sin(corner_angle), math.cos(corner_angle), math.sin(corner_angle)))
        angle_end = angle_start + math.pi / 2
        next_x_sign, next_y_sign = corner_signs[(k + 1) % 4]
        start_point = (next_x_sign * (width / 2 - radius) + radius * math.cos(angle_end), next_y_sign * (depth / 2 - radius) + radius * math.sin(angle_end))
        end_point = out[-1]
        for j in range(1, edge_subdivisions + 1):
            t = j / (edge_subdivisions + 1)
            out.append((end_point[0] + (start_point[0] - end_point[0]) * t, end_point[1] + (start_point[1] - end_point[1]) * t,
                        math.cos(angle_end), math.sin(angle_end)))
    return out


def _wrinkle_displacement(x_coord: float, y_coord: float, z_coord: float, amplitude: float) -> float:
    """
    Calculate canvas wrinkle displacement at a surface point.

    Args:
        x_coord: Surface point's X coordinate.
        y_coord: Surface point's Y coordinate.
        z_coord: Surface point's Z coordinate.
        amplitude: Maximum wrinkle displacement.

    Returns:
        Wrinkle displacement in meters.
    """
    noise_value = (mnoise.noise(Vector((x_coord * 5.0, y_coord * 5.0, z_coord * 2.4 + 1.7))) * 0.6
         + mnoise.noise(Vector((x_coord * 14.0, y_coord * 14.0, z_coord * 7.0 + 5.3))) * 0.4)
    tension_factor = (_smoothstep(abs(abs(x_coord) - STRAP_X_OFFSET) / 0.055)
               * _smoothstep(abs(z_coord - LOWER_BELT_HEIGHT) / 0.045)
               * _smoothstep(abs(z_coord - UPPER_BELT_HEIGHT) / 0.045))
    return amplitude * (0.55 + 0.9 * noise_value) * tension_factor


def build_canvas_body(material: bpy.types.Material) -> None:
    """
    Build the wrinkled canvas shell with a slightly domed top.

    Args:
        material: Material assigned to the canvas geometry.

    Returns:
        None.
    """
    rings: List[List[Point3D]] = []
    for height in BODY_HEIGHT_RINGS:
        s = _profile_scale(height)
        z_coord = CANVAS_BASE_Z + height * (HEIGHT - CANVAS_BASE_Z)
        points: List[Point3D] = []
        for x_coord, y_coord, nx, ny in _rounded_rectangle_ring(WIDTH * s, DEPTH * s, CORNER_RADIUS * s, 5, 9):
            wrinkle_offset = 0.0 if height == 0.0 else _wrinkle_displacement(x_coord, y_coord, z_coord, 0.009)
            points.append((x_coord + nx * wrinkle_offset, y_coord + ny * wrinkle_offset, z_coord))
        rings.append(points)
    for s, dome_height_factor in DOME_RINGS:
        z_coord = HEIGHT + DOME_HEIGHT * dome_height_factor
        points = []
        for x_coord, y_coord, _nx, _ny in _rounded_rectangle_ring(WIDTH * s, DEPTH * s, CORNER_RADIUS * s, 5, 9):
            points.append((x_coord, y_coord, z_coord + _wrinkle_displacement(x_coord, y_coord, z_coord, 0.010) * 0.8))
        rings.append(points)

    vertex_rows = create_loft(material, rings, (True, False), True)
    bm = _get_material_bmesh(material)
    center = bm.verts.new((0.0, 0.0, HEIGHT + DOME_HEIGHT + 0.003))
    last_ring = vertex_rows[-1]
    for i in range(len(last_ring)):
        try:
            bm.faces.new((last_ring[i], last_ring[(i + 1) % len(last_ring)], center))
        except ValueError:
            pass


def add_webbing_ribbon(material: bpy.types.Material, points: Sequence[Vector], width_direction: Vector, center: Vector,
          width: float = STRAP_WIDTH, thickness: float = STRAP_THICKNESS,
          closed_loop: bool = False, lift_per_point: Optional[Sequence[float]] = None) -> None:
    """
    Extrude a flat webbing ribbon along a polyline.

    Args:
        material: Material receiving the ribbon geometry.
        points: Points along the cloth surface.
        width_direction: Fixed direction of the ribbon width.
        center: Interior point used to determine the outward-facing side.
        width: Ribbon width.
        thickness: Ribbon thickness.
        closed_loop: Whether the polyline forms a closed loop.
        lift_per_point: Optional per-point lift above the surface.

    Returns:
        None.
    """
    count = len(points)
    if count < 2:
        return
    rings: List[List[Vector]] = []
    for i, point in enumerate(points):
        if closed_loop:
            t = points[(i + 1) % count] - points[(i - 1) % count]
        else:
            t = points[min(i + 1, count - 1)] - points[max(i - 1, 0)]
        if t.length < 1e-9:
            continue
        t.normalize()
        normal = width_direction.cross(t)
        if normal.length < 1e-9:
            continue
        normal.normalize()
        if normal.dot(point - center) < 0:
            normal = -normal
        extra_lift = lift_per_point[i] if lift_per_point is not None else 0.0
        ribbon_center = point + normal * (thickness / 2 + 0.0015 + extra_lift)
        half_width = width_direction * (width / 2)
        half_thickness = normal * (thickness / 2)
        rings.append([
            ribbon_center - half_width - half_thickness,
            ribbon_center + half_width - half_thickness,
            ribbon_center + half_width + half_thickness,
            ribbon_center - half_width + half_thickness,
        ])
    if len(rings) < 2:
        return
    if closed_loop:
        create_loft(material, rings, (False, False), True, None, wrap_rings=True)
    else:
        create_loft(material, rings, (True, True), True)


def _raycast_canvas(bvh_tree: BVHTree, origin: Vector, direction: Vector) -> Optional[Vector]:
    """
    Cast a ray against the canvas body.

    Args:
        bvh_tree: BVH tree representing the canvas surface.
        origin: Ray origin.
        direction: Ray direction.

    Returns:
        Hit position, or ``None`` when the ray misses.
    """
    location, _nor, _idx, _dist = bvh_tree.ray_cast(origin, direction)
    return location


def build_vertical_straps(bvh_tree: BVHTree) -> None:
    """
    Build two straps from the base, over the top, and down the back.

    Args:
        bvh_tree: BVH tree representing the canvas surface.

    Returns:
        None.
    """
    center_height = (CANVAS_BASE_Z + HEIGHT) / 2
    for x_sign in (-1, 1):
        x_coord = x_sign * STRAP_X_OFFSET
        center = Vector((x_coord, 0.0, center_height))
        points: List[Vector] = []
        sweep_angle = -42.0
        while sweep_angle <= 222.0:
            angle_radians = math.radians(sweep_angle)
            hit = _raycast_canvas(bvh_tree, center, Vector((0.0, -math.cos(angle_radians), math.sin(angle_radians))))
            if hit is not None:
                points.append(hit)
            sweep_angle += 3.0
        add_webbing_ribbon(MAT_WEBBING, points, Vector((1, 0, 0)), center)


def build_belts(bvh_tree: BVHTree) -> None:
    """
    Build two belts around the bundle over the straps and corner binding.

    Args:
        bvh_tree: BVH tree representing the canvas surface.

    Returns:
        None.
    """
    for belt_height in (LOWER_BELT_HEIGHT, UPPER_BELT_HEIGHT):
        center = Vector((0.0, 0.0, belt_height))
        points: List[Vector] = []
        lift_offsets: List[float] = []
        angle_degrees = 0.0
        while angle_degrees < 360.0:
            angle_radians = math.radians(angle_degrees)
            hit = _raycast_canvas(bvh_tree, center, Vector((math.cos(angle_radians), math.sin(angle_radians), 0.0)))
            if hit is not None:
                points.append(hit)
                lift = 0.0
                if abs(hit.y) > 0.25:
                    lift = max(lift, _smoothstep((0.06 - abs(abs(hit.x) - STRAP_X_OFFSET)) / 0.03))
                distance_x, distance_y = HALF_WIDTH - abs(hit.x), HALF_DEPTH - abs(hit.y)
                lift = max(lift, _smoothstep((0.075 - max(distance_x, distance_y)) / 0.03))
                lift_offsets.append(lift * STRAP_THICKNESS)
            angle_degrees += 5.0
        add_webbing_ribbon(MAT_WEBBING, points, Vector((0, 0, 1)), center, closed_loop=True, lift_per_point=lift_offsets)


def build_corner_bindings(bvh_tree: BVHTree) -> None:
    """
    Build webbing bindings along the four vertical corners.

    Args:
        bvh_tree: BVH tree representing the canvas surface.

    Returns:
        None.
    """
    for x_sign in (-1, 1):
        for y_sign in (-1, 1):
            outward_direction = Vector((x_sign, y_sign, 0.0)).normalized()
            width_direction = Vector((-y_sign, x_sign, 0.0)).normalized()
            points: List[Vector] = []
            for i in range(15):
                height = 0.012 + 0.95 * i / 14
                z_coord = CANVAS_BASE_Z + height * (HEIGHT - CANVAS_BASE_Z)
                s = _profile_scale(height)
                origin = Vector((x_sign * (HALF_WIDTH - CORNER_RADIUS) * s, y_sign * (HALF_DEPTH - CORNER_RADIUS) * s, z_coord))
                hit = _raycast_canvas(bvh_tree, origin, outward_direction)
                if hit is not None:
                    points.append(hit)
            add_webbing_ribbon(MAT_WEBBING, points, width_direction, Vector((0.0, 0.0, 0.4)), width=0.042,
                               thickness=STRAP_THICKNESS * 0.8)


def build_buckle(point: Vector, axis: str) -> None:
    """
    Build a cam buckle facing -Y or +X.

    Args:
        point: Buckle center position.
        axis: Facing axis; ``"y"`` faces -Y and any other value faces +X.

    Returns:
        None.
    """
    if axis == 'y':
        add_rounded_box(MAT_METAL, point, 0.058, 0.012, 0.074, 0.003)
        add_rounded_box(MAT_METAL, point + Vector((0, -0.010, 0.012)), 0.046, 0.010, 0.032, 0.002, rotation=rotation_x(-14))
        add_box(MAT_METAL, point + Vector((0, -0.008, -0.026)), 0.050, 0.010, 0.008)
    else:
        add_rounded_box(MAT_METAL, point, 0.012, 0.058, 0.074, 0.003)
        add_rounded_box(MAT_METAL, point + Vector((0.010, 0, 0.012)), 0.010, 0.046, 0.032, 0.002, rotation=rotation_y(14))
        add_box(MAT_METAL, point + Vector((0.008, 0, -0.026)), 0.010, 0.050, 0.008)


def build_hardware(bvh_tree: BVHTree) -> None:
    """
    Build buckles on the front straps and +X side belts.

    Args:
        bvh_tree: BVH tree representing the canvas surface.

    Returns:
        None.
    """
    for x_sign in (-1, 1):
        hit = _raycast_canvas(bvh_tree, Vector((x_sign * STRAP_X_OFFSET, 0.0, 0.40)), Vector((0, -1, 0)))
        if hit is not None:
            build_buckle(hit + Vector((0, -(STRAP_THICKNESS + 0.007), 0)), 'y')
    for belt_height in (LOWER_BELT_HEIGHT, UPPER_BELT_HEIGHT):
        hit = _raycast_canvas(bvh_tree, Vector((0.0, 0.0, belt_height)), Vector((1, 0, 0)))
        if hit is not None:
            build_buckle(hit + Vector((STRAP_THICKNESS + 0.007, 0, 0)), 'x')


def build_lifting_rig(bvh_tree: BVHTree) -> None:
    """
    Build the lifting rig, including slings and the master ring.

    Args:
        bvh_tree: BVH tree representing the canvas surface.

    Returns:
        None.
    """
    top_z = HEIGHT + DOME_HEIGHT + 0.235
    master_ring_base = Vector((0.0, 0.0, top_z))
    for x_sign in (-1, 1):
        for y_sign in (-1, 1):
            hit = _raycast_canvas(bvh_tree, Vector((x_sign * STRAP_X_OFFSET, y_sign * 0.24, HEIGHT + 0.3)), Vector((0, 0, -1)))
            if hit is None:
                continue
            ring_position = hit + Vector((0, 0, 0.024))
            add_torus(MAT_METAL, 0.022, 0.0055, ring_position, rotation_x(90), segments=20, minor_segments=6)
            add_cylinder(MAT_ROPE, ring_position + Vector((0, 0, 0.022)), master_ring_base, 0.0085, segments=6)
    add_sphere(MAT_METAL, master_ring_base, 0.016, (1.0, 1.0, 1.0), 10, 6)
    add_torus(MAT_METAL, 0.032, 0.0065, master_ring_base + Vector((0, 0, 0.040)), rotation_x(90), segments=24, minor_segments=6)


def build_wooden_base() -> None:
    """
    Build a plywood deck on three skids beneath the canvas.

    Returns:
        None.
    """
    for x_coord in (-0.40, 0.0, 0.40):
        add_rounded_box(MAT_WOOD, (x_coord, 0, SKID_HEIGHT / 2), 0.100, DEPTH * 0.94, SKID_HEIGHT, 0.008, 2)
    add_rounded_box(MAT_WOOD, (0, 0, SKID_HEIGHT + BASE_HEIGHT / 2), WIDTH * 0.975, DEPTH * 0.975,
           BASE_HEIGHT, 0.008, 2)


GLYPHS: Dict[str, List[str]] = {
    'A': ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    'D': ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    'K': ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    'L': ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    'O': ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    'P': ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    'R': ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    'S': ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    'U': ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    'Y': ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    '.': ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    ' ': ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}
CANVAS_TEXTURE_HEIGHT: float = HEIGHT + DOME_HEIGHT - CANVAS_BASE_Z


def _generate_value_noise(width: int, height: int, cell_size: int, seed: int) -> np.ndarray:
    """
    Generate smooth value noise with the requested image dimensions.

    Args:
        width: Output width in pixels.
        height: Output height in pixels.
        cell_size: Grid-cell size; one produces white noise.
        seed: Seed for the random number generator.

    Returns:
        A floating-point noise array with shape ``(height, width)``.
    """
    rng = np.random.default_rng(seed)
    noise_grid = rng.random((height // cell_size + 2, width // cell_size + 2)).astype(np.float32)
    y_coordinates = np.arange(height, dtype=np.float32) / cell_size
    x_coordinates = np.arange(width, dtype=np.float32) / cell_size
    bottom, left = y_coordinates.astype(np.int64), x_coordinates.astype(np.int64)
    ty, tx = y_coordinates - bottom, x_coordinates - left
    ty = (ty * ty * (3 - 2 * ty))[:, None]
    tx = (tx * tx * (3 - 2 * tx))[None, :]
    n00 = noise_grid[bottom][:, left]
    n10 = noise_grid[bottom][:, left + 1]
    n01 = noise_grid[bottom + 1][:, left]
    n11 = noise_grid[bottom + 1][:, left + 1]
    return (n00 * (1 - tx) + n10 * tx) * (1 - ty) + (n01 * (1 - tx) + n11 * tx) * ty


def _paint_stencil(buf: np.ndarray, wear_mask: np.ndarray, rect: UVRect, extent_u: float, extent_v: float,
              text: str, center_u: float, center_v: float, height: float, color: RGBColor) -> None:
    """
    Paint worn stencil text into an atlas buffer.

    Args:
        buf: RGBA texture buffer modified in place.
        wear_mask: Per-pixel wear mask used to distress the stencil.
        rect: UV bounds of the atlas cell.
        extent_u: Real-world horizontal extent represented by the cell.
        extent_v: Real-world vertical extent represented by the cell.
        text: Text to render using the built-in 5x7 glyphs.
        center_u: Horizontal text center within the cell, from 0 to 1.
        center_v: Vertical text center within the cell, from 0 to 1.
        height: Letter height in meters.
        color: RGB stencil color.

    Returns:
        None.
    """
    image_height, image_width = buf.shape[0], buf.shape[1]
    vertex_rows = [""] * 7
    for character in text:
        glyph = GLYPHS.get(character.upper(), GLYPHS[' '])
        for row_index in range(7):
            vertex_rows[row_index] += glyph[row_index] + "0"
    glyph_bits = np.array([
        [1.0 if bit == '1' else 0.0 for bit in row_text[:-1]]
        for row_text in vertex_rows
    ], dtype=np.float32)
    column_count = glyph_bits.shape[1]
    pixels_per_unit_u = (rect[2] - rect[0]) * image_width / extent_u
    pixels_per_unit_v = (rect[3] - rect[1]) * image_height / extent_v
    unit_size = height / 7.0
    width_pixels = max(1, int(column_count * unit_size * pixels_per_unit_u))
    height_pixels = max(1, int(height * pixels_per_unit_v))
    indices_x = np.arange(width_pixels) * column_count // width_pixels
    indices_y = np.arange(height_pixels) * 7 // height_pixels
    mask = glyph_bits[::-1][indices_y][:, indices_x]
    stroke_width = max(1, int(unit_size * min(pixels_per_unit_u, pixels_per_unit_v) * 0.30))
    base_mask = mask.copy()
    for depth in range(1, stroke_width + 1):
        mask[:, depth:] = np.maximum(mask[:, depth:], base_mask[:, :-depth])
        mask[depth:, :] = np.maximum(mask[depth:, :], base_mask[:-depth, :])
    center_x = (rect[0] + (rect[2] - rect[0]) * center_u) * image_width
    center_y = (rect[1] + (rect[3] - rect[1]) * center_v) * image_height
    left, bottom = int(center_x - width_pixels / 2), int(center_y - height_pixels / 2)
    right, top = left + width_pixels, bottom + height_pixels
    if left < 0 or bottom < 0 or right > image_width or top > image_height:
        return
    paint_mask = np.clip((wear_mask[bottom:top, left:right] - 0.10) * 6.0, 0.0, 1.0)
    paint_alpha = (mask * paint_mask)[..., None]
    paint_rgb = np.array(color, dtype=np.float32)
    buf[bottom:top, left:right, :3] = buf[bottom:top, left:right, :3] * (1 - paint_alpha) + paint_rgb * paint_alpha


def _create_texture_atlas() -> bpy.types.Image:
    """
    Create and save the 3x3 texture atlas.

    Returns:
        The generated Blender image.
    """
    image_width, image_height = TEXTURE_WIDTH, TEXTURE_HEIGHT
    buf = np.zeros((image_height, image_width, 4), dtype=np.float32)
    buf[..., 3] = 1.0
    yy, xx = np.mgrid[0:image_height, 0:image_width]
    yy = yy.astype(np.float32)
    xx = xx.astype(np.float32)
    coarse_noise = _generate_value_noise(image_width, image_height, 92, 1)
    medium_noise = _generate_value_noise(image_width, image_height, 28, 2)
    fine_noise = _generate_value_noise(image_width, image_height, 9, 3)
    random_grain = _generate_value_noise(image_width, image_height, 1, 4)
    wear_mask = medium_noise * 0.6 + fine_noise * 0.4

    def atlas_cell_slices(column: int, row: int) -> Tuple[slice, slice, int, int]:
        """
        Return pixel slices and vertical bounds for an atlas cell.

        Args:
            column: Zero-based atlas column.
            row: Zero-based atlas row.

        Returns:
            Y and X slices followed by the cell's lower and upper pixel bounds.
        """
        bottom, top = row * image_height // 3, (row + 1) * image_height // 3
        left, right = column * image_width // 3, (column + 1) * image_width // 3
        return slice(bottom, top), slice(left, right), bottom, top

    for column, row, is_wall in ((0, 2, True), (1, 2, True), (0, 1, True), (1, 1, True), (2, 2, False)):
        slice_y, slice_x, bottom, top = atlas_cell_slices(column, row)
        normalized_height = (yy[slice_y, slice_x] - bottom) / float(top - bottom)
        pattern = 0.5 + 0.5 * np.sin(xx[slice_y, slice_x] * 1.05) * 0.30 + 0.5 * np.sin(yy[slice_y, slice_x] * 1.05) * 0.30
        value = (0.30 + pattern * 0.045 + coarse_noise[slice_y, slice_x] * 0.10 + medium_noise[slice_y, slice_x] * 0.035
             + (random_grain[slice_y, slice_x] - 0.5) * 0.055)
        if is_wall:
            value = value - 0.05 * (1.0 - normalized_height)
        color_components = np.stack([value * 0.96, value * 1.00, value * 0.76], axis=-1)
        if is_wall:
            mud_mask = np.clip((0.17 - normalized_height) / 0.17, 0.0, 1.0) * (0.35 + 0.65 * medium_noise[slice_y, slice_x])
            mud_mask = (mud_mask * 0.7)[..., None]
            color_components = color_components * (1 - mud_mask) + np.array([0.17, 0.13, 0.09], dtype=np.float32) * mud_mask
        buf[slice_y, slice_x, :3] = color_components

    slice_y, slice_x, _y0, _y1 = atlas_cell_slices(2, 1)
    wood_grain = 0.5 + 0.5 * np.sin(yy[slice_y, slice_x] * 0.45 + fine_noise[slice_y, slice_x] * 4.0 + coarse_noise[slice_y, slice_x] * 3.0)
    value = 0.62 + 0.10 * wood_grain + (random_grain[slice_y, slice_x] - 0.5) * 0.06 - medium_noise[slice_y, slice_x] * 0.10
    buf[slice_y, slice_x, :3] = np.stack([value * 0.52, value * 0.42, value * 0.30], axis=-1)

    slice_y, slice_x, _y0, _y1 = atlas_cell_slices(0, 0)
    stripe_pattern = 0.5 + 0.5 * np.sin(yy[slice_y, slice_x] * 2.1 + fine_noise[slice_y, slice_x] * 6.0)
    value = 0.22 + stripe_pattern * 0.05 + (random_grain[slice_y, slice_x] - 0.5) * 0.05
    color_components = np.stack([value, value * 1.00, value * 1.03], axis=-1)
    rust_mask = (np.clip((fine_noise[slice_y, slice_x] * 0.6 + medium_noise[slice_y, slice_x] * 0.4 - 0.62) * 6.0, 0.0, 1.0) * 0.45)[..., None]
    buf[slice_y, slice_x, :3] = color_components * (1 - rust_mask) + np.array([0.34, 0.18, 0.09], dtype=np.float32) * rust_mask

    slice_y, slice_x, _y0, _y1 = atlas_cell_slices(1, 0)
    weave_pattern = 0.5 + 0.5 * np.sin(xx[slice_y, slice_x] * 1.6) * np.sin(yy[slice_y, slice_x] * 0.7)
    value = 0.15 + weave_pattern * 0.03 + medium_noise[slice_y, slice_x] * 0.04 + (random_grain[slice_y, slice_x] - 0.5) * 0.03
    buf[slice_y, slice_x, :3] = np.stack([value * 0.96, value * 1.00, value * 0.78], axis=-1)

    slice_y, slice_x, _y0, _y1 = atlas_cell_slices(2, 0)
    rope_pattern = 0.5 + 0.5 * np.sin((xx[slice_y, slice_x] + yy[slice_y, slice_x]) * 0.9 + fine_noise[slice_y, slice_x] * 3.0)
    value = 0.46 + rope_pattern * 0.09 + (random_grain[slice_y, slice_x] - 0.5) * 0.05
    buf[slice_y, slice_x, :3] = np.stack([value * 1.00, value * 0.86, value * 0.58], axis=-1)

    stencil_color: RGBColor = (0.74, 0.73, 0.66)

    def height_to_uv(z_coord: float) -> float:
        """
        Map a model-space height to normalized canvas texture coordinates.

        Args:
            z_coord: Height in model-space units.

        Returns:
            Normalized vertical coordinate within the canvas texture cell.
        """
        return (z_coord - CANVAS_BASE_Z) / CANVAS_TEXTURE_HEIGHT

    for rect in (UV_FRONT, UV_BACK):
        _paint_stencil(buf, wear_mask, rect, WIDTH, CANVAS_TEXTURE_HEIGHT, "K.A.S.", 0.5, height_to_uv(0.50), 0.105, stencil_color)
        _paint_stencil(buf, wear_mask, rect, WIDTH, CANVAS_TEXTURE_HEIGHT, "SUPPLY DROP", 0.5, height_to_uv(0.385), 0.062, stencil_color)
    _paint_stencil(buf, wear_mask, UV_RIGHT, DEPTH, CANVAS_TEXTURE_HEIGHT, "K.A.S.", 0.5, height_to_uv(0.49), 0.090, stencil_color)
    _paint_stencil(buf, wear_mask, UV_RIGHT, DEPTH, CANVAS_TEXTURE_HEIGHT, "SUPPLY DROP", 0.5, height_to_uv(0.39), 0.055, stencil_color)
    _paint_stencil(buf, wear_mask, UV_LEFT, DEPTH, CANVAS_TEXTURE_HEIGHT, "K.A.S.", 0.5, height_to_uv(0.45), 0.090, stencil_color)
    _paint_stencil(buf, wear_mask, UV_TOP, WIDTH, DEPTH, "K.A.S.", 0.5, 0.5, 0.120, stencil_color)

    image = bpy.data.images.new(MODEL_NAME, image_width, image_height)
    image.colorspace_settings.name = 'sRGB'
    image.pixels.foreach_set(np.ascontiguousarray(buf, dtype=np.float32).ravel())
    os.makedirs(os.path.dirname(TEXTURE_OUTPUT_PATH), exist_ok=True)
    image.filepath_raw = TEXTURE_OUTPUT_PATH
    image.file_format = 'PNG'
    image.save()
    print("Texture saved: " + TEXTURE_OUTPUT_PATH)
    return image


def _mesh_bounds(mesh: bpy.types.Mesh) -> Tuple[float, float, float, float, float, float]:
    """
    Calculate a mesh's axis-aligned bounding box.

    Args:
        mesh: Mesh to measure.

    Returns:
        Bounds as ``(left, right, bottom, top, z0, z1)``.
    """
    x_coordinates = [value.co.x for value in mesh.vertices]
    y_coordinates = [value.co.y for value in mesh.vertices]
    zs = [value.co.z for value in mesh.vertices]
    return (min(x_coordinates), max(x_coordinates), min(y_coordinates), max(y_coordinates), min(zs), max(zs))


def _assign_uvs(mesh: bpy.types.Mesh, material: bpy.types.Material) -> None:
    """
    Project each face onto the atlas cell it belongs to.

    The canvas uses fixed extents (so the stencil lands where the texture expects it);
    every other material is box-projected into its own cell.

    Args:
        mesh: Mesh whose UV coordinates will be assigned.
        material: Material used to select the atlas cell.

    Returns:
        None.
    """
    uv_layer = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
    is_canvas = material is MAT_CANVAS
    if is_canvas:
        left, right, bottom, top, z0, z1 = -HALF_WIDTH, HALF_WIDTH, -HALF_DEPTH, HALF_DEPTH, CANVAS_BASE_Z, HEIGHT + DOME_HEIGHT
    else:
        left, right, bottom, top, z0, z1 = _mesh_bounds(mesh)
    distance_x, distance_y, distance_z = max(right - left, 1e-6), max(top - bottom, 1e-6), max(z1 - z0, 1e-6)

    for poly in mesh.polygons:
        normal = poly.normal
        if normal.y < -0.6:
            face_side = 'F'
        elif normal.y > 0.6:
            face_side = 'B'
        elif normal.x > 0.6:
            face_side = 'R'
        elif normal.x < -0.6:
            face_side = 'L'
        else:
            face_side = 'T'
        if is_canvas:
            uv_region = {'F': UV_FRONT, 'B': UV_BACK, 'R': UV_RIGHT,
                   'L': UV_LEFT, 'T': UV_TOP}[face_side]
        else:
            uv_region = MATERIAL_UV_REGIONS[material]
        region_u0, region_v0, region_u1, region_v1 = uv_region
        for loop_index in poly.loop_indices:
            co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            if face_side == 'F':
                normalized_u, normalized_v = (co.x - left) / distance_x, (co.z - z0) / distance_z
            elif face_side == 'B':
                normalized_u, normalized_v = 1.0 - (co.x - left) / distance_x, (co.z - z0) / distance_z
            elif face_side == 'R':
                normalized_u, normalized_v = (co.y - bottom) / distance_y, (co.z - z0) / distance_z
            elif face_side == 'L':
                normalized_u, normalized_v = 1.0 - (co.y - bottom) / distance_y, (co.z - z0) / distance_z
            else:
                normalized_u, normalized_v = (co.x - left) / distance_x, (co.y - bottom) / distance_y
            normalized_u = max(0.0, min(1.0, normalized_u))
            normalized_v = max(0.0, min(1.0, normalized_v))
            uv_layer.data[loop_index].uv = (
                region_u0 + (region_u1 - region_u0) * normalized_u,
                region_v0 + (region_v1 - region_v0) * normalized_v,
            )


def finalize_and_export(name: str, texture_image: bpy.types.Image) -> None:
    """
    Create Blender objects, bind the atlas, and export the FBX.

    Args:
        name: Name used for the collection, root object, and mesh objects.
        texture_image: Texture atlas assigned to the generated materials.

    Returns:
        None.
    """
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    root_object = bpy.data.objects.new(name, None)
    collection.objects.link(root_object)
    for material, bm in _material_bmeshes.items():
        if material not in DOUBLE_SIDED_MATERIALS:
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        mesh = bpy.data.meshes.new(name + "_" + material.name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(material)
        mesh_object = bpy.data.objects.new(name + "_" + material.name, mesh)
        mesh_object.parent = root_object
        collection.objects.link(mesh_object)
        smooth_shading = material in SMOOTH_SHADING_MATERIALS
        for polygon in mesh.polygons:
            polygon.use_smooth = smooth_shading
        if smooth_shading:
            try:
                mesh.set_sharp_from_angle(angle=math.radians(40))
            except Exception:
                pass
        _assign_uvs(mesh, material)
        try:
            node_tree = material.node_tree
            bsdf_node = node_tree.nodes.get("Principled BSDF")
            if bsdf_node is not None:
                texture_node = node_tree.nodes.new("ShaderNodeTexImage")
                texture_node.image = texture_image
                texture_node.location = (-320, 260)
                texture_node.interpolation = 'Smart'
                uv_map_node = node_tree.nodes.new("ShaderNodeUVMap")
                uv_map_node.uv_map = "UVMap"
                uv_map_node.location = (-540, 260)
                node_tree.links.new(uv_map_node.outputs["UV"], texture_node.inputs["Vector"])
                node_tree.links.new(texture_node.outputs["Color"], bsdf_node.inputs["Base Color"])
        except Exception as exc:
            print("Warning: could not link texture: " + str(exc))

    try:
        for area in bpy.context.screen.areas:
            if area.type == 'VIEW_3D':
                for sp in area.spaces:
                    if sp.type == 'VIEW_3D':
                        sp.shading.type = 'MATERIAL'
                        sp.overlay.show_relationship_lines = False
                        sp.overlay.show_extras = False
    except Exception:
        pass

    os.makedirs(MODEL_DIR, exist_ok=True)
    try:
        bpy.ops.export_scene.fbx(filepath=FBX_OUTPUT_PATH, use_selection=False,
                                 path_mode='RELATIVE', embed_textures=False,
                                 axis_forward='-Z', axis_up='Y', global_scale=1.0,
                                 apply_scale_options='FBX_SCALE_NONE',
                                 use_mesh_modifiers=True, bake_anim=False,
                                 object_types={'MESH'})
        print("FBX saved: " + FBX_OUTPUT_PATH)
    except Exception as exc:
        print("ERROR exporting FBX: " + str(exc))


    print(name + " is ready.")


build_wooden_base()
build_canvas_body(MAT_CANVAS)

canvas_bvh: BVHTree = BVHTree.FromBMesh(_get_material_bmesh(MAT_CANVAS))
build_vertical_straps(canvas_bvh)
build_belts(canvas_bvh)
build_corner_bindings(canvas_bvh)
build_hardware(canvas_bvh)
if INCLUDE_LIFTING_RIG:
    build_lifting_rig(canvas_bvh)

texture_image: bpy.types.Image = _create_texture_atlas()
finalize_and_export(MODEL_NAME, texture_image)

print("")
print("--- Summary ---")
print("Model   : " + FBX_OUTPUT_PATH)
print("Texture : " + TEXTURE_OUTPUT_PATH)
print("Dimensions: %.2f x %.2f x %.2f m (without lifting rig)" % (WIDTH, DEPTH, HEIGHT + DOME_HEIGHT))