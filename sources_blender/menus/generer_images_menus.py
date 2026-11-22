# OrbMeka 0.0.8.14 (#247, demande de l'utilisateur) : images des menus, faites ici dans Blender (tout original) :
# menu des actions (B + T), actions de la fabrication (O + F), main et poche de l'inventaire (O + I).
# Toutes dans le même style : même angle (de trois quarts, un peu au-dessus), même lumière (principale en haut à gauche,
# d'appoint à droite, contre-jour qui détache les bords sur le fond sombre des menus), fond transparent, fin contour sombre
# et petite ombre. Formes et couleurs du jeu : modèles sortis du jeu par tools/modeles_menus.gd (modeles/*.glb,
# couleurs.json) ; main : celle du jeu (même construction que ../main/generer_main.py), posée selon l'action, dans les
# trois couleurs de peau du jeu (le jeu prend celle du personnage). Sol, herbe, terre et sable : couleurs du shader du sol
# (shaders/terrain_surface.gdshader).
# Résultat : assets/ui/menus/<nom>.png (192 × 192) ; images avec la main : <nom>_light.png, _brown.png, _dark.png.
# Lancer dans Blender : exec(open(r"<dossier du jeu>/sources_blender/menus/generer_images_menus.py").read())
# Variable ORBMEKA_IMAGES=nom1,nom2 : seulement ces images ; ORBMEKA_PEAUX=light : seulement cette peau.
import bpy, bmesh, math, os, json, random, struct, zlib
import numpy as np
from mathutils import Vector, Matrix, Euler
from bpy_extras.object_utils import world_to_camera_view

GAME = os.environ.get("ORBMEKA_GAME", r"C:\Users\Dev\Desktop\Godot\orb-meka")
MODELS = os.path.join(GAME, "sources_blender", "menus", "modeles")
OUT = os.path.join(GAME, "assets", "ui", "menus")
TEMP = os.path.join(os.environ.get("TEMP", GAME), "orbmeka_images_menus")
SCENE = "OrbMeka_Images_Menus"
SIZE = 192
RENDER = SIZE * 4
# Angle de vue (degrés) : la caméra à droite et au-dessus, le même pour toutes les images.
AZIMUTH = 28.0
ELEVATION = 30.0
LENS = 70.0
# Part de l'image occupée par la chose (le reste : contour et ombre).
FILL = 0.9
SKINS = ["light", "brown", "dark"]
# Contour (pixels du rendu, 4 fois l'image finale) et ombre portée.
OUTLINE_RADIUS = 8
OUTLINE_COLOR = (0.07, 0.055, 0.1)
SHADOW_OFFSET = (10, 12)
SHADOW_BLUR = 17
SHADOW_ALPHA = 0.33

# Lumières : [nom, force, flou des ombres (degrés), couleur, sens où va la lumière].
LIGHTS = [
    ("Principale", 3.6, 6.0, (1.0, 0.95, 0.86), (0.49, 0.62, -0.62)),
    ("Appoint", 1.1, 20.0, (0.82, 0.88, 1.0), (-0.92, -0.08, -0.38)),
    ("ContreJour", 2.4, 4.0, (1.0, 0.97, 0.92), (0.33, -0.61, -0.6)),
]

COLORS = json.load(open(os.path.join(MODELS, "couleurs.json"), encoding="utf-8"))


def lin(c):
    """Couleur sRGB du jeu (0 à 1) vers la couleur linéaire de Blender."""
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c[:3])


# --- Scène, studio et lumières ---

