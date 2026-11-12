# OrbMeka : plantes à fibres et lianes (0.0.6.16, #182), modélisées dans Blender puis rendues en images pour le jeu.
# Ortie (Urtica dioica) : tiges droites, feuilles opposées en cœur allongé, dentées, chatons verts pendants.
# Lin (Linum usitatissimum) : tiges fines, feuilles étroites, fleurs bleu ciel à cinq pétales en haut.
# Herbes longues : touffe de longues feuilles arquées et d'épis plumeux beiges.
# Liane fine : tige en zigzag et petites feuilles en cœur (bande verticale qui se répète, enroulée sur les troncs).
# Chaque plante est rendue de face sur fond transparent : assets/plants/<nom>.png (plaques croisées dans le jeu).
# Le fichier Blender est rangé dans ../Archives OrbMeka/Blender/plantes.blend (hors du dépôt).
import bpy, math, random
from mathutils import Vector
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/'assets'/'plants';OUT.mkdir(parents=True,exist_ok=True)
BLEND=ROOT.parent/'Archives OrbMeka'/'Blender'/'plantes.blend'

old=bpy.data.scenes.get('OrbMeka_Plantes_Atelier')
if old:
 for ob in list(old.objects):bpy.data.objects.remove(ob,do_unlink=True)
 bpy.data.scenes.remove(old)
scene=bpy.data.scenes.new('OrbMeka_Plantes_Atelier');bpy.context.window.scene=scene
scene.render.engine='BLENDER_EEVEE';scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
if hasattr(scene,'eevee') and hasattr(scene.eevee,'taa_render_samples'):scene.eevee.taa_render_samples=32
scene.world=bpy.data.worlds.new('Plantes_Ciel');scene.world.use_nodes=True
bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.75,.8,.85,1);bg.inputs['Strength'].default_value=.9
sun=bpy.data.lights.new('Soleil','SUN');sun.energy=3.0;sun.angle=.3
sun_ob=bpy.data.objects.new('Soleil',sun);scene.collection.objects.link(sun_ob);sun_ob.rotation_euler=(.7,-.3,.4)

def mat(name,color,rough=.8):
 m=bpy.data.materials.new(name);m.use_nodes=True
 bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough
 if 'Subsurface Weight' in bs.inputs and color[1]>color[0]:bs.inputs['Subsurface Weight'].default_value=.15
 m.use_backface_culling=False
 return m
STEM=mat('Tige',(.10,.20,.05));NETTLE=mat('Feuille_Ortie',(.05,.17,.03));CATKIN=mat('Chaton_Ortie',(.18,.24,.08))
FLAX=mat('Feuille_Lin',(.13,.26,.09));FLAX_FLOWER=mat('Fleur_Lin',(.18,.38,.85),.6);FLAX_HEART=mat('Coeur_Lin',(.85,.75,.25))
GRASS=mat('Herbe_Longue',(.17,.30,.07));SEED=mat('Epi',(.55,.47,.30));VINE=mat('Liane',(.07,.19,.04));VINE_STEM=mat('Tige_Liane',(.18,.14,.08))

