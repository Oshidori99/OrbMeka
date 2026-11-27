# OrbMeka 0.0.8.53 (lot C1, demande de l'utilisateur : de vrais modèles pour le feu de camp, la torche et l'archet à feu,
# faits dans Blender ; tout original). Modèles à exporter dans assets/items/ :
# - feu_camp.glb : un lit de cendre, un cercle de pierres irrégulières, des bûches en tipi et du petit bois (éteint) ;
# - feu_camp_braise.glb : le même, les bûches noircies, des braises sur la cendre (allumé ; les flammes restent celles
#   du jeu, fire.gd) ;
# - torche_tete.glb : la tête d'une torche : une botte de fibres serrée, deux liens de cordelette ;
# - torche_forte_tete.glb : la tête d'une torche forte : des lanières d'écorce de pin résineuse enroulées, des gouttes de
#   résine, deux liens ;
# - archet.glb : l'archet à feu : une branche souple courbée, une cordelette tendue d'un bout à l'autre, nouée aux bouts.
# Têtes et archet sont dans le repère du bâton du jeu (ground_items.gd : cylindre de rayon 0,5 et de hauteur 1, le bout à
# +0,5) : le jeu les met à la taille de chaque objet (épaisseur, longueur) et leur bâton prend l'écorce de son essence.
# Les feux sont à leur vraie taille (environ 75 cm de large), base à z = 0.
# Lancer dans Blender : exec(open(r"<dossier du jeu>/sources_blender/feu/generer_feu.py").read())
# Travaille dans sa propre scène (OrbMeka_Feu) ; ne touche à rien d'autre.
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, noise

GAME = os.environ.get("ORBMEKA_GAME", r"C:\Users\Dev\Desktop\Godot\orb-meka")
OUT = os.path.join(GAME, "assets", "items")
# 0.0.8.53 : copies à leur vraie taille (torches avec leur bâton) pour les images des menus (../menus).
MODELS = os.path.join(GAME, "sources_blender", "menus", "modeles")
SCENE = "OrbMeka_Feu"
# Tailles de référence (celles du catalogue du jeu, inventory.gd CATALOG_MODELS).
TORCH_LENGTH = 0.55
TORCH_THICK = 0.03
BOW_LENGTH = 0.7
BOW_THICK = 0.02