def studio():
    scene = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    bpy.context.window.scene = scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    render = scene.render
    try:
        render.engine = "BLENDER_EEVEE"
    except TypeError:
        pass
    render.resolution_x = RENDER
    render.resolution_y = RENDER
    render.resolution_percentage = 100
    render.film_transparent = True
    render.image_settings.file_format = "PNG"
    render.image_settings.color_mode = "RGBA"
    render.image_settings.color_depth = "8"
    eevee = scene.eevee
    for name, value in [("taa_render_samples", 64), ("use_shadows", True), ("use_gtao", True), ("gtao_distance", 0.05),
                        ("use_raytracing", True), ("shadow_ray_count", 3), ("shadow_step_count", 12),
                        ("fast_gi_distance", 0.05), ("use_fast_gi", True)]:
        if hasattr(eevee, name):
            try:
                setattr(eevee, name, value)
            except (TypeError, AttributeError):
                pass
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    world = bpy.data.worlds.get(SCENE) or bpy.data.worlds.new(SCENE)
    world.use_nodes = True
    background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs[0].default_value = (0.62, 0.68, 0.78, 1.0)
    background.inputs[1].default_value = 0.55
    scene.world = world
    # Principale (chaude, en haut à gauche), d'appoint (froide, à droite), contre-jour (bords clairs).
    for name, energy, angle, color, travel in LIGHTS:
        data = bpy.data.lights.get(name) or bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = math.radians(angle)
        data.color = color
        light = bpy.data.objects.new(name, data)
        light.rotation_euler = Vector(travel).normalized().to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(light)
    camera_data = bpy.data.cameras.get(SCENE) or bpy.data.cameras.new(SCENE)
    camera_data.lens = LENS
    camera_data.sensor_fit = "HORIZONTAL"
    camera_data.sensor_width = 36.0
    camera_data.clip_start = 0.002
    camera_data.clip_end = 50.0
    camera = bpy.data.objects.new("Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return scene


def clear_subject(scene):
    for obj in list(scene.objects):
        if obj.get("sujet"):
            bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def subject(obj, frame=True):
    """Objet de l'image (effacé à l'image suivante) ; frame : compte pour le cadrage."""
    obj["sujet"] = True
    obj["cadre"] = frame
    scene = bpy.context.scene
    if obj.name not in scene.collection.objects:
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        scene.collection.objects.link(obj)
    return obj


# --- Matières ---

_materials = {}


def _bsdf_tree(mat):
    mat.use_nodes = True
    tree = mat.node_tree
    tree.nodes.clear()
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    tree.links.new(bsdf.outputs[0], out.inputs[0])
    return tree, bsdf


def _set(bsdf, **values):
    names = {"roughness": "Roughness", "metallic": "Metallic", "specular": "Specular IOR Level", "coat": "Coat Weight",
             "subsurface": "Subsurface Weight", "sheen": "Sheen Weight", "emission": "Emission Strength"}
    for key, value in values.items():
        name = names[key]
        if name in bsdf.inputs:
            bsdf.inputs[name].default_value = value


def principled(name, color, roughness=0.8, metallic=0.0, specular=0.5, coat=0.0, subsurface=0.0, sheen=0.0):
    if name in _materials:
        return _materials[name]
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    tree, bsdf = _bsdf_tree(mat)
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    _set(bsdf, roughness=roughness, metallic=metallic, specular=specular, coat=coat, subsurface=subsurface, sheen=sheen)
    if subsurface > 0.0 and "Subsurface Radius" in bsdf.inputs:
        bsdf.inputs["Subsurface Radius"].default_value = (0.012, 0.005, 0.003)
    _materials[name] = mat
    return mat


def _two_tone(tree, coords, dark, light, scale, detail=6.0, contrast=(0.35, 0.7)):
    """Deux tons mêlés par un bruit (comme le shader du sol) : (couleur, bruit)."""
    noise = tree.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    tree.links.new(coords, noise.inputs["Vector"])
    ramp = tree.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = contrast[0]
    ramp.color_ramp.elements[0].color = (*dark, 1.0)
    ramp.color_ramp.elements[1].position = contrast[1]
    ramp.color_ramp.elements[1].color = (*light, 1.0)
    tree.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    return ramp.outputs["Color"], noise.outputs["Fac"]


def _mix_color(tree, factor, first, second):
    mix = tree.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    tree.links.new(factor, mix.inputs["Factor"])
    for index, value in [(6, first), (7, second)]:
        if isinstance(value, tuple):
            mix.inputs[index].default_value = (*value, 1.0)
        else:
            tree.links.new(value, mix.inputs[index])
    return mix.outputs[2]


def _bump(tree, bsdf, height, strength, distance=0.02):
    node = tree.nodes.new("ShaderNodeBump")
    node.inputs["Strength"].default_value = strength
    node.inputs["Distance"].default_value = distance
    tree.links.new(height, node.inputs["Height"])
    tree.links.new(node.outputs["Normal"], bsdf.inputs["Normal"])


# Tons du sol (linéaires, comme dans shaders/terrain_surface.gdshader) : [foncé, clair, échelle du bruit, relief].
GROUND_LOOKS = {
    "herbe": [(0.12, 0.19, 0.03), (0.33, 0.42, 0.1), 45.0, 0.35],
    "terre": [(0.105, 0.062, 0.032), (0.3, 0.19, 0.095), 40.0, 0.5],
    "sable": [(0.37, 0.26, 0.13), (0.56, 0.41, 0.21), 70.0, 0.2],
}


def noisy(name, dark, light, scale=8.0, roughness=0.85, bump=0.25, specular=0.4, coat=0.0, spots=None, object_space=True):
    """Matière à deux tons, relief léger ; spots : (couleur, seuil, rugosité) taches (croûte du silex)."""
    if name in _materials:
        return _materials[name]
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    tree, bsdf = _bsdf_tree(mat)
    coords = tree.nodes.new("ShaderNodeTexCoord").outputs["Object" if object_space else "Generated"]
    color, fac = _two_tone(tree, coords, dark, light, scale)
    _set(bsdf, roughness=roughness, specular=specular, coat=coat)
    if spots:
        spot_noise = tree.nodes.new("ShaderNodeTexNoise")
        spot_noise.inputs["Scale"].default_value = scale * 0.55
        spot_noise.inputs["Detail"].default_value = 3.0
        tree.links.new(coords, spot_noise.inputs["Vector"])
        spot = tree.nodes.new("ShaderNodeMapRange")
        spot.inputs["From Min"].default_value = spots[1]
        spot.inputs["From Max"].default_value = spots[1] + 0.05
        tree.links.new(spot_noise.outputs["Fac"], spot.inputs["Value"])
        color = _mix_color(tree, spot.outputs["Result"], color, spots[0])
        rough = tree.nodes.new("ShaderNodeMapRange")
        tree.links.new(spot.outputs["Result"], rough.inputs["Value"])
        rough.inputs["To Min"].default_value = roughness
        rough.inputs["To Max"].default_value = spots[2]
        tree.links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    tree.links.new(color, bsdf.inputs["Base Color"])
    if bump > 0.0:
        _bump(tree, bsdf, fac, bump)
    _materials[name] = mat
    return mat


def mat_ground(kind):
    look = GROUND_LOOKS[kind]
    return noisy("Sol_" + kind, look[0], look[1], scale=look[2], roughness=0.92, bump=look[3])


def mat_stone():
    return noisy("Pierre", (0.2, 0.195, 0.185), (0.48, 0.465, 0.44), scale=9.0, roughness=0.8, bump=0.3)


def mat_flint():
    # Silex : cassure sombre et brillante, croûte blanchâtre et mate par taches.
    return noisy("Silex", (0.03, 0.03, 0.036), (0.085, 0.082, 0.095), scale=7.0, roughness=0.2, bump=0.06,
                 specular=0.9, spots=((0.62, 0.58, 0.5), 0.57, 0.9))


def mat_flint_inside():
    return principled("Silex_cassure", (0.04, 0.039, 0.046), roughness=0.16, specular=0.95, coat=0.4)


def mat_skin(skin):
    return principled("Peau_" + skin, lin(COLORS["peaux"][skin]), roughness=0.55, subsurface=0.15, specular=0.35)


def mat_bark():
    if "Ecorce" in _materials:
        return _materials["Ecorce"]
    mat = bpy.data.materials.new("Ecorce")
    tree, bsdf = _bsdf_tree(mat)
    image = tree.nodes.new("ShaderNodeTexImage")
    image.image = bpy.data.images.load(os.path.join(GAME, "assets", "trees", "ecorce_pommier.png"), check_existing=True)
    coords = tree.nodes.new("ShaderNodeTexCoord")
    tree.links.new(coords.outputs["UV"], image.inputs["Vector"])
    # Comme dans le jeu : l'écorce un peu éclaircie.
    tint = tree.nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    tree.links.new(image.outputs["Color"], tint.inputs[6])
    tint.inputs[7].default_value = (*[c * 1.6 for c in COLORS.get("ecorce_eclaircie", [1.7, 1.55, 1.4])], 1.0)
    tree.links.new(tint.outputs[2], bsdf.inputs["Base Color"])
    _bump(tree, bsdf, image.outputs["Color"], 0.4, 0.01)
    _set(bsdf, roughness=0.9, specular=0.3)
    _materials["Ecorce"] = mat
    return mat


def mat_wood():
    # Bois clair de la fente (sous l'écorce).
    return noisy("Bois", (0.4, 0.27, 0.13), (0.6, 0.44, 0.24), scale=40.0, roughness=0.75, bump=0.1)


def mat_white():
    # Flèches : blanc lumineux (lisibles sur le fond sombre des menus).
    if "Fleche" in _materials:
        return _materials["Fleche"]
    mat = principled("Fleche", (0.95, 0.95, 0.95), roughness=0.4)
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    if "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (1.0, 1.0, 1.0, 1.0)
        _set(bsdf, emission=0.5)
    return mat


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


# --- Formes ---

def mesh_object(name, bm, smooth=True):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return subject(obj)


def place(obj, location=(0, 0, 0), rotation=(0, 0, 0), scale=1.0):
    obj.location = location
    obj.rotation_euler = Euler([math.radians(r) for r in rotation])
    obj.scale = (scale, scale, scale) if isinstance(scale, (int, float)) else scale
    return obj


def import_model(name):
    """Un modèle sorti du jeu (modeles/<nom>.glb) : un seul objet, à sa taille du jeu."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, name + ".glb"))
    made = [obj for obj in bpy.data.objects if obj not in before]
    meshes = [obj for obj in made if obj.type == "MESH"]
    for obj in meshes:
        matrix = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = matrix
    for obj in made:
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    obj = meshes[0]
    obj.name = name
    # Le modèle tel quel (repère du jeu, y vers le haut devenu z vers le haut).
    obj.data.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
    return subject(obj)


def blob(name, radius, seed, squash=(1.0, 1.0, 1.0), rough=0.3, subdiv=2):
    """Petit morceau irrégulier (miette de terre, caillou)."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    bumps = [(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized(), rng.uniform(-rough, rough))
             for _ in range(7)]
    for v in bm.verts:
        d = v.co.normalized()
        k = 1.0 + sum(b * max(0.0, d.dot(n)) ** 3 for n, b in bumps)
        v.co = Vector((d.x * squash[0], d.y * squash[1], d.z * squash[2])) * radius * k
    return mesh_object(name, bm)


def heap(name, radius, height, seed, rings=14, sides=32):
    """Petit tas bosselé (une poignée de matière), base à z = 0."""
    rng = random.Random(seed)
    lumps = [(Vector((rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7))), rng.uniform(0.15, 0.35), rng.uniform(-0.2, 0.3))
             for _ in range(8)]

    def lift(flat, r):
        bump = sum(l[2] * math.exp(-((flat - l[0]).length_squared) / (l[1] * l[1])) for l in lumps)
        return height * max(1.0 - r * r, 0.0) ** 0.7 * (1.0 + bump * (1.0 - r)), bump

    bm = bmesh.new()
    center = bm.verts.new((0.0, 0.0, lift(Vector((0.0, 0.0)), 0.0)[0]))
    rows = []
    for ring in range(1, rings + 1):
        r = ring / rings
        row = []
        for side in range(sides):
            angle = math.tau * side / sides
            flat = Vector((math.cos(angle), math.sin(angle))) * r
            z, bump = lift(flat, r)
            row.append(bm.verts.new((flat.x * radius * (1 + bump * 0.1), flat.y * radius * (1 + bump * 0.1), z)))
        rows.append(row)
    for side in range(sides):
        bm.faces.new((center, rows[0][side], rows[0][(side + 1) % sides]))
    for ring in range(rings - 1):
        for side in range(sides):
            bm.faces.new((rows[ring][side], rows[ring + 1][side], rows[ring + 1][(side + 1) % sides], rows[ring][(side + 1) % sides]))
    bm.faces.new(list(reversed(rows[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm)


def uv_cylinder(obj):
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new()
    uv = mesh.uv_layers.active.data
    for poly in mesh.polygons:
        for index in poly.loop_indices:
            co = mesh.vertices[mesh.loops[index].vertex_index].co
            uv[index].uv = (math.atan2(co.y, co.x) / math.tau + 0.5, co.z * 4.0)


def stick(name, start, end, radius, tip_radius=None, sides=14):
    """Bâton : cylindre un peu conique de start à end, en écorce."""
    bm = bmesh.new()
    tip_radius = radius * 0.85 if tip_radius is None else tip_radius
    length = (Vector(end) - Vector(start)).length
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=tip_radius, depth=length)
    obj = mesh_object(name, bm)
    uv_cylinder(obj)
    direction = (Vector(end) - Vector(start)).normalized()
    obj.matrix_world = Matrix.Translation((Vector(start) + Vector(end)) * 0.5) @ direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    return assign(obj, mat_bark())


def arrow(name, start, end, width=0.03):
    """Flèche blanche (tige et pointe), de start vers end."""
    bm = bmesh.new()
    length = (Vector(end) - Vector(start)).length
    head = min(length * 0.5, width * 3.4)
    shaft = bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=width * 0.5, radius2=width * 0.5, depth=length - head)
    for v in shaft["verts"]:
        v.co.z += (length - head) * 0.5
    tip = bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=width * 1.6, radius2=0.0, depth=head)
    for v in tip["verts"]:
        v.co.z += length - head * 0.5
    obj = mesh_object(name, bm)
    direction = (Vector(end) - Vector(start)).normalized()
    obj.matrix_world = Matrix.Translation(Vector(start)) @ direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    return assign(obj, mat_white())


