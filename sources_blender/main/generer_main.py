# OrbMeka 0.0.7.6 : main droite vue à la première personne (demande de l'utilisateur : une main tout à droite qui tient
# l'objet choisi). Modèle original fait ici, dans Blender, par ce script (aucun asset repris).
# Paume vers le haut, un peu creusée, doigts légèrement repliés : l'objet tenu repose dans la paume.
# Doigts, pouce et poignet : squelette de sommets + modificateur Skin (épaisseur par sommet) ; paume : sphère aplatie ;
# le tout lissé (Subdivision 1). Unités : mètres (main d'adolescent, environ 17 cm du poignet au bout du majeur).
# Repère : doigts vers +Y, paume vers +Z, pouce vers +X (main droite).
# 0.0.8.17 (#224, demande de l'utilisateur : animations des bras) : la même main dans d'autres poses, en formes de
# mélange (« shape keys », mêmes sommets) : prise (serrer un objet), griffe (creuser), ouverte (poser), pince (pouce et
# index). Le jeu passe de l'une à l'autre en douceur (first_person_hand.gd).
# Exporte assets/hands/main_droite.glb (sans matériau : le jeu met la couleur de peau du personnage).
# Lancer dans Blender : exec(open(r"<dossier du jeu>/sources_blender/main/generer_main.py").read())
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

GAME = os.environ.get("ORBMEKA_GAME", r"C:\Users\Dev\Desktop\Godot\orb-meka")
OUT = os.path.join(GAME, "assets", "hands", "main_droite.glb")
SCENE = "OrbMeka_Main"