def lin(hex_color):
    c = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def material(name, hex_color, roughness=0.9, emission=None, strength=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*lin(hex_color), 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*lin(emission), 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def new_object(name, bm, materials):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for mat in materials:
        mesh.materials.append(mat)
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def tube(bm, points, radii, sides=8, mat=0, cap=True):
    """Tube le long de points (rayon par point) ; matière n° mat ; bouts fermés."""
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
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        rings.append([bm.verts.new(p + (normal * math.cos(k * math.tau / sides) + b * math.sin(k * math.tau / sides)) * r) for k in range(sides)])
    for i in range(count - 1):
        for k in range(sides):
            f = bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
            f.material_index = mat
    if cap:
        for ring, flip in ((rings[0], True), (rings[-1], False)):
            f = bm.faces.new(list(reversed(ring)) if flip else ring)
            f.material_index = mat
    return rings


def blob(bm, at, size, rng, mat=0, subdivisions=2, rough=0.25):
    """Pierre irrégulière : icosphère aplatie et bosselée."""
    made = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    seed = Vector((rng.random() * 50, rng.random() * 50, rng.random() * 50))
    for v in made["verts"]:
        d = v.co.normalized()
        bump = 1.0 + rough * noise.noise(d * 1.7 + seed) + rough * 0.5 * noise.noise(d * 4.1 + seed)
        v.co = Vector((d.x * size.x, d.y * size.y, d.z * size.z)) * bump + at
    for f in {face for vert in made["verts"] for face in vert.link_faces}:
        f.material_index = mat
    for f in {face for vert in made["verts"] for face in vert.link_faces}:
        f.smooth = True


def log(bm, start, end, radius, rng, bark=0, cut=1, sides=9):
    """Bûche : écorce bosselée, bouts coupés (autre matière)."""
    steps = 6
    axis = end - start
    pts = [start + axis * (i / steps) for i in range(steps + 1)]
    radii = [radius * (1.0 + 0.06 * math.sin(i * 1.7 + rng.random() * 6.0)) for i in range(steps + 1)]
    rings = tube(bm, pts, radii, sides, bark, cap=False)
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        f = bm.faces.new(list(reversed(ring)) if flip else ring)
        f.material_index = cut


def campfire(name, lit):
    rng = random.Random(209)
    bm = bmesh.new()
    # Matières : 0 pierre claire, 1 pierre sombre, 2 écorce (ou bois noirci), 3 bois coupé, 4 cendre, 5 braises.
    # Lit de cendre : un disque bas aux bords irréguliers.
    ash_rings = []
    for ring in range(4):
        r = 0.27 * (ring + 1) / 4.0
        z = 0.016 * (1.0 - (ring / 3.0) ** 2)
        verts = []
        for k in range(24):
            a = k * math.tau / 24
            wobble = 1.0 + 0.12 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, ring)))
            verts.append(bm.verts.new(Vector((math.cos(a) * r * wobble, math.sin(a) * r * wobble, z))))
        ash_rings.append(verts)
    center = bm.verts.new(Vector((0, 0, 0.018)))
    for k in range(24):
        f = bm.faces.new((center, ash_rings[0][k], ash_rings[0][(k + 1) % 24]))
        f.material_index = 4
    for ring in range(3):
        for k in range(24):
            f = bm.faces.new((ash_rings[ring][k], ash_rings[ring + 1][k], ash_rings[ring + 1][(k + 1) % 24], ash_rings[ring][(k + 1) % 24]))
            f.material_index = 4
    # Cercle de pierres (9), chacune à sa taille, un peu enfoncée.
    for k in range(9):
        a = k * math.tau / 9 + rng.uniform(-0.12, 0.12)
        size = Vector((rng.uniform(0.07, 0.1), rng.uniform(0.055, 0.08), rng.uniform(0.045, 0.065)))
        at = Vector((math.cos(a) * 0.33, math.sin(a) * 0.33, size.z * 0.55))
        rot = Matrix.Rotation(a + rng.uniform(-0.4, 0.4), 3, "Z")
        made = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        seed = Vector((rng.random() * 50, rng.random() * 50, rng.random() * 50))
        for v in made["verts"]:
            d = v.co.normalized()
            bump = 1.0 + 0.22 * noise.noise(d * 1.6 + seed) + 0.1 * noise.noise(d * 4.3 + seed)
            local = Vector((d.x * size.x, d.y * size.y, d.z * size.z)) * bump
            v.co = rot @ local + at
        for f in {face for vert in made["verts"] for face in vert.link_faces}:
            f.material_index = 0 if k % 3 else 1
            f.smooth = True
    # Bûches en tipi (4), petit bois au centre.
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        foot = Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, 0.03))
        top = Vector((math.cos(a + 0.5) * 0.03, math.sin(a + 0.5) * 0.03, 0.3 + 0.02 * k))
        log(bm, foot, top, rng.uniform(0.032, 0.042), rng, 2, 3)
    for k in range(7):
        a = rng.random() * math.tau
        foot = Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.02))
        top = Vector((math.cos(a + 2.5) * 0.04, math.sin(a + 2.5) * 0.04, 0.12 + rng.random() * 0.05))
        log(bm, foot, top, rng.uniform(0.007, 0.011), rng, 2, 3, sides=5)
    if lit:
        # Braises : petits morceaux rougeoyants sur la cendre, au pied des bûches.
        for k in range(14):
            a = rng.random() * math.tau
            r = rng.uniform(0.02, 0.17)
            blob(bm, Vector((math.cos(a) * r, math.sin(a) * r, 0.02)), Vector((rng.uniform(0.014, 0.026), rng.uniform(0.012, 0.022), rng.uniform(0.008, 0.012))), rng, 5, 1, 0.3)
    mats = [material("Feu_pierre_claire", "8a8680", 0.92), material("Feu_pierre_sombre", "5f5c58", 0.9),
            material("Feu_bois_noirci" if lit else "Feu_ecorce", "2b2420" if lit else "5e4129", 0.95),
            material("Feu_bois_coupe_noirci" if lit else "Feu_bois_coupe", "3a2a20" if lit else "a88a5e", 0.9),
            material("Feu_cendre", "4a4642", 1.0),
            material("Feu_braise", "3a1408", 0.8, "ff5a14", 6.0)]
    return new_object(name, bm, mats)


def to_stick_space(obj, length, thick):
    """Du repère réel (bâton le long de z, de 0 à length) au repère du bâton du jeu (rayon 0,5, hauteur 1, centré)."""
    mesh = obj.data
    for v in mesh.vertices:
        v.co = Vector((v.co.x / thick, v.co.y / thick, (v.co.z - length * 0.5) / length))


