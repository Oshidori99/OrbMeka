# OrbMeka 0.0.7.6 : main droite vue à la première personne (demande de l'utilisateur : une main tout à droite qui tient
# l'objet choisi). Modèle original fait ici, dans Blender, par ce script (aucun asset repris).
# Paume vers le haut, un peu creusée, doigts légèrement repliés : l'objet tenu repose dans la paume.
# Doigts, pouce et poignet : squelette de sommets + modificateur Skin (épaisseur par sommet) ; paume : sphère aplatie ;
# le tout lissé (Subdivision 1). Unités : mètres (main d'adolescent, environ 17 cm du poignet au bout du majeur).
# Repère : doigts vers +Y, paume vers +Z, pouce vers +X (main droite).
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

# Doigts : [base de la phalange (jointure), longueurs des 3 phalanges, rayon, angle de repli de chaque articulation].
FINGERS = [
    (Vector((0.031, 0.083, 0.0)), (0.040, 0.025, 0.020), 0.0088, (14, 26, 22)),   # index
    (Vector((0.011, 0.089, 0.002)), (0.045, 0.028, 0.022), 0.0092, (12, 24, 20)),  # majeur
    (Vector((-0.010, 0.085, 0.0)), (0.042, 0.026, 0.021), 0.0087, (14, 26, 22)),   # annulaire
    (Vector((-0.029, 0.074, -0.003)), (0.032, 0.021, 0.018), 0.0078, (18, 28, 24)),# auriculaire
]

def skeleton():
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
    for base, lengths, radius, bends in FINGERS:
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
    # Pouce : de la base de la paume vers +X, il remonte un peu pour tenir l'objet.
    thumb = [Vector((0.022, 0.012, -0.004)), Vector((0.046, 0.032, 0.006)), Vector((0.062, 0.055, 0.018)), Vector((0.069, 0.075, 0.03))]
    previous = vert(thumb[0], (0.013, 0.011))
    bm.edges.new((wrist, previous))
    for index, point in enumerate(thumb[1:]):
        r = 0.0115 - 0.0012 * index
        current = vert(point, (r, r * 0.9))
        bm.edges.new((previous, current))
        previous = current
    mesh = bpy.data.meshes.new("Main_Squelette")
    bm.to_mesh(mesh)
    bm.free()
    return mesh, radii

mesh, radii = skeleton()
fingers = bpy.data.objects.new("Main_Doigts", mesh)
scene.collection.objects.link(fingers)
skin = fingers.modifiers.new("Skin", "SKIN")
skin.use_smooth_shade = True
for index, data in enumerate(mesh.skin_vertices[0].data):
    data.radius = radii[index]
mesh.skin_vertices[0].data[0].use_root = True
fingers.modifiers.new("Lisse", "SUBSURF").levels = 1

# Paume : sphère aplatie, un peu creusée (le centre plus bas que les bords).
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0)
for v in bm.verts:
    v.co = Vector((v.co.x * 0.043, v.co.y * 0.052, v.co.z * 0.017))
    if v.co.z > 0:
        v.co.z -= 0.006 * max(0.0, 1.0 - (v.co.x / 0.043) ** 2 - (v.co.y / 0.052) ** 2)
    v.co += Vector((0.001, 0.042, -0.002))
palm_mesh = bpy.data.meshes.new("Main_Paume")
bm.to_mesh(palm_mesh)
bm.free()
for poly in palm_mesh.polygons:
    poly.use_smooth = True
palm = bpy.data.objects.new("Main_Paume", palm_mesh)
scene.collection.objects.link(palm)

# Un seul objet, modificateurs appliqués.
bpy.context.view_layer.objects.active = fingers
for obj in scene.objects:
    obj.select_set(True)
depsgraph = bpy.context.evaluated_depsgraph_get()
evaluated = fingers.evaluated_get(depsgraph)
baked = bpy.data.meshes.new_from_object(evaluated)
fingers.modifiers.clear()
fingers.data = baked
bpy.ops.object.join()
hand = bpy.context.view_layer.objects.active
hand.name = "Main_Droite"
for poly in hand.data.polygons:
    poly.use_smooth = True

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
hand.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_materials="NONE", export_apply=True)
print("Main_Droite :", len(hand.data.polygons), "faces ;", "dimensions", tuple(round(d, 3) for d in hand.dimensions), "->", OUT)
