# OrbMeka 0.0.8.58 (demande de l'utilisateur : « en baissant la tête, je veux en voir le plus possible : ventre, jambes,
# pieds, mais joli ») : le corps vu à la première personne, pour chacun des 4 personnages humains. Le script lit le modèle
# du jeu déjà équipé de son squelette (assets/characters/<nom>.glb, equiper_personnages.py) et en fait une copie
# <nom>_1p.glb :
# - sans la tête (visage, cheveux), sans les manches, les avant-bras ni les mains : à la première personne, les mains du
#   jeu (first_person_hand.gd) les remplacent, et la tête serait devant les yeux ; toutes les pièces restantes sont
#   fermées (le haut, le pantalon ou la robe, les chaussures) : on ne voit jamais l'intérieur (plus de « disque rouge ») ;
# - avec un ombrage doux calculé ici (occlusion ambiante, dans la couleur des sommets « AO ») : chaque sommet regarde
#   autour de lui (AO_RAYS rayons), en comptant aussi la tête et les bras enlevés et le sol ; le haut du tee-shirt est
#   ainsi à l'ombre du menton et des bras, le pantalon sous l'ourlet du haut, l'intérieur des jambes. Le jeu multiplie la
#   couleur par cet ombrage (player.gd, BODY_1P_SHADER).
# Même squelette (mêmes os, mêmes poids) : il marche comme le corps entier (character_rig.gd).
# Lancer dans Blender : exec(open(r"<dossier du jeu>/sources_blender/personnages/corps_premiere_personne.py").read())
# Variables : ORBMEKA_PERSOS=boy14 (seulement ceux-là), ORBMEKA_SANS_EXPORT=1 (ne rien écrire). Scène : OrbMeka_Corps1P.
import bpy, bmesh, math, os, random
from mathutils import Vector
from mathutils.bvhtree import BVHTree

GAME = os.environ.get("ORBMEKA_GAME", r"C:\Users\Dev\Desktop\Godot\orb-meka")
FOLDER = os.path.join(GAME, "assets", "characters")
SCENE = "OrbMeka_Corps1P"
HUMANS = ["boy9", "girl9", "boy14", "girl14"]
# Pièces enlevées (rôles de equiper_personnages.classify).
REMOVED = ("tete", "manche", "avantbras", "main")
AO_RAYS = 96
AO_DISTANCE = 0.4
AO_STRENGTH = 0.7
# Ombre plus douce que noire : le plus sombre gardé (le jeu éclaire aussi).
AO_FLOOR = 0.42

_rig_tools = {"__name__": "orbmeka_corps1p"}
_saved = os.environ.get("ORBMEKA_SANS_EXPORT")
os.environ["ORBMEKA_SANS_EXPORT"] = "1"
exec(open(os.path.join(GAME, "sources_blender", "personnages", "equiper_personnages.py"), encoding="utf-8").read(), _rig_tools)
if _saved is None:
    del os.environ["ORBMEKA_SANS_EXPORT"]
else:
    os.environ["ORBMEKA_SANS_EXPORT"] = _saved


def import_rigged(name):
    scene = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    bpy.context.window.scene = scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(FOLDER, name + ".glb"))
    made = [o for o in bpy.data.objects if o not in before]
    mesh = max((o for o in made if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    rig = next(o for o in made if o.type == "ARMATURE")
    for obj in made:
        if obj not in (mesh, rig):
            bpy.data.objects.remove(obj, do_unlink=True)
    mesh.name = name + "_1p"
    rig.name = name + "_1p_squelette"
    return mesh, rig


def hemisphere(normal, rng):
    """Direction au hasard autour de la normale (plus souvent près d'elle : comme la lumière d'un ciel couvert)."""
    u = rng.random()
    v = rng.random()
    r = math.sqrt(u)
    theta = 2.0 * math.pi * v
    local = Vector((r * math.cos(theta), r * math.sin(theta), math.sqrt(max(0.0, 1.0 - u))))
    helper = Vector((1.0, 0.0, 0.0)) if abs(normal.x) < 0.9 else Vector((0.0, 1.0, 0.0))
    tangent = normal.cross(helper).normalized()
    bitangent = normal.cross(tangent)
    return (tangent * local.x + bitangent * local.y + normal * local.z).normalized()


def ambient_occlusion(mesh, kept):
    """Ombrage de chaque sommet gardé (0 à 1), le modèle entier et le sol comptant comme obstacles."""
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    ground = min(v.co.z for v in bm.verts)
    # Le sol : un grand carré sous les pieds.
    size = 3.0
    corners = [bm.verts.new((x, y, ground - 0.001)) for x, y in ((-size, -size), (size, -size), (size, size), (-size, size))]
    bm.faces.new(corners)
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    bm.verts.ensure_lookup_table()
    rng = random.Random(58)
    shade = {}
    for index in kept:
        vert = bm.verts[index]
        normal = vert.normal.normalized() if vert.normal.length > 0.0 else Vector((0.0, 0.0, 1.0))
        origin = vert.co + normal * 0.003
        blocked = 0.0
        for ray in range(AO_RAYS):
            direction = hemisphere(normal, rng)
            hit = tree.ray_cast(origin, direction, AO_DISTANCE)
            if hit[0] is not None:
                # Un obstacle proche compte plus qu'un lointain.
                blocked += 1.0 - (hit[3] / AO_DISTANCE) ** 2
        occlusion = blocked / AO_RAYS
        shade[index] = max(AO_FLOOR, 1.0 - AO_STRENGTH * occlusion)
    bm.free()
    return shade


def make_first_person(name):
    mesh, rig = import_rigged(name)
    parts = _rig_tools["islands"](mesh, name)
    _rig_tools["classify"](parts)
    removed = set()
    kept = []
    for p in parts:
        if p["role"] in REMOVED:
            removed.update(p["verts"])
        else:
            kept.extend(p["verts"])
    shade = ambient_occlusion(mesh, kept)
    # Couleur des sommets « AO » (gris : ombrage), la seule : exportée comme COLOR_0.
    for attribute in list(mesh.data.color_attributes):
        mesh.data.color_attributes.remove(attribute)
    colors = mesh.data.color_attributes.new("AO", "FLOAT_COLOR", "POINT")
    for index, value in shade.items():
        colors.data[index].color = (value, value, value, 1.0)
    for index in removed:
        colors.data[index].color = (1.0, 1.0, 1.0, 1.0)
    mesh.data.color_attributes.active_color = colors
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in removed], context="VERTS")
    bm.to_mesh(mesh.data)
    bm.free()
    roles = {}
    for p in parts:
        roles[p["role"]] = roles.get(p["role"], 0) + 1
    values = list(shade.values())
    print("CORPS1P", name, "gardés", len(kept), "enlevés", len(removed), "pièces", roles, "ombrage", round(min(values), 2), "à", round(max(values), 2))
    return mesh, rig


def export(name, mesh, rig):
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    mesh.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=os.path.join(FOLDER, name + "_1p.glb"), use_selection=True, use_active_scene=True,
                              export_format="GLB", export_apply=False, export_yup=True, export_materials="EXPORT",
                              export_skins=True, export_animations=False, export_vertex_color="ACTIVE")


def run(export_files=True):
    only = [n for n in os.environ.get("ORBMEKA_PERSOS", "").split(",") if n] or HUMANS
    results = {}
    for name in only:
        mesh, rig = make_first_person(name)
        if export_files:
            export(name, mesh, rig)
        results[name] = (mesh, rig)
    return results


if os.environ.get("ORBMEKA_SANS_EXPORT") != "1":
    run()
