extends SceneTree
# 0.0.8.54 (lot C1, #224, #225, #230, demandes de l'utilisateur) : squelette des personnages humains et leurs gestes
# (character_rig.gd ; squelettes faits par sources_blender/personnages/equiper_personnages.py) :
# - les 4 personnages humains ont leurs 19 os ; les animaux (0.0.8.56) : corps et tête, ils se dandinent en marchant ;
# - objet tenu : l'avant-bras se lève ; geste « frapper » : le bras monte haut ; en marchant, les jambes se balancent ;
# - le joueur : le corps entier (vu de dos ou de face) tient l'objet choisi, ombre seule à la première personne.
const CharacterModel = preload("res://scripts/character_model.gd")
const CharacterRig = preload("res://scripts/character_rig.gd")
const Inventory = preload("res://scripts/inventory.gd")
const BONES := ["Bassin", "Dos", "Poitrine", "Cou", "Tete", "Epaule.G", "Bras.G", "AvantBras.G", "Main.G", "Epaule.D", "Bras.D", "AvantBras.D", "Main.D", "Cuisse.G", "Jambe.G", "Pied.G", "Cuisse.D", "Jambe.D", "Pied.D"]
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for index in range(count):
		await process_frame

# Angle (radians) entre la pose d'un os et sa pose de repos.
func bent(rig: RefCounted, bone_name: String) -> float:
	var bone: int = rig.skeleton.find_bone(bone_name)
	var rest: Quaternion = rig.skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	return rest.angle_to(rig.skeleton.get_bone_pose_rotation(bone))

func _run() -> void:
	for id in ["boy9", "girl9", "boy14", "girl14"]:
		var model := CharacterModel.build(id, "light")
		root.add_child(model)
		var rig: RefCounted = CharacterRig.new()
		var ready: bool = rig.setup(model)
		check(ready and BONES.all(func(name: String) -> bool: return rig.has_bone(name)), "%s: a skeleton with its 19 bones" % id)
		model.queue_free()
	# 0.0.8.56 (lot C2) : les animaux : un corps et une tête (la tortue : son corps seulement) ; en marchant, il se
	# dandine et sautille, la tête hoche.
	for id in ["fox", "rabbit", "squirrel", "cat", "turtle"]:
		var beast := CharacterModel.build(id, "")
		root.add_child(beast)
		var beast_rig: RefCounted = CharacterRig.new()
		var has_rig: bool = beast_rig.setup(beast)
		check(has_rig and beast_rig.animal and beast_rig.has_bone("Corps") and (id == "turtle" or beast_rig.has_bone("Tete")), "%s: an animal skeleton (body%s)" % [id, "" if id == "turtle" else ", head"])
		if id == "fox":
			var sways := []
			for step in range(30):
				beast_rig.update(0.05, 3.0)
				sways.append(bent(beast_rig, "Corps"))
			check(sways.max() > 0.08, "fox walking: it waddles (%.2f rad)" % sways.max())
		beast.queue_free()
	var boy := CharacterModel.build("boy14", "light")
	root.add_child(boy)
	var rig: RefCounted = CharacterRig.new()
	rig.setup(boy)
	rig.update(0.1, 0.0)
	var resting: float = bent(rig, "AvantBras.D")
	var item := Node3D.new()
	rig.hold("D", item)
	for step in range(10):
		rig.update(0.05, 0.0)
	check(rig.held_node("D") == item and bent(rig, "AvantBras.D") > resting + 0.5, "holding something: it is in the right hand, the forearm raised (%.2f rad)" % bent(rig, "AvantBras.D"))
	var holding_arm: float = bent(rig, "Bras.D")
	rig.play("dig")
	rig.update(0.15, 0.0)
	check(bent(rig, "Bras.D") > holding_arm + 1.0, "« dig » gesture: the arm goes up high (%.2f rad)" % bent(rig, "Bras.D"))
	for step in range(20):
		rig.update(0.05, 0.0)
	check(absf(bent(rig, "Bras.D") - holding_arm) < 0.05, "the gesture ends: back to holding")
	var legs := []
	for step in range(30):
		rig.update(0.05, 4.0)
		legs.append(bent(rig, "Cuisse.G"))
	check(legs.max() > 0.3 and legs.min() < 0.15, "walking: the legs swing (%.2f to %.2f rad)" % [legs.min(), legs.max()])
	boy.queue_free()
	# Le joueur : l'objet choisi dans la main du corps entier.
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(60)
	world.player.set_physics_process(false)
	world.player.body_key = ""
	world.player.character = "boy14"
	world.player.sync_body()
	check(world.player.shadow_rig != null and world.player.body_rig != null, "the player's body and its whole copy have their skeletons")
	world.inventory.set_mode(Inventory.CREATIVE)
	world.inventory._store().bar[0] = {"objet": "hache_pierre", "pile": [Inventory.CATALOG_MODELS.hache_pierre.duplicate()]}
	world.inventory.select(0)
	world.inventory.changed.emit()
	await frames(3)
	# 0.0.8.57 : l'objet choisi est dans la main gauche.
	var held: Node3D = world.player.shadow_rig.held_node("G")
	world.player.set_view("back")
	var seen: MeshInstance3D = world.player.shadow_rig.held_node("G")
	check(held != null and seen != null and seen.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and world.player.shadow_rig.held_node("D") == null, "seen from behind: the axe is in the character's left hand")
	world.player.set_view("first")
	var first: MeshInstance3D = world.player.shadow_rig.held_node("G")
	check(first != null and first.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and world.player.body_rig.held_node("G") == null, "first person: only its shadow (the game's hand holds it)")
	world.player.hand_view.dig()
	check(world.player.shadow_rig.gesture == "dig", "the hand's gesture is played by the body too")
	world.queue_free()
	await frames(2)
	print("RESULT: %d skeleton checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
