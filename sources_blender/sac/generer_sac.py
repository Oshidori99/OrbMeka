# OrbMeka 0.0.8.21 (#207, demandes de l'utilisateur) : sac en filet, fait ici dans Blender (tout original).
# Un filet de cordelette en losanges (deux séries de cordelettes en spirale qui se croisent, un petit nœud à chaque
# croisement), un ourlet en haut et la bretelle. Deux modèles, à leur vraie taille (environ 32 cm de haut porté) :
# - assets/items/sac_filet.glb : posé à plat au sol (base à z = 0), la bretelle enroulée à côté ;
# - assets/items/sac_filet_porte.glb : porté, il pend, l'ourlet en haut, la bretelle qui monte vers l'épaule.
# Une copie du modèle posé va dans sources_blender/menus/modeles/ (image du sac et image « Nouer » des menus).
# Lancer dans Blender : exec(open(r"<dossier du jeu>/sources_blender/sac/generer_sac.py").read())
# Travaille dans sa propre scène (OrbMeka_Sac) ; ne touche à rien d'autre.
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

GAME = os.environ.get("ORBMEKA_GAME", r"C:\Users\Dev\Desktop\Godot\orb-meka")
OUT = os.path.join(GAME, "assets", "items")
MODELS = os.path.join(GAME, "sources_blender", "menus", "modeles")
SCENE = "OrbMeka_Sac"
# Couleur de la cordelette de lin du jeu (#b9a66c), en linéaire.
CORD = "b9a66c"
CORDS = 9           # cordelettes dans chaque sens (losanges)
CORD_RADIUS = 0.0035
HEIGHT = 0.30
RIM = 0.075         # rayon de l'ourlet (le haut, un peu resserré)
BELLY = 0.13        # rayon au plus large


def lin(hex_color):
    c = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def material():
    mat = bpy.data.materials.get("Cordelette_sac") or bpy.data.materials.new("Cordelette_sac")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*lin(CORD), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.95
    return mat


def profile(v):
    """Rayon du sac à la hauteur v (0 : fond, 1 : ourlet) : fond arrondi, ventre, haut resserré."""
    belly = math.sin(math.pi * min(1.0, 0.12 + v * 0.95)) ** 0.7
    return max(RIM * v ** 2, BELLY * belly * (1.0 - 0.42 * v ** 2.5)) + 0.004


def surface(u, v, flat, lying=False):
    """Point du sac : u (tour, 0 à 1), v (0 fond à 1 haut). flat : épaisseur (1 rond, 0,5 aplati). Porté : aplati
    d'avant en arrière (y) et pendu (z vers le bas) ; posé : couché le long de x, aplati en hauteur (z)."""
    r = profile(v)
    a = math.tau * u
    if lying:
        return Vector((HEIGHT * v, math.cos(a) * r, (math.sin(a) + 1.0) * r * flat))
    return Vector((math.cos(a) * r, math.sin(a) * r * flat, -HEIGHT * (1.0 - v)))


def tube(bm, points, radius, sides=5):
    rings = []
    normal = None
    count = len(points)
    for i, p in enumerate(points):
        t = (points[min(i + 1, count - 1)] - points[max(i - 1, 0)]).normalized()
        if normal is None:
            helper = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            normal = t.cross(helper).normalized()
        else:
            normal = (normal - t * normal.dot(t)).normalized()
        b = t.cross(normal)
        rings.append([bm.verts.new(p + (normal * math.cos(k * math.tau / sides) + b * math.sin(k * math.tau / sides)) * radius) for k in range(sides)])
    for i in range(count - 1):
        for k in range(sides):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))


def knot(bm, at, radius):
    made = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
    for v in made["verts"]:
        v.co += at


def build(name, worn):
    rng = random.Random(207)
    lying = not worn
    flat = 0.62 if worn else 0.32
    bm = bmesh.new()
    steps = 18

    def at(u, v):
        return surface(u, v, flat, lying)

    # Deux séries de cordelettes en spirale (sens inverses) : elles se croisent en losanges ; un nœud à chaque croisement.
    for direction in (1, -1):
        for c in range(CORDS):
            points = []
            for s in range(steps + 1):
                v = 0.04 + 0.96 * s / steps
                u = c / CORDS + direction * 0.5 * v
                p = at(u, v)
                p += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.0012
                points.append(p)
            tube(bm, points, CORD_RADIUS)
    # Nœuds : là où les deux sens se croisent.
    for c in range(CORDS):
        for k in range(1, CORDS):
            v = k / CORDS
            u = (c + 0.5 * (k % 2)) / CORDS
            knot(bm, at(u, 0.04 + 0.96 * v), CORD_RADIUS * 1.9)
    # Fond (petit nœud qui réunit tout) et ourlet en haut.
    knot(bm, at(0.0, 0.0), CORD_RADIUS * 3.0)
    rim = [at(i / 24, 1.0) for i in range(25)]
    tube(bm, rim, CORD_RADIUS * 1.5, sides=6)
    # Bretelle : porté, elle monte vers l'épaule ; posé, une boucle couchée au sol, devant l'ourlet.
    if worn:
        top_a = at(0.0, 1.0)
        top_b = at(0.5, 1.0)
        strap = [top_a.lerp(top_b, i / 16) + Vector((0, 0.01, 0.42 * math.sin(math.pi * i / 16) ** 0.6)) for i in range(17)]
        tube(bm, strap, CORD_RADIUS * 1.6, sides=6)
    else:
        start = at(0.0, 1.0)
        loop = []
        for i in range(33):
            a = math.tau * i / 32
            loop.append(Vector((start.x + 0.09 + 0.09 * math.sin(a - math.pi / 2) + 0.09, 0.1 * math.sin(a) * (1.0 + 0.1 * i / 32), CORD_RADIUS * 1.6)))
        loop.insert(0, start)
        tube(bm, loop, CORD_RADIUS * 1.6, sides=6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(material())
    bpy.context.scene.collection.objects.link(obj)
    if lying:
        # Posé : base à z = 0, centré.
        low = min(v.co.z for v in obj.data.vertices)
        center = sum((v.co for v in obj.data.vertices), Vector()) / len(obj.data.vertices)
        for v in obj.data.vertices:
            v.co -= Vector((center.x, center.y, low))
    return obj


def export(obj, path):
    for other in bpy.context.scene.objects:
        other.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # Seulement cet objet, de cette scène (sans les objets choisis dans les autres scènes du fichier).
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, use_active_scene=True, export_format="GLB",
                              export_apply=True, export_yup=True, export_materials="EXPORT")


def run():
    scene = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    bpy.context.window.scene = scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in [m for m in bpy.data.meshes if m.name.startswith("Sac_filet") and m.users == 0]:
        bpy.data.meshes.remove(mesh)
    os.makedirs(OUT, exist_ok=True)
    lying = build("Sac_filet", False)
    worn = build("Sac_filet_porte", True)
    worn.location.x = 0.5
    export(lying, os.path.join(OUT, "sac_filet.glb"))
    export(lying, os.path.join(MODELS, "sac_filet.glb"))
    export(worn, os.path.join(OUT, "sac_filet_porte.glb"))
    print("SAC :", len(lying.data.polygons), "faces (posé),", len(worn.data.polygons), "faces (porté)")


run()
