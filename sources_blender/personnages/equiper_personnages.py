# OrbMeka 0.0.8.54 (lot C1, #224, #225, #230 : demandes de l'utilisateur) : un squelette pour les personnages humains
# (assets/characters/boy9, girl9, boy14, girl14), pour animer leurs bras (et plus tard leurs jambes) dans le jeu et leur
# mettre un objet en main. Le script lit chaque modèle .glb du jeu (fait dans personnages.blend, rangé hors du dépôt).
# Chaque personnage est fait de pièces séparées (tête, cheveux, haut, manches, avant-bras, mains, jambes, chaussures) :
# chaque pièce suit son os, les articulations sont aux jonctions des pièces (bas de la manche : coude ; haut de la main :
# poignet ; haut d'une jambe : hanche ; haut de la chaussure : cheville), les pièces longues (jambes, tronc) plient en
# douceur (passage d'un os à l'autre sur quelques centimètres). Puis le .glb est réexporté avec son squelette (mêmes
# matières, même place, même taille ; relancer le script sur un modèle déjà équipé refait la même chose).
# Os (noms lus par le jeu, character_rig.gd) : Bassin, Dos, Poitrine, Cou, Tete ; Epaule.G/D, Bras.G/D, AvantBras.G/D,
# Main.G/D ; Cuisse.G/D, Jambe.G/D, Pied.G/D (G : gauche du personnage, à +X dans Blender comme dans le jeu).
# Lancer dans Blender : exec(open(r"<dossier du jeu>/sources_blender/personnages/equiper_personnages.py").read())
# Variables : ORBMEKA_PERSOS=boy14 (seulement ceux-là), ORBMEKA_SANS_EXPORT=1 (ne rien écrire). Scène : OrbMeka_Perso.
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

GAME = os.environ.get("ORBMEKA_GAME", r"C:\Users\Dev\Desktop\Godot\orb-meka")
FOLDER = os.path.join(GAME, "assets", "characters")
SCENE = "OrbMeka_Perso"
HUMANS = ["boy9", "girl9", "boy14", "girl14"]


def import_character(name):
    scene = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    bpy.context.window.scene = scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(FOLDER, name + ".glb"))
    made = [o for o in bpy.data.objects if o not in before]
    mesh = [o for o in made if o.type == "MESH"][0]
    # Le modèle tel quel (sommets dans le repère du monde de Blender : z vers le haut, le visage vers -y), sans squelette.
    world = mesh.matrix_world.copy()
    mesh.parent = None
    mesh.data.transform(world)
    mesh.matrix_world = Matrix.Identity(4)
    for obj in made:
        if obj != mesh:
            bpy.data.objects.remove(obj, do_unlink=True)
    mesh.name = name
    for group in list(mesh.vertex_groups):
        mesh.vertex_groups.remove(group)
    for modifier in list(mesh.modifiers):
        mesh.modifiers.remove(modifier)
    return mesh


def islands(mesh, name):
    """Pièces du modèle (sommets reliés) : sommets, boîte, centre, matières (sans le préfixe du personnage)."""
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bm.verts.ensure_lookup_table()
    mats = mesh.data.materials
    seen = set()
    parts = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]
        seen.add(v.index)
        comp = []
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        kinds = set()
        for c in comp:
            for f in c.link_faces:
                kinds.add(mats[f.material_index].name.split(".")[0].replace(name + "_", ""))
        cos = [c.co.copy() for c in comp]
        low = Vector((min(p.x for p in cos), min(p.y for p in cos), min(p.z for p in cos)))
        high = Vector((max(p.x for p in cos), max(p.y for p in cos), max(p.z for p in cos)))
        parts.append({"verts": [c.index for c in comp], "low": low, "high": high, "center": (low + high) * 0.5, "kinds": kinds})
    bm.free()
    return parts