def torch_head(name, strong, real=False):
    rng = random.Random(214 if not strong else 215)
    bm = bmesh.new()
    # Repère réel : le bâton le long de z, de 0 (bas) à TORCH_LENGTH (bout) ; la tête sur les 15 derniers cm.
    low = TORCH_LENGTH - 0.15
    high = TORCH_LENGTH + 0.012
    if not strong:
        # Botte de fibres : un fuseau cannelé (les brins), le haut en brosse.
        sides = 18
        steps = 10
        rings = []
        for i in range(steps + 1):
            t = i / steps
            z = low + (high - low) * t
            bulge = 0.024 + 0.012 * math.sin(math.pi * min(1.0, t * 1.15)) - 0.006 * t ** 4
            ring = []
            for k in range(sides):
                a = k * math.tau / sides
                groove = 1.0 + 0.09 * math.cos(a * 9 + t * 2.0) + 0.05 * noise.noise(Vector((math.cos(a) * 3, math.sin(a) * 3, t * 6)))
                ring.append(bm.verts.new(Vector((math.cos(a) * bulge * groove, math.sin(a) * bulge * groove, z))))
            rings.append(ring)
        for i in range(steps):
            for k in range(sides):
                f = bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
                f.material_index = 0
        top = bm.verts.new(Vector((0, 0, high + 0.01)))
        bottom = bm.verts.new(Vector((0, 0, low - 0.004)))
        for k in range(sides):
            bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], top)).material_index = 0
            bm.faces.new((rings[0][(k + 1) % sides], rings[0][k], bottom)).material_index = 0
        # Quelques brins qui dépassent en haut.
        for k in range(9):
            a = rng.random() * math.tau
            r = rng.uniform(0.004, 0.016)
            base = Vector((math.cos(a) * r, math.sin(a) * r, high - 0.004))
            tip = base + Vector((math.cos(a) * 0.012, math.sin(a) * 0.012, rng.uniform(0.018, 0.035)))
            tube(bm, [base, (base + tip) * 0.5, tip], [0.0022, 0.0016, 0.0006], 4, 0)
        mats = [material("Torche_fibres", "a3955c", 0.95), material("Torche_lien", "b9a66c", 0.95)]
    else:
        # Lanières d'écorce de pin enroulées en spirale, qui se chevauchent ; gouttes de résine.
        for strip in range(5):
            turn0 = strip * math.tau / 5 + rng.uniform(-0.2, 0.2)
            pts = []
            span = 0.9
            for i in range(12):
                t = i / 11
                z = low + 0.01 + (high - low - 0.02) * t
                a = turn0 + t * 0.9
                r = 0.026 + 0.008 * math.sin(math.pi * t) + 0.002 * strip
                pts.append((a, z, r))
            prev = None
            for (a, z, r) in pts:
                ring = [bm.verts.new(Vector((math.cos(a + d) * (r + 0.0025 * (j % 2)), math.sin(a + d) * (r + 0.0025 * (j % 2)), z))) for j, d in enumerate((-span * 0.5, -span * 0.25, 0.0, span * 0.25, span * 0.5))]
                if prev is not None:
                    for j in range(4):
                        bm.faces.new((prev[j], prev[j + 1], ring[j + 1], ring[j])).material_index = 0
                prev = ring
        # Cœur (sous les lanières) et bout fermé.
        tube(bm, [Vector((0, 0, low)), Vector((0, 0, high))], 0.022, 10, 0)
        for k in range(10):
            a = rng.random() * math.tau
            z = rng.uniform(low + 0.02, high - 0.01)
            r = 0.033 + 0.006 * math.sin(math.pi * (z - low) / (high - low))
            blob(bm, Vector((math.cos(a) * r, math.sin(a) * r, z)), Vector((0.004, 0.004, rng.uniform(0.006, 0.011))), rng, 2, 1, 0.15)
        mats = [material("Torche_ecorce_pin", "5e3a22", 0.55), material("Torche_lien", "b9a66c", 0.95), material("Torche_resine", "c98a2e", 0.25)]
    # Deux liens de cordelette (quelques tours serrés).
    for z in (low + 0.025, high - 0.035):
        r = 0.031 if not strong else 0.037
        pts = [Vector((math.cos(k * 0.5) * r, math.sin(k * 0.5) * r, z + k * 0.0007)) for k in range(int(math.tau * 2.2 / 0.5) + 1)]
        tube(bm, pts, 0.0026, 5, 1)
    if real:
        # Le bâton (images des menus) : écorce brune, un peu plus fin vers le bas.
        tube(bm, [Vector((0, 0, 0.0)), Vector((0, 0, TORCH_LENGTH - 0.02))], [TORCH_THICK * 0.42, TORCH_THICK * 0.5], 10, len(mats))
        mats.append(material("Torche_baton", "6b4a2e", 0.9))
    obj = new_object(name, bm, mats)
    if not real:
        to_stick_space(obj, TORCH_LENGTH, TORCH_THICK)
    return obj


