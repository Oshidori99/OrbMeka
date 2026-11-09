import bpy, math
from mathutils import Vector
from pathlib import Path
scene=bpy.context.scene
scene.world.use_nodes=True
bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND')
bg.inputs['Color'].default_value=(0.40,.49,.62,1);bg.inputs['Strength'].default_value=.6
col=bpy.data.collections.new('Atelier_Presentation');scene.collection.children.link(col)
mesh=bpy.data.meshes.new('Sol_Atelier');mesh.from_pydata([(-200,-200,-.04),(200,-200,-.04),(200,200,-.04),(-200,200,-.04)],[],[(0,1,2,3)])
ground=bpy.data.objects.new('Sol_Atelier',mesh);col.objects.link(ground)
m=bpy.data.materials.new('Sol_Neutre');m.diffuse_color=(.18,.21,.16,1);ground.data.materials.append(m)
for name,loc,power,size in [('Lumiere_Principale',(0,-7,11),1800,8),('Lumiere_Contour',(2,5,8),2200,6)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
 ob=bpy.data.objects.new(name,d);col.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector((0,0,2))-ob.location).to_track_quat('-Z','Y').to_euler()
sun=bpy.data.lights.new('Soleil','SUN');sun.energy=2.0;sun.angle=.15
ob=bpy.data.objects.new('Soleil',sun);col.objects.link(ob);ob.rotation_euler=(.5,-.5,-.4)
d=bpy.data.cameras.new('Camera_Atelier');cam=bpy.data.objects.new('Camera_Atelier',d);col.objects.link(cam)
cam.location=(9,-16,7.3);cam.rotation_euler=(Vector((0,0,2.2))-cam.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=13
scene.camera=cam
scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
if hasattr(scene,'eevee') and hasattr(scene.eevee,'taa_render_samples'):scene.eevee.taa_render_samples=24
scene.render.image_settings.file_format='PNG';scene.render.filepath=r'C:\Users\Dev\Desktop\Godot\orb-meka\sources_blender\arbres\apercu_ensemble.png'
bpy.ops.wm.save_as_mainfile(filepath=r'C:\Users\Dev\Desktop\Godot\orb-meka\sources_blender\arbres\arbres_detail.blend')
bpy.ops.render.render(write_still=True)
print('PREVIEW_READY')
