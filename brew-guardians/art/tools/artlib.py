"""Small Blender toolkit for building stylised game assets from code.

Organic bodies are metaballs (blobs that melt into each other) converted to
a mesh and vertex-painted by the nearest blob. Hard details (eyes, horns,
crystals) are regular meshes. Each asset is joined into one textured mesh
(plus an optional *_Glow mesh for neon parts), baked to an image texture and
exported as FBX for Roblox Studio's 3D importer.

Coordinates: X right, Y back (front faces -Y), Z up, ground at z = 0.
"""

import math
import os

import bpy  # must come first: it provides addon_utils, bmesh and mathutils
import addon_utils
import bmesh
from mathutils import Euler, Matrix, Quaternion, Vector


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    addon_utils.enable("cycles", default_set=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "Standard"


def hexcol(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _paint(mesh, color_fn):
    """Fill a 'Col' corner colour attribute using color_fn(vertex_co) -> rgb."""
    attr = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for loop in mesh.loops:
        c = color_fn(mesh.vertices[loop.vertex_index].co)
        attr.data[loop.index].color = (c[0], c[1], c[2], 1.0)
    mesh.color_attributes.active_color = attr
    return attr


class Blob:
    """One metaball element with a colour."""

    def __init__(self, co, radius, color, size=(1, 1, 1), rot=(0, 0, 0), kind="ELLIPSOID", stiffness=2.0, negative=False):
        self.co = Vector(co)
        self.radius = radius
        self.color = color
        self.size = Vector(size)
        self.rot = Euler([math.radians(a) for a in rot]).to_quaternion()
        self.kind = kind
        self.stiffness = stiffness
        self.negative = negative

    def ndist(self, p):
        local = self.rot.inverted() @ (Vector(p) - self.co)
        s = self.size * self.radius
        return Vector((local.x / s.x, local.y / s.y, local.z / s.z)).length


class Asset:
    def __init__(self, name, flat=False):
        self.name = name
        self.flat = flat  # keep faceted shading (rocks, crystals)
        self.blobs = []
        self.solids = []  # (object, glow)

    # -- organic body -------------------------------------------------
    def blob(self, *args, **kwargs):
        b = Blob(*args, **kwargs)
        self.blobs.append(b)
        return b

    def build_body(self, voxel=0.012, smooth=12, smooth_factor=0.6):
        """Fuse every blob into one watertight surface with soft seams.

        Each blob is an exact ellipsoid; a voxel remesh unions them and a
        Laplacian-style smooth rounds the junctions like clay.
        """
        parts = []
        for b in self.blobs:
            if b.negative:
                continue
            bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=1)
            o = bpy.context.active_object
            o.scale = b.size * b.radius
            o.rotation_mode = "QUATERNION"
            o.rotation_quaternion = b.rot
            o.location = b.co
            parts.append(o)
        for o in bpy.context.selected_objects:
            o.select_set(False)
        for o in parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        bpy.ops.object.join()
        body = bpy.context.active_object
        body.name = self.name + "_body"
        rem = body.modifiers.new("remesh", "REMESH")
        rem.mode = "VOXEL"
        rem.voxel_size = voxel
        rem.use_smooth_shade = True
        bpy.ops.object.modifier_apply(modifier="remesh")
        if smooth > 0:
            sm = body.modifiers.new("smooth", "SMOOTH")
            sm.factor = smooth_factor
            sm.iterations = smooth
            bpy.ops.object.modifier_apply(modifier="smooth")
        for p in body.data.polygons:
            p.use_smooth = True

        positive = [b for b in self.blobs if not b.negative]

        def color_at(p):
            best, second = None, None
            for b in positive:
                d = b.ndist(p)
                if best is None or d < best[0]:
                    best, second = (d, b.color), best
                elif second is None or d < second[0]:
                    second = (d, b.color)
            if second is None:
                return best[1]
            # soft edge between neighbouring colour patches
            t = max(0.0, min(1.0, (second[0] - best[0]) / 0.12))
            return mix(second[1], best[1], 0.5 + 0.5 * t)

        _paint(body.data, color_at)
        self.solids.append((body, False))
        return body

    # -- hard details -------------------------------------------------
    def _solid(self, mesh_fn, loc, scale, rot, color, glow=False, smooth=True):
        mesh_fn()
        obj = bpy.context.active_object
        obj.location = loc
        obj.scale = scale
        obj.rotation_euler = Euler([math.radians(a) for a in rot])
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if smooth:
            for p in obj.data.polygons:
                p.use_smooth = True
        col = color
        _paint(obj.data, lambda p: col)
        self.solids.append((obj, glow))
        return obj

    def sphere(self, loc, scale, color, rot=(0, 0, 0), glow=False, segments=24):
        return self._solid(lambda: bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, radius=1),
                           loc, scale, rot, color, glow)

    def cone(self, loc, radius, height, color, rot=(0, 0, 0), glow=False, verts=12, tip=0.0):
        # base at loc, pointing along local +Z
        def make():
            bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=tip, depth=height, location=(0, 0, height / 2))
            o = bpy.context.active_object
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.transform_apply(location=True)
        return self._solid(make, loc, (1, 1, 1), rot, color, glow)

    def cylinder(self, loc, radius, height, color, rot=(0, 0, 0), glow=False, verts=16):
        def make():
            bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=height, location=(0, 0, height / 2))
            o = bpy.context.active_object
            bpy.ops.object.transform_apply(location=True)
        return self._solid(make, loc, (1, 1, 1), rot, color, glow)

    def crystal(self, loc, radius, height, color, rot=(0, 0, 0), glow=False):
        """Hexagonal prism with a pointed tip."""
        def make():
            bm = bmesh.new()
            ring_lo, ring_hi = [], []
            for i in range(6):
                a = i / 6 * math.tau
                ring_lo.append(bm.verts.new((math.cos(a) * radius, math.sin(a) * radius, 0)))
                ring_hi.append(bm.verts.new((math.cos(a) * radius, math.sin(a) * radius, height * 0.75)))
            tip = bm.verts.new((0, 0, height))
            bm.faces.new(list(reversed(ring_lo)))
            for i in range(6):
                j = (i + 1) % 6
                bm.faces.new((ring_lo[i], ring_lo[j], ring_hi[j], ring_hi[i]))
                bm.faces.new((ring_hi[i], ring_hi[j], tip))
            me = bpy.data.meshes.new("crystal")
            bm.to_mesh(me)
            o = _link(bpy.data.objects.new("crystal", me))
            for ob in bpy.context.selected_objects:
                ob.select_set(False)
            bpy.context.view_layer.objects.active = o
            o.select_set(True)
        obj = self._solid(make, loc, (1, 1, 1), rot, color, glow, smooth=False)
        return obj

    def lathe(self, profile, color_fn, segments=48, glow=False, loc=(0, 0, 0)):
        """Spin a list of (radius, z) points around Z into a closed-top-less shell."""
        bm = bmesh.new()
        rings = []
        for r, z in profile:
            ring = []
            for i in range(segments):
                ang = i / segments * math.tau
                ring.append(bm.verts.new((loc[0] + math.cos(ang) * r, loc[1] + math.sin(ang) * r, loc[2] + z)))
            rings.append(ring)
        for k in range(len(rings) - 1):
            a, b = rings[k], rings[k + 1]
            for i in range(segments):
                j = (i + 1) % segments
                bm.faces.new((a[i], a[j], b[j], b[i]))
        me = bpy.data.meshes.new("lathe")
        bm.to_mesh(me)
        obj = _link(bpy.data.objects.new("lathe", me))
        for p in me.polygons:
            p.use_smooth = True
        _paint(me, color_fn)
        self.solids.append((obj, glow))
        return obj

    def rock(self, loc, size, color_fn, seed=1, detail=2, glow=False):
        """Faceted low-poly rock: a displaced icosphere."""
        import random
        rnd = random.Random(seed)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=detail, radius=1)
        obj = bpy.context.active_object
        for v in obj.data.vertices:
            v.co *= 1.0 + rnd.uniform(-0.18, 0.18)
            if v.co.z < -0.3:
                v.co.z = -0.3 + (v.co.z + 0.3) * 0.3  # flatten the underside
        obj.scale = size
        obj.location = loc
        obj.rotation_euler = (0, 0, rnd.uniform(0, math.tau))
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        me = obj.data
        attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        for poly in me.polygons:
            c = color_fn(poly.center, poly.normal)
            for li in poly.loop_indices:
                attr.data[li].color = (*c, 1.0)
            poly.use_smooth = False
        me.color_attributes.active_color = attr
        self.solids.append((obj, glow))
        return obj

    # -- placing details on the body surface ---------------------------
    def hit(self, x, z, direction=(0, 1, 0), y=None):
        """Ray-cast onto the fused body. By default fires from the front
        (-Y) toward +Y at (x, z). Returns (point, outward normal)."""
        body = next(o for o, g in self.solids if o.name.endswith("_body"))
        d = Vector(direction).normalized()
        origin = Vector((x, -10.0, z)) if y is None else Vector((x, y, z)) - d * 10.0
        ok, loc, normal, _ = body.ray_cast(origin, d)
        if not ok:
            raise RuntimeError(f"{self.name}: ray at ({x}, {z}) missed the body")
        return loc, normal

    @staticmethod
    def frame(normal):
        """Rotation whose local -Y points along `normal`, keeping +Z up."""
        n = Vector(normal).normalized()
        yax = -n
        up = Vector((0, 0, 1))
        zax = (up - up.dot(yax) * yax)
        if zax.length < 1e-4:
            zax = Vector((0, 1, 0))
        zax.normalize()
        xax = yax.cross(zax)
        m = Matrix((xax, yax, zax)).transposed()
        return m.to_quaternion()

    def stick(self, loc, normal, offset, scale, color, glow=False, rot=(0, 0, 0)):
        """Sphere placed in the surface frame: offset is (right, out, up)."""
        q = self.frame(normal)
        o = Vector((offset[0], -offset[1], offset[2]))
        world = loc + q @ o
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1)
        obj = bpy.context.active_object
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = q @ Euler([math.radians(a) for a in rot]).to_quaternion()
        obj.scale = scale
        obj.location = world
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        for p in obj.data.polygons:
            p.use_smooth = True
        col = color
        _paint(obj.data, lambda p: col)
        self.solids.append((obj, glow))
        return obj

    def spike(self, loc, direction, radius, height, color, glow=False, verts=12, bend=None):
        """Cone with its base at `loc` pointing along `direction`."""
        d = Vector(direction).normalized()
        if bend is not None:
            d = (d + Vector(bend)).normalized()
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0, depth=height, location=(0, 0, height / 2))
        obj = bpy.context.active_object
        bpy.ops.object.transform_apply(location=True)
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
        obj.location = loc
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        for p in obj.data.polygons:
            p.use_smooth = True
        col = color
        _paint(obj.data, lambda p: col)
        self.solids.append((obj, glow))
        return obj

    def eyes(self, spread, z, size, iris=None, lid=None, tilt=12, sink=0.35):
        """Big glossy cartoon eyes ray-cast onto the face at (+-spread, z)."""
        iris = iris or hexcol("3b2a5a")
        for side in (-1, 1):
            loc, n = self.hit(side * spread, z)
            r = (0, side * -tilt * 0.3, side * tilt)
            self.stick(loc, n, (0, size * (0.15 - sink), 0), (size, size * 0.62, size * 1.18), (1, 1, 1), rot=r)
            self.stick(loc, n, (0, size * (0.5 - sink), -size * 0.06), (size * 0.72, size * 0.32, size * 0.86), iris, rot=r)
            self.stick(loc, n, (0, size * (0.68 - sink), -size * 0.1), (size * 0.4, size * 0.2, size * 0.5), hexcol("0d0a12"), rot=r)
            self.stick(loc, n, (side * size * 0.24, size * (0.84 - sink), size * 0.32), (size * 0.22, size * 0.1, size * 0.22), (1, 1, 1))
            self.stick(loc, n, (-side * size * 0.2, size * (0.8 - sink), -size * 0.38), (size * 0.1, size * 0.05, size * 0.1), (1, 1, 1))
            if lid:
                self.stick(loc, n, (0, size * (0.2 - sink), size * 0.78), (size * 1.15, size * 0.7, size * 0.42), lid, rot=(0, side * 12, side * tilt))

    # -- finishing ----------------------------------------------------
    def finish(self, out_dir, tex_size=1024, max_tris=9000, decimate=True):
        """Join, decimate, UV, bake, and return the objects to export."""
        results = []
        for glow in (False, True):
            objs = [o for o, g in self.solids if g == glow]
            if not objs:
                continue
            for o in bpy.context.selected_objects:
                o.select_set(False)
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            if len(objs) > 1:
                bpy.ops.object.join()
            obj = bpy.context.active_object
            obj.name = self.name + ("_Glow" if glow else "")
            obj.data.name = obj.name  # each part keeps its own smooth/flat shading
            tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
            if decimate and tris > max_tris:
                mod = obj.modifiers.new("dec", "DECIMATE")
                mod.ratio = max_tris / tris
                bpy.ops.object.modifier_apply(modifier="dec")
            results.append((obj, glow))

        for obj, glow in results:
            self._bake(obj, out_dir, tex_size if not glow else 256)
        return [o for o, _ in results]

    def _bake(self, obj, out_dir, size):
        for o in bpy.context.selected_objects:
            o.select_set(False)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01)
        bpy.ops.object.mode_set(mode="OBJECT")

        mat = bpy.data.materials.new(obj.name + "_mat")
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
        img = bpy.data.images.new(obj.name + "_tex", size, size)
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        nt.nodes.active = tex
        obj.data.materials.clear()
        obj.data.materials.append(mat)

        sc = bpy.context.scene
        sc.render.bake.use_pass_direct = False
        sc.render.bake.use_pass_indirect = False
        sc.render.bake.use_pass_color = True
        sc.render.bake.margin = 8
        sc.cycles.samples = 1
        bpy.ops.object.bake(type="DIFFUSE")
        path = os.path.join(out_dir, obj.name + ".png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()

        # swap to the baked texture for export and preview
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.55
        if obj.name.endswith("_Glow"):
            bsdf.inputs["Emission Color"].default_value = (1, 1, 1, 1)
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 3.0
        sc.cycles.samples = 48


def export_fbx(objs, path):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
        bake_space_transform=True,
    )


def preview_scene(target=(0, 0, 0.5), distance=4.0, angle=-25, height=0.35, lens=50, ground=hexcol("8cbf6e")):
    sc = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
    plane = bpy.context.active_object
    mat = bpy.data.materials.new("ground")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*ground, 1)
    plane.data.materials.append(mat)

    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.8, 1.0, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.55

    sun = _link(bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")))
    sun.data.energy = 2.2
    sun.data.angle = math.radians(8)
    sun.rotation_euler = Euler((math.radians(50), 0, math.radians(35)))
    fill = _link(bpy.data.objects.new("fill", bpy.data.lights.new("fill", "AREA")))
    fill.data.energy = 120
    fill.data.size = 6
    fill.location = (-4, -4, 3)
    fill.rotation_euler = Euler((math.radians(60), 0, math.radians(-45)))

    cam = _link(bpy.data.objects.new("cam", bpy.data.cameras.new("cam")))
    cam.data.lens = lens
    a = math.radians(angle)
    t = Vector(target)
    cam.location = t + Vector((math.sin(a) * distance, -math.cos(a) * distance, height * distance))
    direction = t - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    return cam


def render(path, w=900, h=640, samples=48):
    sc = bpy.context.scene
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.cycles.samples = samples
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