def fire_bow(name, real=False):
    rng = random.Random(208)
    bm = bmesh.new()
    # Repère réel : la branche courbée dans le plan x-z (la flèche de 6 cm vers +x), de z = 0 à BOW_LENGTH.
    sag = 0.06
    pts = []
    radii = []
    for i in range(17):
        t = i / 16
        z = BOW_LENGTH * t
        x = sag * math.sin(math.pi * t)
        pts.append(Vector((x, 0.0, z)))
        radii.append(BOW_THICK * 0.5 * (1.0 - 0.2 * abs(t - 0.5) * 2.0) * (1.0 + 0.05 * noise.noise(Vector((t * 9, 0, 0)))))
    tube(bm, pts, radii, 8, 0)
    # Encoches et cordelette nouée aux deux bouts (quelques tours), tendue d'un bout à l'autre.
    ends = (Vector((0.0, 0.0, 0.03)), Vector((0.0, 0.0, BOW_LENGTH - 0.03)))
    for end in ends:
        coil = [end + Vector((math.cos(k * 0.6) * 0.0105, math.sin(k * 0.6) * 0.0105, (k - 8) * 0.0009)) for k in range(17)]
        tube(bm, coil, 0.0022, 5, 1)
    tube(bm, [ends[0] + Vector((-0.004, 0, 0)), ends[1] + Vector((-0.004, 0, 0))], 0.0018, 5, 1)
    # Deux petits nœuds de l'écorce.
    for z in (0.22, 0.46):
        t = z / BOW_LENGTH
        blob(bm, Vector((sag * math.sin(math.pi * t) + 0.008, 0.0, z)), Vector((0.006, 0.006, 0.009)), rng, 0, 1, 0.2)
    obj = new_object(name, bm, [material("Archet_bois", "8a6440", 0.9), material("Archet_corde", "b9a66c", 0.95)])
    if not real:
        to_stick_space(obj, BOW_LENGTH, BOW_THICK)
    return obj


def export(obj, path):
    for other in bpy.context.scene.objects:
        other.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, use_active_scene=True, export_format="GLB",
                              export_apply=True, export_yup=True, export_materials="EXPORT")


def run():
    scene = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    bpy.context.window.scene = scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in [m for m in bpy.data.meshes if m.users == 0 and m.name.split(".")[0] in ("Feu_camp", "Feu_camp_braise", "Torche_tete", "Torche_forte_tete", "Archet", "Torche_reelle", "Torche_forte_reelle", "Archet_reel")]:
        bpy.data.meshes.remove(mesh)
    os.makedirs(OUT, exist_ok=True)
    made = {
        "feu_camp.glb": campfire("Feu_camp", False),
        "feu_camp_braise.glb": campfire("Feu_camp_braise", True),
        "torche_tete.glb": torch_head("Torche_tete", False),
        "torche_forte_tete.glb": torch_head("Torche_forte_tete", True),
        "archet.glb": fire_bow("Archet"),
    }
    real = {
        "feu_camp.glb": made["feu_camp.glb"],
        "torche.glb": torch_head("Torche_reelle", False, True),
        "torche_forte.glb": torch_head("Torche_forte_reelle", True, True),
        "archet.glb": fire_bow("Archet_reel", True),
    }
    x = 0.0
    for file, obj in made.items():
        export(obj, os.path.join(OUT, file))
        print("FEU :", file, len(obj.data.polygons), "faces")
    for file, obj in real.items():
        export(obj, os.path.join(MODELS, file))
        print("FEU (images des menus) :", file)
    # Rangés côte à côte pour les regarder (après l'export, qui garde leur place d'origine).
    for obj in list(made.values()) + [real["torche.glb"], real["torche_forte.glb"], real["archet.glb"]]:
        obj.location.x = x
        x += 1.0


run()