scene = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
for obj in list(scene.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.context.window.scene = scene

# Doigts : [base de la phalange (jointure), longueurs des 3 phalanges, rayon].
FINGERS = [
    (Vector((0.031, 0.083, 0.0)), (0.040, 0.025, 0.020), 0.0088),   # index
    (Vector((0.011, 0.089, 0.002)), (0.045, 0.028, 0.022), 0.0092),  # majeur
    (Vector((-0.010, 0.085, 0.0)), (0.042, 0.026, 0.021), 0.0087),   # annulaire
    (Vector((-0.029, 0.074, -0.003)), (0.032, 0.021, 0.018), 0.0078),  # auriculaire
]
# Poses : repli de chaque articulation (degrés), de l'index à l'auriculaire ; pouce (4 points). « jeu » : la main de base.
POSES = {
    "jeu": {"doigts": [(14, 26, 22), (12, 24, 20), (14, 26, 22), (18, 28, 24)],
            "pouce": [(0.022, 0.012, -0.004), (0.046, 0.032, 0.006), (0.062, 0.055, 0.018), (0.069, 0.075, 0.03)]},
    "prise": {"doigts": [(40, 60, 45), (38, 58, 44), (42, 60, 45), (46, 62, 46)],
              "pouce": [(0.022, 0.012, -0.004), (0.044, 0.036, 0.016), (0.046, 0.06, 0.036), (0.034, 0.074, 0.05)]},
    "griffe": {"doigts": [(32, 52, 40), (30, 50, 38), (32, 52, 40), (36, 54, 42)],
               "pouce": [(0.022, 0.012, -0.004), (0.046, 0.034, 0.014), (0.058, 0.056, 0.034), (0.058, 0.072, 0.052)]},
    "ouverte": {"doigts": [(3, 6, 4), (2, 5, 4), (4, 6, 4), (6, 8, 6)],
                "pouce": [(0.022, 0.012, -0.004), (0.05, 0.03, 0.0), (0.071, 0.048, 0.004), (0.084, 0.064, 0.008)]},
    "pince": {"doigts": [(24, 34, 28), (34, 48, 36), (52, 70, 50), (56, 70, 50)],
              "pouce": [(0.022, 0.012, -0.004), (0.042, 0.04, 0.012), (0.046, 0.068, 0.03), (0.04, 0.094, 0.042)]},
}


def skeleton(pose):
    bm = bmesh.new()
    radii = []

    def vert(at, r):
        v = bm.verts.new(at)
        radii.append(r)
        return v

    # Avant-bras (sort du bas de l'écran) et poignet.
    arm = vert(Vector((0.0, -0.13, -0.012)), (0.032, 0.026))
    wrist = vert(Vector((0.0, -0.005, -0.004)), (0.028, 0.018))
    bm.edges.new((arm, wrist))
    for (base, lengths, radius), bends in zip(FINGERS, POSES[pose]["doigts"]):
        root = vert(base + Vector((0, -0.004, -0.002)), (radius * 1.15, radius * 1.05))
        # Relié au poignet (caché dans la paume) : le modificateur Skin ne fait qu'une pièce, à partir du poignet.
        bm.edges.new((wrist, root))
        at = base.copy()
        direction = Vector((base.x * 0.35, 1.0, 0.0)).normalized()
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
    # Pouce : de la base de la paume vers +X.
    thumb = [Vector(p) for p in POSES[pose]["pouce"]]
    previous = vert(thumb[0], (0.013, 0.011))
    bm.edges.new((wrist, previous))
    for index, point in enumerate(thumb[1:]):
        r = 0.0115 - 0.0012 * index
        current = vert(point, (r, r * 0.9))
        bm.edges.new((previous, current))
        previous = current
    mesh = bpy.data.meshes.new("Main_Squelette_" + pose)
    bm.to_mesh(mesh)
    bm.free()
    return mesh, radii


def palm_mesh():
    # Paume : sphère aplatie, un peu creusée (le centre plus bas que les bords).
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * 0.043, v.co.y * 0.052, v.co.z * 0.017))
        if v.co.z > 0:
            v.co.z -= 0.006 * max(0.0, 1.0 - (v.co.x / 0.043) ** 2 - (v.co.y / 0.052) ** 2)
        v.co += Vector((0.001, 0.042, -0.002))
    mesh = bpy.data.meshes.new("Main_Paume")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def hand_points(pose, palm):
    """La main d'une pose : doigts (Skin, Subdivision appliqués) et paume, en un seul maillage (bmesh)."""
    mesh, radii = skeleton(pose)
    fingers = bpy.data.objects.new("Main_Doigts_" + pose, mesh)
    scene.collection.objects.link(fingers)
    skin = fingers.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    for index, data in enumerate(mesh.skin_vertices[0].data):
        data.radius = radii[index]
    mesh.skin_vertices[0].data[0].use_root = True
    fingers.modifiers.new("Lisse", "SUBSURF").levels = 1
    depsgraph = bpy.context.evaluated_depsgraph_get()
    baked = bpy.data.meshes.new_from_object(fingers.evaluated_get(depsgraph))
    bpy.data.objects.remove(fingers, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    joined = bmesh.new()
    joined.from_mesh(baked)
    joined.from_mesh(palm)
    bpy.data.meshes.remove(baked)
    return joined


palm = palm_mesh()
base = hand_points("jeu", palm)
hand_mesh = bpy.data.meshes.new("Main_Droite")
base.to_mesh(hand_mesh)
base.free()
for poly in hand_mesh.polygons:
    poly.use_smooth = True
hand = bpy.data.objects.new("Main_Droite", hand_mesh)
scene.collection.objects.link(hand)
hand.shape_key_add(name="Base")
for pose in ["prise", "griffe", "ouverte", "pince"]:
    other = hand_points(pose, palm)
    other.verts.ensure_lookup_table()
    if len(other.verts) != len(hand_mesh.vertices):
        raise RuntimeError("pose %s : %d sommets au lieu de %d" % (pose, len(other.verts), len(hand_mesh.vertices)))
    points = [v.co.copy() for v in other.verts]
    other.free()
    # Le modificateur Skin numérote parfois deux sommets immobiles (bout de l'avant-bras) dans l'autre sens : ceux qui
    # sautent trop loin sont rendus à leur voisin le plus proche (sinon : des pointes en passant d'une pose à l'autre).
    base_points = [v.co for v in hand_mesh.vertices]
    jumped = [i for i in range(len(points)) if (points[i] - base_points[i]).length > 0.09]
    free = list(jumped)
    chosen = {}
    for i in jumped:
        best = min(free, key=lambda j: (points[j] - base_points[i]).length)
        free.remove(best)
        chosen[i] = points[best]
    for i, point in chosen.items():
        points[i] = point
    key = hand.shape_key_add(name=pose)
    for index, point in enumerate(points):
        key.data[index].co = point
bpy.data.meshes.remove(palm)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
hand.select_set(True)
bpy.context.view_layer.objects.active = hand
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, use_active_scene=True, export_materials="NONE", export_apply=False, export_morph=True,
                          export_morph_normal=True)
print("Main_Droite :", len(hand.data.polygons), "faces ;", len(hand.data.shape_keys.key_blocks) - 1, "poses ;",
      "dimensions", tuple(round(d, 3) for d in hand.dimensions), "->", OUT)