def classify(parts):
    """Rôle de chaque pièce : tete, tronc, bassin, manche, avantbras, main, jambe, pied ; son côté (1 gauche, -1 droit)."""
    shoes = [p for p in parts if "Chaussures" in p["kinds"] or "Semelle" in p["kinds"]]
    cx = (min(p["low"].x for p in shoes) + max(p["high"].x for p in shoes)) * 0.5
    top = max(p["high"].z for p in parts)
    head = max((p for p in parts if p["kinds"] == {"Skin"}), key=lambda p: p["high"].z)
    neck = head["low"].z
    for p in parts:
        off = p["center"].x - cx
        width = p["high"].x - p["low"].x
        p["side"] = 1 if off >= 0.0 else -1
        k = p["kinds"]
        if "Chaussures" in k or "Semelle" in k:
            p["role"] = "pied"
        elif p["low"].z >= neck - 0.02 or "Cheveux" in k or any(n.startswith("O_") for n in k):
            p["role"] = "tete"
        elif "Orbe" in k:
            p["role"] = "tronc"
        elif "Haut" in k and abs(off) > 0.09 and width < 0.2:
            p["role"] = "manche"
        elif "Haut" in k:
            p["role"] = "tronc"
        elif "Bas" in k and abs(off) > 0.05 and width < 0.2:
            p["role"] = "jambe"
        elif "Bas" in k:
            p["role"] = "bassin"
        elif k == {"Skin"} and p["low"].z < top * 0.15:
            # Jambes nues (short, robe) : la peau qui descend jusqu'aux chaussures.
            p["role"] = "jambe"
        elif k == {"Skin"} and abs(off) > 0.1:
            p["role"] = "brasnu"
        else:
            p["role"] = "tronc"
    # Bras nus : la pièce du bas (la main) et celle au-dessus (l'avant-bras), de chaque côté.
    for side in (1, -1):
        bare = sorted((p for p in parts if p["role"] == "brasnu" and p["side"] == side), key=lambda p: p["low"].z)
        for index, p in enumerate(bare):
            p["role"] = "main" if index == 0 else "avantbras"
    return cx, top, neck


def landmarks(parts, cx, top, neck):
    def side_parts(role, side):
        return [p for p in parts if p["role"] == role and p["side"] == side]
    marks = {"cx": cx, "top": top, "neck": neck, "arms": {}, "legs": {}}
    trunk = [p for p in parts if p["role"] == "tronc"]
    marks["shoulder_z"] = max(p["high"].z for p in trunk)
    for side in (1, -1):
        sleeves = side_parts("manche", side)
        fore = side_parts("avantbras", side)
        hands = side_parts("main", side)
        hand = hands[0] if hands else None
        shoulder_top = max(p["high"].z for p in sleeves) if sleeves else marks["shoulder_z"]
        upper_low = min(p["low"].z for p in sleeves) if sleeves else (shoulder_top + (hand["high"].z if hand else 0.0)) * 0.5
        x_sleeve = sum(p["center"].x for p in sleeves) / len(sleeves) if sleeves else cx + side * 0.2
        x_fore = sum(p["center"].x for p in fore) / len(fore) if fore else x_sleeve
        x_hand = hand["center"].x if hand else x_fore
        y_hand = hand["center"].y if hand else 0.0
        wrist_z = hand["high"].z - 0.008 if hand else upper_low - 0.15
        marks["arms"][side] = {
            "shoulder": Vector((x_sleeve, 0.0, shoulder_top - 0.045)),
            "elbow": Vector((x_fore, 0.0, upper_low + 0.025)),
            "wrist": Vector((x_hand, y_hand, wrist_z)),
            "tip": Vector((x_hand, y_hand, hand["low"].z if hand else wrist_z - 0.08)),
        }
        legs = side_parts("jambe", side)
        feet = side_parts("pied", side)
        hip_top = max(p["high"].z for p in legs) if legs else 0.45
        x_leg = sum((p["low"].x + p["high"].x) * 0.5 for p in legs) / len(legs) if legs else cx + side * 0.075
        ankle_z = max(p["high"].z for p in feet) + 0.03 if feet else 0.06
        toe_y = min(p["low"].y for p in feet) if feet else -0.1
        foot_low = min(p["low"].z for p in feet) if feet else 0.0
        marks["legs"][side] = {
            "hip": Vector((x_leg, 0.0, hip_top - 0.04)),
            "ankle": Vector((x_leg, 0.0, ankle_z)),
            "toe": Vector((x_leg, toe_y + 0.02, foot_low + 0.02)),
        }
    marks["hips"] = (marks["legs"][1]["hip"].z + marks["legs"][-1]["hip"].z) * 0.5 + 0.03
    return marks