class Mesh:
 def __init__(self):self.v=[];self.f=[];self.m=[]
 def add(self,verts,faces,mi):
  k=len(self.v);self.v+= [tuple(v) for v in verts];self.f+=[tuple(i+k for i in face) for face in faces];self.m+=[mi]*len(faces)
 def tube(self,pts,r0,r1,mi,sides=5):
  for j in range(len(pts)-1):
   a,b=pts[j],pts[j+1];axis=(b-a).normalized();s=axis.cross(Vector((0,1,0)))
   if s.length<.01:s=axis.cross(Vector((1,0,0)))
   s.normalize();u=axis.cross(s)
   ra=r0+(r1-r0)*j/(len(pts)-1);rb=r0+(r1-r0)*(j+1)/(len(pts)-1)
   ring=lambda p,r:[p+(s*math.cos(i*math.tau/sides)+u*math.sin(i*math.tau/sides))*r for i in range(sides)]
   verts=ring(a,ra)+ring(b,rb)
   self.add(verts,[(i,(i+1)%sides,sides+(i+1)%sides,sides+i) for i in range(sides)],mi)
 # Feuille plate : base au point, direction d (axe), largeur relative w, forme en cœur (cordate) ou étroite, dentée.
 def leaf(self,base,d,length,w,mi,rng,cordate=False,teeth=0.0,droop=.25,plane=None):
  axis=Vector(d).normalized();side=axis.cross(Vector(plane) if plane else Vector((0,0,1)))
  if side.length<.01:side=Vector((1,0,0))
  side.normalize();up=side.cross(axis).normalized()
  n=8;left=[];right=[];mid=[]
  for j in range(n+1):
   t=j/n
   prof=math.sin(math.pi*t**(.7 if cordate else .9))**.8
   if cordate:prof=max(prof,.45*(1-t)**3)
   tooth=1+teeth*(1 if j%2 else -1)
   bend=-droop*length*t*t
   c=base+axis*(t*length)+Vector((0,0,bend))
   left.append(c+side*w*length*prof*tooth*.5);right.append(c-side*w*length*prof*tooth*.5);mid.append(c+up*length*.03*math.sin(math.pi*t))
  verts=left+mid+right;faces=[]
  for j in range(n):
   faces.append((j,j+1,n+1+j+1,n+1+j));faces.append((n+1+j,n+1+j+1,2*(n+1)+j+1,2*(n+1)+j))
  self.add(verts,faces,mi)
 def ball(self,c,r,mi,sides=6,rings=4,stretch=1.0):
  verts=[c+Vector((r*math.sin(math.pi*j/rings)*math.cos(math.tau*i/sides),r*math.sin(math.pi*j/rings)*math.sin(math.tau*i/sides),r*math.cos(math.pi*j/rings)*stretch)) for j in range(rings+1) for i in range(sides)]
  self.add(verts,[(j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i) for j in range(rings) for i in range(sides)],mi)
 def obj(self,name,mats):
  me=bpy.data.meshes.new(name);me.from_pydata(self.v,[],self.f);me.update()
  for m in mats:me.materials.append(m)
  for p,mi in zip(me.polygons,self.m):p.material_index=mi;p.use_smooth=True
  ob=bpy.data.objects.new(name,me);scene.collection.objects.link(ob);return ob

def curve(base,height,lean,rng,steps=10):
 a=rng.random()*math.tau;bend=Vector((math.cos(a),math.sin(a),0))*lean
 return [base+bend*(j/steps)**2+Vector((0,0,height*j/steps)) for j in range(steps+1)]

def nettle(rng):
 g=Mesh()
 for s in range(7):
  a=rng.random()*math.tau;foot=Vector((math.cos(a),math.sin(a),0))*rng.uniform(0,.12)
  h=rng.uniform(.7,1.05);pts=curve(foot,h,rng.uniform(.03,.10),rng)
  g.tube(pts,.0045,.0025,0)
  turn=rng.random()*math.pi
  for k in range(int(h/.08)):
   t=.12+k*.08/h
   if t>.98:break
   at=pts[0].lerp(pts[-1],t)+(pts[min(10,int(t*10)+1)]-pts[0].lerp(pts[-1],t))*0
   size=.13*(1-.5*t)+.04
   for side in (0,math.pi):
    ang=turn+side+k*math.pi/2
    g.leaf(at,(math.cos(ang),math.sin(ang),-.15),size,.55,1,rng,cordate=True,teeth=.10,droop=.35)
   if t>.45 and rng.random()<.7:
    for side in (0,math.pi):
     ang=turn+side+k*math.pi/2+.6
     g.tube([at,at+Vector((math.cos(ang)*.05,math.sin(ang)*.05,-.07))],.0025,.0015,2,4)
 return g.obj('Ortie',[STEM,NETTLE,CATKIN])