def ground(name, size=(1.0, 0.8), depth=0.3, top=None, res=64, layer=0.045, cover="herbe", bare=None):
    """Morceau de sol : dessus selon top(x, y) (hauteur), côtés et dessous. Couverture (herbe, sable…) sur le dessus et
    une couche de `layer` sur les côtés ; terre en dessous et là où l'on a creusé (bare(x, y, z) vrai, ou sous la couche)."""
    top = top or (lambda x, y: 0.0)
    bare = bare or (lambda x, y, z: z < -layer * 0.6)
    sx, sy = size
    bm = bmesh.new()
    soil = bm.verts.layers.float.new("terre")
    grid = []
    for j in range(res + 1):
        row = []
        for i in range(res + 1):
            x = -sx / 2 + sx * i / res
            y = -sy / 2 + sy * j / res
            z = top(x, y)
            v = bm.verts.new((x, y, z))
            v[soil] = 1.0 if bare(x, y, z) else 0.0
            row.append(v)
        grid.append(row)
    for j in range(res):
        for i in range(res):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    ring = [grid[0][i] for i in range(res + 1)] + [grid[j][res] for j in range(1, res + 1)] + \
           [grid[res][i] for i in range(res - 1, -1, -1)] + [grid[j][0] for j in range(res - 1, 0, -1)]
    # Côtés : la couverture (layer) puis la terre, jusqu'au fond.
    mid, bottom = [], []
    for v in ring:
        m = bm.verts.new((v.co.x, v.co.y, v.co.z - layer))
        m[soil] = 0.5
        mid.append(m)
        b = bm.verts.new((v.co.x, v.co.y, -depth))
        b[soil] = 1.0
        bottom.append(b)
    count = len(ring)
    for k in range(count):
        n = (k + 1) % count
        bm.faces.new((ring[n], ring[k], mid[k], mid[n]))
        bm.faces.new((mid[n], mid[k], bottom[k], bottom[n]))
    bm.faces.new(list(reversed(bottom)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_object(name, bm)
    # Côtés plats, dessus lisse.
    for poly in obj.data.polygons:
        poly.use_smooth = poly.normal.z > 0.3
    obj.data.materials.append(_ground_material(name, cover))
    return obj


def _ground_material(name, cover):
    mat = bpy.data.materials.new(name + "_matiere")
    tree, bsdf = _bsdf_tree(mat)
    coords = tree.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    look = GROUND_LOOKS[cover]
    top_color, top_fac = _two_tone(tree, coords, look[0], look[1], look[2])
    dirt = GROUND_LOOKS["terre"]
    soil_color, soil_fac = _two_tone(tree, coords, dirt[0], dirt[1], dirt[2])
    attr = tree.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "terre"
    # Limite nette entre couverture et terre (0,5 sur les côtés : la couche du dessus descend jusque-là).
    edge = tree.nodes.new("ShaderNodeMapRange")
    edge.inputs["From Min"].default_value = 0.45
    edge.inputs["From Max"].default_value = 0.55
    tree.links.new(attr.outputs["Fac"], edge.inputs["Value"])
    tree.links.new(_mix_color(tree, edge.outputs["Result"], top_color, soil_color), bsdf.inputs["Base Color"])
    height = tree.nodes.new("ShaderNodeMix")
    height.data_type = "FLOAT"
    tree.links.new(edge.outputs["Result"], height.inputs["Factor"])
    tree.links.new(top_fac, height.inputs[2])
    tree.links.new(soil_fac, height.inputs[3])
    _bump(tree, bsdf, height.outputs[0], 0.4)
    _set(bsdf, roughness=0.92, specular=0.35)
    return mat


# --- Main du joueur : celle du jeu (../main/generer_main.py), posée ---
# Repère : doigts vers +Y, paume vers +Z, pouce vers +X (main droite), poignet à l'origine. Mètres.
FINGERS = [
    (Vector((0.031, 0.083, 0.0)), (0.040, 0.025, 0.020), 0.0088),    # index
    (Vector((0.011, 0.089, 0.002)), (0.045, 0.028, 0.022), 0.0092),  # majeur
    (Vector((-0.010, 0.085, 0.0)), (0.042, 0.026, 0.021), 0.0087),   # annulaire
    (Vector((-0.029, 0.074, -0.003)), (0.032, 0.021, 0.018), 0.0078),  # auriculaire
]
# Poses : repli de chaque articulation (degrés) de l'index à l'auriculaire, et le pouce (4 points).
POSES = {
    # Celle du jeu : paume vers le haut, doigts un peu repliés (l'objet repose dans la paume).
    "jeu": {"doigts": [(14, 26, 22), (12, 24, 20), (14, 26, 22), (18, 28, 24)],
            "pouce": [(0.022, 0.012, -0.004), (0.046, 0.032, 0.006), (0.062, 0.055, 0.018), (0.069, 0.075, 0.03)]},
    # Main ouverte, détendue (image de la main de l'inventaire).
    "ouverte": {"doigts": [(4, 8, 6), (3, 7, 5), (5, 8, 6), (8, 10, 8)], "ecart": 0.25,
                "pouce": [(0.022, 0.012, -0.004), (0.05, 0.03, 0.0), (0.071, 0.048, 0.004), (0.084, 0.064, 0.008)]},
    # Creux de la main (une poignée de matière).
    "creux": {"doigts": [(18, 30, 24), (16, 28, 22), (18, 30, 24), (22, 32, 26)],
              "pouce": [(0.022, 0.012, -0.004), (0.044, 0.034, 0.012), (0.056, 0.058, 0.03), (0.06, 0.077, 0.045)]},
    # Griffe (creuser).
    "griffe": {"doigts": [(30, 48, 36), (28, 46, 34), (30, 48, 36), (34, 50, 38)], "ecart": 0.15,
               "pouce": [(0.022, 0.012, -0.004), (0.046, 0.034, 0.014), (0.058, 0.056, 0.034), (0.058, 0.072, 0.052)]},
    # Prise (tenir un caillou, une touffe) : doigts bien repliés autour.
    "prise": {"doigts": [(42, 62, 44), (40, 60, 42), (44, 62, 44), (48, 64, 46)],
              "pouce": [(0.022, 0.012, -0.004), (0.044, 0.036, 0.018), (0.046, 0.06, 0.04), (0.036, 0.074, 0.054)]},
}


def hand(name, skin, pose="jeu", arm=0.05, thick=1.12):
    """Main droite du jeu (même construction : squelette + Skin + Subdivision, paume aplatie et creusée), posée."""
    spec = POSES[pose]
    bm = bmesh.new()
    radii = []

    def vert(at, r):
        radii.append(r)
        return bm.verts.new(Vector(at))

    forearm = vert((0.0, -arm, -0.012), (0.032, 0.026))
    wrist = vert((0.0, -0.005, -0.004), (0.028, 0.018))
    bm.edges.new((forearm, wrist))
    for (base, lengths, radius), bends in zip(FINGERS, spec["doigts"]):
        radius *= thick
        root = vert(base + Vector((0, -0.004, -0.002)), (radius * 1.15, radius * 1.05))
        bm.edges.new((wrist, root))
        at = base.copy()
        direction = Vector((base.x * (0.35 + spec.get("ecart", 0.0) * 10.0), 1.0, 0.0)).normalized()
        previous = root
        total = 0.0
        for index in range(3):
            total += math.radians(bends[index])
            axis = direction.cross(Vector((0, 0, 1))).normalized()
            step = (Matrix.Rotation(total, 3, axis) @ direction) * lengths[index]
            at = at + step
            r = radius * 1.12 * (0.95 - 0.1 * index)
            current = vert(at, (r, r * 0.9))
            bm.edges.new((previous, current))
            previous = current
    thumb = [Vector(p) for p in spec["pouce"]]
    previous = vert(thumb[0], (0.013, 0.011))
    bm.edges.new((wrist, previous))
    for index, point in enumerate(thumb[1:]):
        r = 0.0115 - 0.0012 * index
        current = vert(point, (r, r * 0.9))
        bm.edges.new((previous, current))
        previous = current
    mesh = bpy.data.meshes.new(name + "_squelette")
    bm.to_mesh(mesh)
    bm.free()
    bones = bpy.data.objects.new(name + "_squelette", mesh)
    bpy.context.scene.collection.objects.link(bones)
    skin_mod = bones.modifiers.new("Skin", "SKIN")
    skin_mod.use_smooth_shade = True
    for index, data in enumerate(mesh.skin_vertices[0].data):
        data.radius = radii[index]
    mesh.skin_vertices[0].data[0].use_root = True
    bones.modifiers.new("Lisse", "SUBSURF").levels = 1
    # Paume : sphère aplatie, un peu creusée (le centre plus bas que les bords).
    palm = bmesh.new()
    bmesh.ops.create_uvsphere(palm, u_segments=20, v_segments=12, radius=1.0)
    for v in palm.verts:
        v.co = Vector((v.co.x * 0.043, v.co.y * 0.052, v.co.z * 0.017))
        if v.co.z > 0:
            v.co.z -= 0.006 * max(0.0, 1.0 - (v.co.x / 0.043) ** 2 - (v.co.y / 0.052) ** 2)
        v.co += Vector((0.001, 0.042, -0.002))
    # Image (pas dans le jeu) : le gras du pouce, qui relie la paume au pouce (lissé ensuite avec le reste).
    thenar = bmesh.ops.create_uvsphere(palm, u_segments=16, v_segments=10, radius=1.0)
    for v in thenar["verts"]:
        v.co = Matrix.Rotation(math.radians(-35.0), 3, "Z") @ Vector((v.co.x * 0.017, v.co.y * 0.03, v.co.z * 0.014))
        v.co += Vector((0.024, 0.024, -0.001))
    palm_mesh = bpy.data.meshes.new(name + "_paume")
    palm.to_mesh(palm_mesh)
    palm.free()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    baked = bpy.data.meshes.new_from_object(bones.evaluated_get(depsgraph))
    joined = bmesh.new()
    joined.from_mesh(baked)
    joined.from_mesh(palm_mesh)
    bpy.data.objects.remove(bones, do_unlink=True)
    for old in [mesh, baked, palm_mesh]:
        bpy.data.meshes.remove(old)
    obj = mesh_object(name, joined)
    # Une seule surface lisse (doigts, paume et pouce bien raccordés) : remaillage en petits cubes, puis lissage.
    remesh = obj.modifiers.new("Remaillage", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.0012
    remesh.adaptivity = 0.0
    smooth = obj.modifiers.new("Lissage", "SMOOTH")
    smooth.factor = 0.9
    smooth.iterations = 8
    depsgraph = bpy.context.evaluated_depsgraph_get()
    smoothed = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    obj.modifiers.clear()
    rough = obj.data
    obj.data = smoothed
    bpy.data.meshes.remove(rough)
    assign(obj, mat_skin(skin))
    if hasattr(obj.data, "shade_smooth"):
        obj.data.shade_smooth()
    # Cadrage : sans l'avant-bras (il sort de l'image).
    obj["cadre_axe"] = 1
    obj["cadre_min"] = -0.03
    return obj


def orient(obj, fingers, palm, location):
    """Oriente la main : doigts et paume dans ces directions (monde), poignet à location."""
    y = Vector(fingers).normalized()
    z = Vector(palm)
    z = (z - y * z.dot(y)).normalized()
    x = y.cross(z)
    obj.matrix_world = Matrix.Translation(Vector(location)) @ Matrix((x, y, z)).transposed().to_4x4()
    return obj


def in_hand(obj, local):
    """Un point du repère de la main (doigts +Y, paume +Z) dans le monde."""
    return obj.matrix_world @ Vector(local)


# --- Cadrage, rendu, finition ---

def frame(scene):
    camera = scene.camera
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in scene.objects:
        if obj.type != "MESH" or not obj.get("sujet") or not obj.get("cadre", True):
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        low = obj.get("cadre_min")
        axis = int(obj.get("cadre_axe", 1))
        matrix = obj.matrix_world
        for v in mesh.vertices:
            if low is not None and v.co[axis] < low:
                continue
            points.append(matrix @ v.co)
        evaluated.to_mesh_clear()
    if not points:
        return
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    target = (low + high) * 0.5
    radius = max((high - low).length * 0.5, 0.01)
    azimuth, elevation = math.radians(AZIMUTH), math.radians(ELEVATION)
    direction = Vector((math.sin(azimuth) * math.cos(elevation), -math.cos(azimuth) * math.cos(elevation), math.sin(elevation)))
    half = math.atan(18.0 / LENS)
    distance = radius / math.sin(half)
    step = max(1, len(points) // 6000)
    sample = points[::step]
    for attempt in range(5):
        camera.location = target + direction * distance
        camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
        bpy.context.view_layer.update()
        seen = [world_to_camera_view(scene, camera, p) for p in sample]
        xs = [s.x for s in seen]
        ys = [s.y for s in seen]
        extent = max(max(xs) - min(xs), max(ys) - min(ys))
        middle = ((min(xs) + max(xs)) * 0.5 - 0.5, (min(ys) + max(ys)) * 0.5 - 0.5)
        width = 2.0 * distance * math.tan(half)
        rotation = camera.matrix_world.to_3x3()
        target = target + rotation @ Vector((middle[0] * width, middle[1] * width, 0.0))
        distance *= extent / FILL
    camera.location = target + direction * distance
    camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()


def write_png(path, rgba):
    """PNG 8 bits RGBA (h, w, 4) uint8, sans dépendance."""
    height, width, _ = rgba.shape
    raw = b"".join(b"\x00" + rgba[y].tobytes() for y in range(height))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)

    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + \
        chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as file:
        file.write(data)


def _shift(array, dy, dx):
    out = np.zeros_like(array)
    h, w = array.shape
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = array[ys, xs]
    return out


def _box_blur(array, size):
    pad = size // 2
    padded = np.pad(array, pad, mode="constant")
    total = np.cumsum(np.cumsum(padded, axis=0), axis=1)
    total = np.pad(total, ((1, 0), (1, 0)), mode="constant")
    h, w = array.shape
    return (total[size:size + h, size:size + w] - total[0:h, size:size + w] - total[size:size + h, 0:w] + total[0:h, 0:w]) / (size * size)


def finish(rendered, out_path):
    """Contour sombre et ombre douce, puis réduction (moyenne 4 × 4, couleurs prémultipliées) à SIZE × SIZE."""
    image = bpy.data.images.load(rendered, check_existing=False)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    pixels = pixels.reshape(height, width, 4)[::-1]
    alpha = pixels[..., 3]
    color = pixels[..., :3] * alpha[..., None]
    outline = np.zeros_like(alpha)
    for dy in range(-OUTLINE_RADIUS, OUTLINE_RADIUS + 1):
        for dx in range(-OUTLINE_RADIUS, OUTLINE_RADIUS + 1):
            distance = math.hypot(dx, dy)
            if distance <= OUTLINE_RADIUS + 0.5:
                weight = min(1.0, OUTLINE_RADIUS + 0.5 - distance)
                outline = np.maximum(outline, _shift(alpha, dy, dx) * weight)
    shadow = _box_blur(_shift(alpha, SHADOW_OFFSET[1], SHADOW_OFFSET[0]), SHADOW_BLUR) * SHADOW_ALPHA
    under_alpha = shadow
    under_color = np.zeros_like(color)
    line_alpha = outline * 0.92
    under_color = np.array(OUTLINE_COLOR, dtype=np.float32)[None, None, :] * line_alpha[..., None] + under_color * (1.0 - line_alpha[..., None])
    under_alpha = line_alpha + under_alpha * (1.0 - line_alpha)
    final_color = color + under_color * (1.0 - alpha[..., None])
    final_alpha = alpha + under_alpha * (1.0 - alpha)
    factor = height // SIZE
    final_color = final_color.reshape(SIZE, factor, SIZE, factor, 3).mean(axis=(1, 3))
    final_alpha = final_alpha.reshape(SIZE, factor, SIZE, factor).mean(axis=(1, 3))
    straight = np.where(final_alpha[..., None] > 1e-4, final_color / np.maximum(final_alpha[..., None], 1e-4), 0.0)
    rgba = np.concatenate([straight, final_alpha[..., None]], axis=2)
    write_png(out_path, (np.clip(rgba, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8))


def shoot(scene, name):
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(TEMP, exist_ok=True)
    frame(scene)
    rendered = os.path.join(TEMP, name + "_rendu.png")
    scene.render.filepath = rendered
    bpy.ops.render.render(write_still=True)
    finish(rendered, os.path.join(OUT, name + ".png"))
    print("image :", name)


# --- Petites formes des images ---

def tube(name, points, radius, radius_end=None, sides=10, caps=True):
    """Tube lisse le long de points ; le rayon va de radius à radius_end."""
    points = [Vector(p) for p in points]
    radius_end = radius if radius_end is None else radius_end
    bm = bmesh.new()
    rings = []
    normal = None
    count = len(points)
    for index, point in enumerate(points):
        tangent = (points[min(index + 1, count - 1)] - points[max(index - 1, 0)]).normalized()
        if normal is None:
            helper = Vector((0.0, 0.0, 1.0)) if abs(tangent.z) < 0.9 else Vector((1.0, 0.0, 0.0))
            normal = tangent.cross(helper).normalized()
        else:
            normal = (normal - tangent * normal.dot(tangent)).normalized()
        binormal = tangent.cross(normal)
        r = radius + (radius_end - radius) * index / max(count - 1, 1)
        rings.append([bm.verts.new(point + (normal * math.cos(a) + binormal * math.sin(a)) * r)
                      for a in [math.tau * k / sides for k in range(sides)]])
    for index in range(count - 1):
        for k in range(sides):
            bm.faces.new((rings[index][k], rings[index][(k + 1) % sides], rings[index + 1][(k + 1) % sides], rings[index + 1][k]))
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm)


def curve_points(start, end, bend, count=16, wiggle=0.0, seed=0):
    """Points d'une courbe douce de start à end, creusée de bend (vecteur) au milieu."""
    rng = random.Random(seed)
    start, end, bend = Vector(start), Vector(end), Vector(bend)
    points = []
    for index in range(count):
        t = index / (count - 1)
        point = start.lerp(end, t) + bend * (4.0 * t * (1.0 - t))
        if wiggle and 0 < index < count - 1:
            point += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * wiggle
        points.append(point)
    return points


def flake(name, length, seed, thick=0.34):
    """Éclat taillé : dessous lisse, arête au milieu du dessus, bord tranchant, facettes nettes."""
    rng = random.Random(seed)
    corners = 7
    outline = []
    for index in range(corners):
        angle = math.tau * (index + rng.uniform(-0.15, 0.15)) / corners
        reach = rng.uniform(0.8, 1.0)
        x = math.cos(angle) * reach * (1.4 if math.cos(angle) > 0 else 1.0)
        outline.append(Vector((x, math.sin(angle) * reach * 0.85, 0.05)))
    ridge = [Vector((-0.38, rng.uniform(-0.1, 0.1), thick)), Vector((0.5, rng.uniform(-0.1, 0.1), thick * 0.85))]
    bm = bmesh.new()
    scale = length / 2.8
    rim = [bm.verts.new(p * scale) for p in outline]
    tops = [bm.verts.new(p * scale) for p in ridge]
    under = bm.verts.new(Vector((0.05, 0.0, -0.06)) * scale)
    for index in range(corners):
        a, b, c = outline[index], outline[(index + 1) % corners], outline[(index + 2) % corners]
        near = 0 if (a.x + b.x) * 0.5 < 0.05 else 1
        after = 0 if (b.x + c.x) * 0.5 < 0.05 else 1
        bm.faces.new((rim[index], rim[(index + 1) % corners], tops[near]))
        if after != near:
            bm.faces.new((rim[(index + 1) % corners], tops[after], tops[near]))
        bm.faces.new((rim[(index + 1) % corners], rim[index], under))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, smooth=False)


def pebble(name, form, diameter, mat):
    """Un caillou du jeu (modèle sorti du jeu, diamètre 1) à sa taille."""
    obj = import_model("caillou_%d" % form)
    obj.name = name
    obj.data.transform(Matrix.Scale(diameter, 4))
    return assign(obj, mat)


def tuft(name, blades=16, height=0.09, seed=3, spread=0.012):
    """Touffe d'herbe : brins fins, effilés et courbés, partant d'une base."""
    rng = random.Random(seed)
    bm = bmesh.new()
    for blade in range(blades):
        angle = rng.uniform(0.0, math.tau)
        out = Vector((math.cos(angle), math.sin(angle), 0.0))
        base = out * rng.uniform(0.0, spread)
        side = Vector((-out.y, out.x, 0.0))
        tall = height * rng.uniform(0.65, 1.15)
        lean = rng.uniform(0.15, 0.55)
        width = rng.uniform(0.0032, 0.0048)
        previous = None
        for step in range(7):
            t = step / 6
            center = base + Vector((0.0, 0.0, tall * t)) + out * tall * lean * t * t
            w = width * (1.0 - t * 0.92)
            left = bm.verts.new(center - side * w)
            right = bm.verts.new(center + side * w)
            if previous:
                bm.faces.new((previous[0], previous[1], right, left))
            previous = (left, right)
    obj = mesh_object(name, bm)
    return assign(obj, noisy("Brins", (0.1, 0.23, 0.035), (0.3, 0.48, 0.09), scale=30.0, roughness=0.6, bump=0.0, specular=0.5))


def roots(name, count=9, length=0.04, seed=5):
    """Racines : fins tubes clairs qui pendent sous une touffe."""
    rng = random.Random(seed)
    made = []
    for index in range(count):
        angle = rng.uniform(0.0, math.tau)
        out = Vector((math.cos(angle), math.sin(angle), 0.0))
        start = out * rng.uniform(0.0, 0.008)
        end = start + out * rng.uniform(0.005, 0.02) + Vector((0.0, 0.0, -length * rng.uniform(0.6, 1.1)))
        made.append(tube("%s_%d" % (name, index), curve_points(start, end, out * 0.006, 10, 0.0015, seed + index), 0.0011, 0.0004, sides=6))
    look = principled("Racines", (0.42, 0.3, 0.17), roughness=0.8)
    for obj in made:
        assign(obj, look)
    return made


def rounded_box(name, size, bevel, mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=bevel, segments=4, affect="EDGES", profile=0.5)
    obj = mesh_object(name, bm)
    return assign(obj, mat)


def split_stick(name, length, radius, split, gap, matrix):
    """Branche dont le bout est fendu en deux (bois clair dedans) : le long de +Z, fente de `split` au bout, les
    deux moitiés écartées de `gap` degrés. Rend [corps, moitié 1, moitié 2]."""
    body = tube(name + "_corps", [(0, 0, 0), (0, 0, length - split)], radius, radius * 0.96, sides=16)
    uv_cylinder(body)
    assign(body, mat_bark())
    parts = [body]
    for side in [1, -1]:
        bm = bmesh.new()
        segments = 10
        rows = []
        for z in [0.0, split]:
            r = radius * (0.96 if z == 0.0 else 0.9)
            row = [bm.verts.new((math.cos(a) * r, side * math.sin(a) * r, z)) for a in [math.pi * k / segments for k in range(segments + 1)]]
            rows.append(row)
        for k in range(segments):
            bm.faces.new((rows[0][k], rows[0][k + 1], rows[1][k + 1], rows[1][k]))
        flat = bm.faces.new((rows[0][0], rows[1][0], rows[1][segments], rows[0][segments]))
        bm.faces.new(list(rows[1]))
        bm.faces.new(list(reversed(rows[0])))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        half = mesh_object("%s_moitie_%d" % (name, side), bm)
        half.data.materials.append(mat_bark())
        half.data.materials.append(mat_wood())
        for poly in half.data.polygons:
            # Face plate (dedans) et bout : le bois clair.
            if abs(poly.normal.y) > 0.9 or abs(poly.normal.z) > 0.9:
                poly.material_index = 1
                poly.use_smooth = False
        uv_cylinder(half)
        hinge = Matrix.Translation((0.0, 0.0, length - split)) @ Matrix.Rotation(math.radians(gap * 0.5) * -side, 4, "X")
        half.matrix_world = matrix @ hinge
        parts.append(half)
    body.matrix_world = matrix
    return parts


def stone_head(name, stone, matrix):
    """Tête de hache taillée du jeu (modèle sorti du jeu) à sa taille, tranchant vers +X."""
    obj = import_model("tete_hache_%d" % stone)
    obj.name = name
    obj.data.transform(Matrix.Scale(COLORS["tailles_tetes"]["hache"], 4))
    obj.matrix_world = matrix
    return obj


def view_axes():
    """Droite, haut et avant de la caméra (même angle pour toutes les images)."""
    azimuth, elevation = math.radians(AZIMUTH), math.radians(ELEVATION)
    back = Vector((math.sin(azimuth) * math.cos(elevation), -math.cos(azimuth) * math.cos(elevation), math.sin(elevation)))
    right = Vector((math.cos(azimuth), math.sin(azimuth), 0.0))
    up = right.cross(-back).normalized()
    if up.z < 0.0:
        up = -up
    return right, up, -back


def stick_frame(screen_angle, opening, location=(0.0, 0.0, 0.0)):
    """Repère d'un bâton (fente le long de Y) : axe à screen_angle degrés dans l'image (0 : vers la droite) ; la fente
    s'ouvre à `opening` degrés de la direction de la caméra (90 : dans le plan de l'image, on voit le V)."""
    right, up, forward = view_axes()
    a = math.radians(screen_angle)
    axis = (right * math.cos(a) + up * math.sin(a)).normalized()
    in_plane = axis.cross(forward).normalized()
    toward = (forward - axis * forward.dot(axis)).normalized()
    o = math.radians(opening)
    side = (toward * math.cos(o) + in_plane * math.sin(o)).normalized()
    x = side.cross(axis)
    return Matrix.Translation(Vector(location)) @ Matrix((x, side, axis)).transposed().to_4x4()


# --- Les images ---

def img_main(skin):
    """Inventaire : la main (le pouce bien à sa place) : main du jeu, ouverte, paume vers nous, doigts vers le haut ;
    le poignet sort par le bas de l'image."""
    obj = hand("Main", skin, "ouverte", arm=0.4)
    toward = Vector((math.sin(math.radians(AZIMUTH)), -math.cos(math.radians(AZIMUTH)), 0.35)).normalized()
    orient(obj, (0.1, 0.06, 1.0), toward, (0.0, 0.0, 0.0))
    obj["cadre_min"] = -0.012


def img_recuperer_materiaux(skin):
    """Clic gauche « Récupérer des matériaux » : le creux de la main tient une poignée de terre, prise dans le sol creusé
    juste dessous (quelques miettes retombent)."""
    def top(x, y):
        d = math.hypot(x - 0.035, y + 0.01)
        return -0.04 * max(0.0, 1.0 - (d / 0.05) ** 2) if d < 0.05 else 0.0
    ground("Sol", size=(0.2, 0.16), depth=0.05, top=top, layer=0.01)
    obj = hand("Main", skin, "creux", arm=0.4)
    orient(obj, (0.95, 0.45, 0.25), (-0.15, -0.45, 1.0), (-0.1, -0.02, 0.07))
    pile = heap("Poignee", 0.04, 0.03, 7)
    pile.matrix_world = obj.matrix_world @ Matrix.Translation((0.002, 0.046, 0.004))
    assign(pile, mat_ground("terre"))
    for index, (offset, size) in enumerate([((0.035, 0.0, -0.035), 0.005), ((0.042, -0.01, -0.06), 0.004), ((0.03, 0.012, -0.08), 0.0035)]):
        crumb = blob("Miette_%d" % index, size, 40 + index)
        crumb.location = in_hand(obj, (0.0, 0.046, 0.0)) + Vector(offset)
        assign(crumb, mat_ground("terre"))


def img_creuser(skin):
    """Clic gauche « Creuser / Casser » : la main en griffe creuse le sol, la terre saute du trou."""
    def top(x, y):
        d = math.hypot(x - 0.02, y + 0.005)
        return -0.045 * max(0.0, 1.0 - (d / 0.055) ** 2) if d < 0.055 else 0.0
    ground("Sol", size=(0.21, 0.17), depth=0.055, top=top, layer=0.01)
    obj = hand("Main", skin, "griffe", arm=0.4)
    orient(obj, (0.55, 0.25, -0.8), (0.35, -0.9, -0.2), (-0.075, 0.02, 0.11))
    rng = random.Random(11)
    for index in range(9):
        t = index / 8
        point = Vector((0.03 + 0.07 * t, -0.01 - 0.02 * t, 0.02 + 0.09 * math.sin(math.pi * (0.25 + 0.6 * t))))
        point += Vector((rng.uniform(-0.01, 0.01), rng.uniform(-0.01, 0.01), rng.uniform(-0.008, 0.008)))
        crumb = blob("Miette_%d" % index, rng.uniform(0.0045, 0.009), 60 + index)
        crumb.location = point
        assign(crumb, mat_ground("terre"))


def img_casser_objets(skin):
    """Clic gauche « Casser / Récupérer des objets » : la main ramasse un caillou posé sur l'herbe, à côté d'un bâton."""
    ground("Sol", size=(0.22, 0.17), depth=0.03, layer=0.01)
    stick("Baton", (-0.08, 0.05, 0.007), (0.09, -0.04, 0.007), 0.0075, 0.006)
    obj = hand("Main", skin, "prise", arm=0.4)
    orient(obj, (0.35, 0.15, -0.92), (0.15, -0.95, 0.1), (-0.04, 0.02, 0.15))
    stone = pebble("Caillou", 3, 0.058, mat_stone())
    stone.location = in_hand(obj, (0.004, 0.088, 0.03))


def img_arracher(skin):
    """Clic gauche « Casser / Arracher » : la main tire une touffe d'herbe hors du sol, racines et motte dessous."""
    def top(x, y):
        d = math.hypot(x - 0.01, y + 0.005)
        return -0.02 * max(0.0, 1.0 - (d / 0.035) ** 2) if d < 0.035 else 0.0
    ground("Sol", size=(0.2, 0.16), depth=0.04, top=top, layer=0.01)
    base = Vector((0.01, -0.005, 0.07))
    grass = tuft("Touffe", 18, 0.085, 3, 0.011)
    grass.location = base
    clod = blob("Motte", 0.014, 21, squash=(1.2, 1.1, 0.7))
    clod.location = base + Vector((0.0, 0.0, -0.004))
    assign(clod, mat_ground("terre"))
    for root in roots("Racine", 10, 0.042, 9):
        root.location = base + Vector((0.0, 0.0, -0.008))
    obj = hand("Main", skin, "prise", arm=0.4)
    orient(obj, (-0.75, 0.15, -0.35), (-0.2, -0.95, 0.25), (0.11, -0.0, 0.11))


def img_poser(skin=None):
    """Clic droit « Poser » : un bloc de sable posé sur l'herbe (la matière en main), une flèche vers le bas."""
    ground("Sol", size=(0.22, 0.17), depth=0.035, layer=0.01)
    rounded_box("Bloc", (0.075, 0.075, 0.05), 0.008, mat_ground("sable")).location = (0.0, 0.0, 0.025)
    arrow("Fleche", (0.0, 0.0, 0.135), (0.0, 0.0, 0.062), 0.014)


def img_aplanir(skin=None):
    """Clic droit « Aplanir » : sol bosselé à gauche, coupé bien à plat à droite (terre à nu), ligne blanche à la
    hauteur visée, qui traverse les bosses."""
    level = -0.004

    def bumps(x, y):
        return 0.04 * (0.55 + 0.45 * math.sin(x * 60.0 + 1.0) * math.cos(y * 52.0)) * math.exp(-((x + 0.035) ** 2) / 0.0035)

    def top(x, y):
        k = min(1.0, max(0.0, (x - 0.0) / 0.012))
        return bumps(x, y) * (1.0 - k) + level * k

    ground("Sol", size=(0.2, 0.15), depth=0.04, top=top, res=90, layer=0.01, bare=lambda x, y, z: x > 0.004)
    bar = tube("Niveau", [(-0.115, -0.077, level + 0.0015), (0.11, -0.077, level + 0.0015)], 0.0032, sides=10)
    assign(bar, mat_white())

def img_lisser(skin=None):
    """Clic droit « Lisser » : une bosse en marches (terre à nu au bord des marches) à gauche, pente lisse à droite."""
    step = 0.016

    def hill(x, y):
        return 0.075 * math.exp(-((x + 0.01) ** 2) / 0.006 - (y * y) / 0.0045)

    def blend(x):
        return min(1.0, max(0.0, (x + 0.004) / 0.016))

    def top(x, y):
        h = hill(x, y)
        return round(h / step) * step * (1.0 - blend(x)) + h * blend(x)

    def bare(x, y, z):
        h = hill(x, y)
        fraction = h / step - math.floor(h / step)
        return blend(x) < 0.5 and h > step * 0.5 and abs(fraction - 0.5) < 0.12

    ground("Sol", size=(0.22, 0.16), depth=0.035, top=top, res=150, layer=0.01, bare=bare)

def img_manger(skin=None):
    """Clic droit « Manger » : la pomme du jeu, croquée (chair claire), avec sa queue et une feuille."""
    apple = import_model("pomme")
    bm = bmesh.new()
    bm.from_mesh(apple.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.to_mesh(apple.data)
    bm.free()
    apple.data.transform(Matrix.Scale(0.05, 4))
    rounder = apple.modifiers.new("Ronde", "SUBSURF")
    rounder.levels = 2
    depsgraph = bpy.context.evaluated_depsgraph_get()
    rounded = bpy.data.meshes.new_from_object(apple.evaluated_get(depsgraph))
    apple.modifiers.clear()
    apple.data = rounded
    assign(apple, noisy("Pomme", lin((0.62, 0.11, 0.08)), lin(COLORS["pommes"][1]), scale=26.0, roughness=0.32, bump=0.02,
                        specular=0.6, coat=0.35))
    apple.data.materials.append(principled("Chair", (0.86, 0.76, 0.5), roughness=0.6, specular=0.3))
    cutter_data = bmesh.new()
    bmesh.ops.create_uvsphere(cutter_data, u_segments=32, v_segments=16, radius=0.028)
    cutter = mesh_object("Croquee", cutter_data)
    cutter.location = (0.04, -0.03, 0.006)
    cutter.data.materials.append(apple.data.materials[1])
    second = bmesh.new()
    bmesh.ops.create_uvsphere(second, u_segments=32, v_segments=16, radius=0.026)
    for v in second.verts:
        v.co += Vector((0.046, -0.002, 0.018))
    cutter2 = mesh_object("Croquee2", second)
    cutter2.data.materials.append(apple.data.materials[1])
    for cut in [cutter, cutter2]:
        boolean = apple.modifiers.new("Croquee", "BOOLEAN")
        boolean.operation = "DIFFERENCE"
        boolean.object = cut
        if hasattr(boolean, "material_mode"):
            boolean.material_mode = "TRANSFER"
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bitten = bpy.data.meshes.new_from_object(apple.evaluated_get(depsgraph))
    apple.modifiers.clear()
    old = apple.data
    apple.data = bitten
    bpy.data.meshes.remove(old)
    for cut in [cutter, cutter2]:
        bpy.data.objects.remove(cut, do_unlink=True)
    for poly in apple.data.polygons:
        poly.use_smooth = True
    stem = tube("Queue", curve_points((0.0, 0.0, 0.026), (0.006, 0.003, 0.05), (0.004, 0.0, 0.0), 8), 0.0022, 0.0016, sides=8)
    assign(stem, principled("Queue", (0.16, 0.09, 0.04), roughness=0.8))
    leaf = blob("Feuille", 1.0, 2, squash=(0.024, 0.011, 0.0018), rough=0.0, subdiv=3)
    leaf.location = (-0.012, 0.004, 0.047)
    leaf.rotation_euler = Euler((math.radians(10.0), math.radians(-28.0), math.radians(150.0)))
    assign(leaf, principled("Feuille", (0.13, 0.32, 0.05), roughness=0.5, specular=0.5))


def img_tresser(skin=None):
    """Fabrication « Tresser » : trois fibres de lin séparées en éventail à gauche, tressées en ficelle à droite."""
    fiber = lin(COLORS["objets"]["fibre_lin"])
    tones = [tuple(min(1.0, c * k) for c in fiber) for k in (0.82, 1.0, 1.18)]
    length = 0.13
    for strand in range(3):
        phase = math.tau * strand / 3 + 0.5
        points = []
        for index in range(70):
            t = index / 69
            x = -length / 2 + length * t
            twist = min(1.0, max(0.0, (t - 0.32) / 0.22))
            spread = (1.0 - twist) * 0.03 * max(0.0, 1.0 - t / 0.54) ** 1.2
            angle = phase + t * math.tau * 3.6 * twist
            radius = 0.0048 * twist
            y = math.cos(angle) * radius + math.cos(phase) * spread
            z = math.sin(angle) * radius + math.sin(phase) * spread
            points.append((x, y, z))
        obj = tube("Brin_%d" % strand, points, 0.0042, 0.004, sides=10)
        assign(obj, noisy("Fibre_%d" % strand, tuple(c * 0.75 for c in tones[strand]), tones[strand], scale=180.0,
                          roughness=0.85, bump=0.2))
    knot = blob("Noeud", 0.0085, 31, rough=0.15)
    knot.location = (length / 2 + 0.003, 0.0, 0.0)
    assign(knot, bpy.data.materials["Fibre_1"])
    # En diagonale dans l'image (de bas à gauche vers haut à droite) : X du dessin le long de l'axe du bâton.
    turn = stick_frame(28.0, 0.0) @ Matrix.Rotation(math.radians(90.0), 4, "Y")
    for obj in bpy.context.scene.objects:
        if obj.get("sujet"):
            obj.matrix_world = turn @ obj.matrix_world

def img_tailler(skin):
    """Fabrication « Tailler » : la main frappe un silex avec un caillou, des éclats et des étincelles sautent."""
    nodule = pebble("Silex", 4, 0.085, mat_flint())
    nodule.location = (0.03, 0.0, 0.0)
    nodule.rotation_euler = Euler((0.2, 0.3, 0.5))
    obj = hand("Main", skin, "prise", arm=0.4)
    orient(obj, (0.4, 0.3, -0.85), (0.2, -0.95, 0.05), (-0.085, 0.01, 0.13))
    stone = pebble("Percuteur", 2, 0.055, mat_stone())
    stone.location = in_hand(obj, (0.004, 0.085, 0.026))
    impact = Vector((0.008, -0.012, 0.042))
    rng = random.Random(5)
    for index, (direction, size) in enumerate([((0.9, -0.3, 0.6), 0.03), ((0.3, -0.7, 0.9), 0.024), ((1.0, 0.2, 0.25), 0.02), ((-0.1, -0.9, 0.35), 0.017)]):
        piece = flake("Eclat_%d" % index, size, 70 + index)
        piece.location = impact + Vector(direction).normalized() * (0.035 + 0.012 * index)
        piece.rotation_euler = Euler((rng.uniform(0, 6.3), rng.uniform(0, 6.3), rng.uniform(0, 6.3)))
        assign(piece, mat_flint_inside())
    for index, direction in enumerate([(0.7, -0.5, 0.5), (0.1, -0.9, 0.4), (0.95, 0.1, 0.35), (0.5, -0.8, 0.0), (0.4, -0.2, 0.9)]):
        d = Vector(direction).normalized()
        spark = tube("Etincelle_%d" % index, [impact + d * 0.01, impact + d * 0.032], 0.0018, 0.0005, sides=6)
        assign(spark, mat_white())

def img_fendre(skin=None):
    """Fabrication « Fendre » : le bout d'une branche fendu en V (bois clair dedans), un éclat de silex enfoncé dans la
    fente."""
    matrix = stick_frame(32.0, 58.0, (-0.08, 0.0, 0.0))
    split_stick("Branche", 0.19, 0.0135, 0.075, 30.0, matrix)
    right, up, forward = view_axes()
    axis = matrix.to_3x3() @ Vector((0.0, 0.0, 1.0))
    # Pointe dans le fond de la fente, face vers nous, un peu devant l'axe (on la voit entre les deux moitiés).
    piece = flake("Eclat", 0.058, 12, thick=0.42)
    long_axis = -axis
    face = -forward
    side = face.cross(long_axis).normalized()
    center = matrix @ Vector((0.0, 0.0, 0.172)) - forward * 0.008
    piece.matrix_world = Matrix.Translation(center) @ Matrix((long_axis, side, face)).transposed().to_4x4()
    assign(piece, mat_flint_inside())

def img_assembler(skin=None):
    """Fabrication « Assembler » : la tête taillée (vue de trois quarts) entre dans la fente du manche ; une flèche, à
    côté, montre qu'elle y descend."""
    matrix = stick_frame(80.0, 90.0, (0.0, 0.0, 0.0))
    split_stick("Manche", 0.2, 0.012, 0.07, 24.0, matrix)
    right, up, forward = view_axes()
    axis = matrix.to_3x3() @ Vector((0.0, 0.0, 1.0))
    across = axis.cross(forward).normalized()
    top = matrix @ Vector((0.0, 0.0, 0.2))
    facing = (forward - axis * forward.dot(axis)).normalized()
    basis = Matrix((-across, facing, axis)).transposed()
    # Un peu tournée autour du manche : on voit qu'elle est plate et qu'elle a un tranchant.
    basis = Matrix.Rotation(math.radians(28.0), 3, axis) @ basis
    head = stone_head("Tete", 0, Matrix.Translation(top + axis * 0.062) @ basis.to_4x4())
    head.data.transform(Matrix.Scale(0.83, 4))
    arrow("Fleche", top + axis * 0.15 - across * 0.088, top + axis * 0.045 - across * 0.088, 0.011)

def img_ficeler(skin=None):
    """Fabrication « Ficeler » : le haut de la hache du jeu, la tête tenue par les tours de ficelle ; un bout de ficelle
    pend encore."""
    tool = import_model("hache_ficelee_0")
    tool.rotation_euler = Euler((math.radians(-14.0), math.radians(-24.0), 0.0))
    tool["cadre_axe"] = 2
    tool["cadre_min"] = 0.43
    bind = lin(COLORS["liens"][1])
    start = Vector((0.006, -0.012, 0.478))
    end_cord = tube("Bout", curve_points(start, Vector((0.032, -0.05, 0.432)), Vector((0.016, -0.01, 0.0)), 14, 0.0008, 4), 0.0022, 0.002, sides=8)
    end_cord.parent = tool
    assign(end_cord, noisy("Ficelle", tuple(c * 0.78 for c in bind), bind, scale=300.0, roughness=0.9, bump=0.2))


def img_poche(skin=None):
    """Inventaire : la poche : poche de tissu cousue, un peu gonflée, un caillou qui dépasse."""
    width, height = 0.12, 0.13
    outline = [(-0.06, 0.065), (0.06, 0.065), (0.058, -0.02), (0.0, -0.065), (-0.058, -0.02)]
    bm = bmesh.new()
    res = 44
    verts = {}
    from mathutils.geometry import intersect_point_line

    def inside(x, y):
        # Bord du polygone : distance au bord (positive dedans).
        count = len(outline)
        best = 1e9
        crossings = 0
        for k in range(count):
            a = Vector(outline[k])
            b = Vector(outline[(k + 1) % count])
            if (a.y > y) != (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x:
                crossings += 1
            point, factor = intersect_point_line(Vector((x, y)), a, b)
            factor = min(1.0, max(0.0, factor))
            best = min(best, (Vector((x, y)) - a.lerp(b, factor)).length)
        return best if crossings % 2 == 1 else -best

    for j in range(res + 1):
        for i in range(res + 1):
            x = -0.065 + 0.13 * i / res
            y = -0.07 + 0.14 * j / res
            d = inside(x, y)
            if d >= -0.0001:
                bulge = 0.014 * min(1.0, max(0.0, d) / 0.03) ** 0.6
                verts[(i, j)] = bm.verts.new((x, y, bulge))
    for j in range(res):
        for i in range(res):
            quad = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if all(q in verts for q in quad):
                bm.faces.new([verts[q] for q in quad])
    # Dos plat (épaisseur du tissu).
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.003)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    pocket = mesh_object("Poche", bm)
    # Tissu bleu croisé (sergé).
    if "Toile" not in _materials:
        mat = bpy.data.materials.new("Toile")
        tree, bsdf = _bsdf_tree(mat)
        coords = tree.nodes.new("ShaderNodeTexCoord").outputs["Object"]
        wave = tree.nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "DIAGONAL"
        wave.inputs["Scale"].default_value = 160.0
        wave.inputs["Distortion"].default_value = 1.5
        tree.links.new(coords, wave.inputs["Vector"])
        color, fac = _two_tone(tree, coords, (0.035, 0.07, 0.16), (0.09, 0.17, 0.36), 60.0)
        tree.links.new(_mix_color(tree, wave.outputs["Fac"], color, (0.12, 0.2, 0.38)), bsdf.inputs["Base Color"])
        _bump(tree, bsdf, wave.outputs["Fac"], 0.25, 0.005)
        _set(bsdf, roughness=0.88, specular=0.3, sheen=0.4)
        _materials["Toile"] = mat
    assign(pocket, _materials["Toile"])
    # Coutures : petits traits dorés le long du bord ; ourlet en haut.
    thread = principled("Fil", (0.85, 0.52, 0.12), roughness=0.55, specular=0.5)
    inset = []
    for k in range(len(outline)):
        a = Vector(outline[k])
        b = Vector(outline[(k + 1) % len(outline)])
        center = Vector((0.0, 0.005))
        inset.append((a + (center - a).normalized() * 0.008, b + (center - b).normalized() * 0.008))
    stitch = 0
    for k, (a, b) in enumerate(inset):
        length = (b - a).length
        count = int(length / 0.008)
        for n in range(count):
            t0 = (n + 0.15) / count
            t1 = (n + 0.65) / count
            p0 = a.lerp(b, t0)
            p1 = a.lerp(b, t1)
            z0 = 0.014 * min(1.0, max(0.0, inside(p0.x, p0.y)) / 0.03) ** 0.6 + 0.0012
            z1 = 0.014 * min(1.0, max(0.0, inside(p1.x, p1.y)) / 0.03) ** 0.6 + 0.0012
            dash = tube("Point_%d" % stitch, [(p0.x, p0.y, z0), (p1.x, p1.y, z1)], 0.0011, sides=6)
            assign(dash, thread)
            dash.parent = pocket
            stitch += 1
    hem = tube("Ourlet", [(-0.058, 0.057, 0.004), (0.058, 0.057, 0.004)], 0.0016, sides=6)
    assign(hem, thread)
    hem.parent = pocket
    stone = pebble("Caillou", 3, 0.045, mat_stone())
    stone.location = (0.016, 0.07, -0.002)
    stone.scale = (1.0, 1.0, 0.45)
    stone.parent = pocket
    toward = Vector((math.sin(math.radians(AZIMUTH)), -math.cos(math.radians(AZIMUTH)), 0.25)).normalized()
    up = Vector((0.0, 0.0, 1.0))
    up = (up - toward * up.dot(toward)).normalized()
    pocket.matrix_world = Matrix((up.cross(toward), up, toward)).transposed().to_4x4() @ Matrix.Rotation(math.radians(-6.0), 4, "Z")


IMAGES = {
    "main": img_main,
    "poche": img_poche,
    "creuser": img_creuser,
    "casser_objets": img_casser_objets,
    "recuperer_materiaux": img_recuperer_materiaux,
    "arracher": img_arracher,
    "poser": img_poser,
    "aplanir": img_aplanir,
    "lisser": img_lisser,
    "manger": img_manger,
    "tresser": img_tresser,
    "tailler": img_tailler,
    "fendre": img_fendre,
    "assembler": img_assembler,
    "ficeler": img_ficeler,
}
WITH_HAND = {"main", "recuperer_materiaux", "creuser", "casser_objets", "arracher", "tailler"}


def run():
    scene = studio()
    only = [n for n in os.environ.get("ORBMEKA_IMAGES", "").split(",") if n]
    skins = [s for s in os.environ.get("ORBMEKA_PEAUX", "").split(",") if s] or SKINS
    made = 0
    for name, build in IMAGES.items():
        if only and name not in only:
            continue
        for skin in (skins if name in WITH_HAND else [None]):
            clear_subject(scene)
            build(skin)
            shoot(scene, "%s_%s" % (name, skin) if skin else name)
            made += 1
    print("IMAGES : %d dans %s" % (made, OUT))


run()