def make_armature(name, marks):
    arm_data = bpy.data.armatures.new(name + "_os")
    rig = bpy.data.objects.new(name + "_squelette", arm_data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    bones = {}

    def bone(bname, head, tail, parent=None, connect=False):
        b = arm_data.edit_bones.new(bname)
        b.head = Vector(head)
        b.tail = Vector(tail)
        b.roll = 0.0
        if parent:
            b.parent = bones[parent]
            b.use_connect = connect
        bones[bname] = b

    cx = marks["cx"]
    hips = marks["hips"]
    chest = marks["shoulder_z"]
    bone("Bassin", (cx, 0, hips), (cx, 0, hips + (chest - hips) * 0.25))
    bone("Dos", (cx, 0, hips + (chest - hips) * 0.25), (cx, 0, hips + (chest - hips) * 0.6), "Bassin", True)
    bone("Poitrine", (cx, 0, hips + (chest - hips) * 0.6), (cx, 0, marks["neck"]), "Dos", True)
    bone("Cou", (cx, 0, marks["neck"]), (cx, 0, marks["neck"] + 0.05), "Poitrine", True)
    bone("Tete", (cx, 0, marks["neck"] + 0.05), (cx, 0, marks["top"]), "Cou", True)
    for side, tag in ((1, "G"), (-1, "D")):
        a = marks["arms"][side]
        bone("Epaule." + tag, (cx + side * 0.04, 0, a["shoulder"].z), a["shoulder"], "Poitrine")
        bone("Bras." + tag, a["shoulder"], a["elbow"], "Epaule." + tag, True)
        bone("AvantBras." + tag, a["elbow"], a["wrist"], "Bras." + tag, True)
        bone("Main." + tag, a["wrist"], a["tip"], "AvantBras." + tag, True)
        l = marks["legs"][side]
        knee = (l["hip"] + l["ankle"]) * 0.5 + Vector((0.0, -0.01, 0.0))
        bone("Cuisse." + tag, l["hip"], knee, "Bassin")
        bone("Jambe." + tag, knee, l["ankle"], "Cuisse." + tag, True)
        bone("Pied." + tag, l["ankle"], l["toe"], "Jambe." + tag, True)
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def weights(mesh, rig, parts, marks):
    groups = {b.name: mesh.vertex_groups.new(name=b.name) for b in rig.data.bones}
    verts = mesh.data.vertices
    hips = marks["hips"]
    chest = marks["shoulder_z"]

    def blend(index, z, low_bone, high_bone, middle, half):
        """Entre deux os selon la hauteur : tout à low_bone sous middle - half, tout à high_bone au-dessus de middle + half."""
        t = max(0.0, min(1.0, (z - (middle - half)) / (2.0 * half)))
        if t < 1.0:
            groups[low_bone].add([index], 1.0 - t, "REPLACE")
        if t > 0.0:
            groups[high_bone].add([index], t, "REPLACE")

    for p in parts:
        tag = "G" if p["side"] == 1 else "D"
        role = p["role"]
        for index in p["verts"]:
            z = verts[index].co.z
            if role == "tete":
                groups["Tete"].add([index], 1.0, "REPLACE")
            elif role == "pied":
                groups["Pied." + tag].add([index], 1.0, "REPLACE")
            elif role == "main":
                groups["Main." + tag].add([index], 1.0, "REPLACE")
            elif role == "avantbras":
                groups["AvantBras." + tag].add([index], 1.0, "REPLACE")
            elif role == "manche":
                blend(index, z, "Bras." + tag, "Epaule." + tag, marks["arms"][p["side"]]["shoulder"].z + 0.01, 0.025)
            elif role == "jambe":
                l = marks["legs"][p["side"]]
                knee = (l["hip"].z + l["ankle"].z) * 0.5
                if z > l["hip"].z + 0.02:
                    blend(index, z, "Cuisse." + tag, "Bassin", l["hip"].z + 0.04, 0.02)
                else:
                    blend(index, z, "Jambe." + tag, "Cuisse." + tag, knee, 0.035)
            elif role == "bassin":
                groups["Bassin"].add([index], 1.0, "REPLACE")
            else:
                # Tronc : bassin, dos, poitrine selon la hauteur.
                if z < hips + (chest - hips) * 0.25:
                    blend(index, z, "Bassin", "Dos", hips + (chest - hips) * 0.25, 0.03)
                else:
                    blend(index, z, "Dos", "Poitrine", hips + (chest - hips) * 0.6, 0.04)


def rig_character(name):
    mesh = import_character(name)
    parts = islands(mesh, name)
    cx, top, neck = classify(parts)
    marks = landmarks(parts, cx, top, neck)
    rig = make_armature(name, marks)
    weights(mesh, rig, parts, marks)
    mesh.parent = rig
    modifier = mesh.modifiers.new("Squelette", "ARMATURE")
    modifier.object = rig
    roles = {}
    for p in parts:
        roles[p["role"]] = roles.get(p["role"], 0) + 1
    print("PERSO", name, "pièces", roles, "épaules", round(marks["shoulder_z"], 3), "bassin", round(marks["hips"], 3), "cou", round(neck, 3))
    return mesh, rig


def export(name, mesh, rig):
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    mesh.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=os.path.join(FOLDER, name + ".glb"), use_selection=True, use_active_scene=True,
                              export_format="GLB", export_apply=False, export_yup=True, export_materials="EXPORT",
                              export_skins=True, export_animations=False)


def run(export_files=True):
    only = [n for n in os.environ.get("ORBMEKA_PERSOS", "").split(",") if n] or HUMANS
    results = {}
    for name in only:
        mesh, rig = rig_character(name)
        if export_files:
            export(name, mesh, rig)
        results[name] = (mesh, rig)
    return results


if os.environ.get("ORBMEKA_SANS_EXPORT") != "1":
    run()