def flax(rng):
 g=Mesh()
 for s in range(11):
  a=rng.random()*math.tau;foot=Vector((math.cos(a),math.sin(a),0))*rng.uniform(0,.08)
  h=rng.uniform(.5,.72);pts=curve(foot,h,rng.uniform(.02,.08),rng)
  g.tube(pts,.0025,.0018,0,4)
  for k in range(int(h/.035)):
   t=.08+k*.035/h
   if t>.82:break
   at=pts[0].lerp(pts[-1],t);ang=rng.random()*math.tau
   g.leaf(at,(math.cos(ang),math.sin(ang),.9),.025,.18,1,rng,droop=.05)
  for b in range(rng.randint(2,4)):
   ang=rng.random()*math.tau;top=pts[-1]+Vector((math.cos(ang)*.04,math.sin(ang)*.04,rng.uniform(.0,.05)))
   g.tube([pts[-1],top],.0018,.0015,0,4)
   if rng.random()<.9:
    for p in range(5):
     pa=p*math.tau/5+rng.random()*.3
     g.leaf(top,(math.cos(pa),math.sin(pa),.55),.026,.9,2,rng,droop=.0)
    g.ball(top+Vector((0,0,.005)),.005,3,5,3)
   else:
    g.ball(top,.004,1,5,3,1.3)
 return g.obj('Lin',[STEM,FLAX,FLAX_FLOWER,FLAX_HEART])

def tall_grass(rng):
 g=Mesh()
 for s in range(30):
  a=rng.random()*math.tau;foot=Vector((math.cos(a),math.sin(a),0))*rng.uniform(0,.10)
  L=rng.uniform(.45,.9);d=Vector((math.cos(a)*rng.uniform(.15,.5),math.sin(a)*rng.uniform(.15,.5),1)).normalized()
  g.leaf(foot,d,L,.035,0,rng,droop=rng.uniform(.25,.6))
 for s in range(8):
  a=rng.random()*math.tau;foot=Vector((math.cos(a),math.sin(a),0))*rng.uniform(0,.08)
  h=rng.uniform(.95,1.25);pts=curve(foot,h,rng.uniform(.05,.18),rng)
  g.tube(pts,.003,.0015,0,4)
  for k in range(14):
   t=.72+k*.02;at=pts[0].lerp(pts[-1],t);ang=rng.random()*math.tau
   g.ball(at+Vector((math.cos(ang)*.012,math.sin(ang)*.012,0)),.006,1,5,3,2.2)
 return g.obj('Herbe_Longue',[GRASS,SEED])

def vine(rng):
 g=Mesh();h=1.0;pts=[]
 for j in range(13):
  pts.append(Vector((math.sin(j*1.3)*.03,0,h*j/12)))
 g.tube(pts,.004,.004,1,4)
 for j in range(1,12):
  at=pts[j];side=1 if j%2 else -1
  g.leaf(at,(side*.8,0,.45),rng.uniform(.05,.07),.85,0,rng,cordate=True,droop=.12,plane=(0,1,0))
  if rng.random()<.6:g.leaf(at,(side*.3,0,.9),.04,.8,0,rng,cordate=True,droop=.08,plane=(0,1,0))
 return g.obj('Liane',[VINE,VINE_STEM])

def render(ob,name,width,height,pixels=(512,512),view=Vector((0,-1,.35))):
 for other in scene.objects:
  if other.type=='MESH':other.hide_render=other!=ob
 cam_data=bpy.data.cameras.get('Camera_Plantes') or bpy.data.cameras.new('Camera_Plantes')
 cam=bpy.data.objects.get('Camera_Plantes')
 if cam is None:cam=bpy.data.objects.new('Camera_Plantes',cam_data);scene.collection.objects.link(cam)
 cam_data.type='ORTHO';cam_data.ortho_scale=max(width,height)
 target=ob.location+Vector((0,0,height/2))
 cam.location=target-view.normalized()*8;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.camera=cam;scene.render.resolution_x,scene.render.resolution_y=pixels;scene.render.resolution_percentage=100
 scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)

rng=random.Random(1601)
plants=[(nettle(rng),'ortie',1.1,1.1),(flax(rng),'lin',.8,.8),(tall_grass(rng),'herbe_longue',1.3,1.3)]
for i,(ob,name,w,h) in enumerate(plants):
 ob.location.x=i*2.0
 render(ob,name,w,h)
v=vine(rng);v.location.x=8
render(v,'liane',.25,1.0,(128,512),Vector((0,-1,0)))
for ob in scene.objects:
 if ob.type=='MESH':ob.hide_render=False
BLEND.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
print('PLANTES_OK',[ (o.name,len(o.data.polygons)) for o in scene.objects if o.type=='MESH'])
