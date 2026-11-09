# OrbMeka : version légère des arbres pour le jeu (09.11.2026). Les modèles détaillés restent dans le fichier Blender.
# Lancer dans Blender (runpy) : relance generer_arbres.py, puis construit pour chaque espèce
#   <Espèce>_Leger : branches à peu de facettes, feuillage en plaques croisées (image de grappe de feuilles), fruits simples ;
#   <Espèce>_Leger_Loin : tronc, grosses branches et quelques grandes plaques (40 à 150 m dans le jeu).
# Exporte assets/trees/<espece>_jeu.glb et <espece>_loin.glb (sans images) et les images PNG à côté.
import bpy, runpy, math, random, json
import numpy as np
from mathutils import Vector
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/'assets'/'trees';OUT.mkdir(exist_ok=True)
G=runpy.run_path(str(HERE/'generer_arbres.py'),run_name='__main__')
Geo=G['Geo'];geos=G['geos'];scene=bpy.context.scene

def save_png(img,name):
 copy=img.copy();copy.filepath_raw=str(OUT/(name+'.png'));copy.file_format='PNG';copy.save();bpy.data.images.remove(copy)

# Image d'une grappe de feuilles sur un rameau (fond transparent), originale, dessinée en code.
def leaf_cluster(name,hazel,seed):
 n=512;rng=np.random.default_rng(seed)
 y,x=np.mgrid[0:n,0:n].astype(np.float32)/(n-1)
 rgba=np.zeros((n,n,4),np.float32)
 twig=np.array([.36,.27,.17] if hazel else [.30,.21,.14])
 # Rameau principal du bas vers le haut, trois rameaux latéraux.
 twigs=[((.5,.0),(.52,.80))]
 for k,(t,side) in enumerate([(.25,-1),(.42,1),(.60,-1)]):
  start=(.5+.02*t,.8*t);twigs.append((start,(start[0]+side*.28,start[1]+.22)))
 for (x0,y0),(x1,y1) in twigs:
  dx,dy=x1-x0,y1-y0;L2=dx*dx+dy*dy
  t=np.clip(((x-x0)*dx+(y-y0)*dy)/L2,0,1);d=np.hypot(x-(x0+t*dx),y-(y0+t*dy))
  m=d<(.010-.005*t)
  rgba[m,:3]=twig;rgba[m,3]=1
 base=np.array([.36,.56,.17] if hazel else [.22,.44,.12])
 leaves=[]
 for (x0,y0),(x1,y1) in twigs:
  for k in range(7 if hazel else 9):
   t=rng.uniform(.15,1.0);ax,ay=x0+(x1-x0)*t,y0+(y1-y0)*t
   ang=math.atan2(y1-y0,x1-x0)+rng.choice([-1,1])*rng.uniform(.5,1.3)
   leaves.append((ax,ay,ang,rng.uniform(.17,.24) if hazel else rng.uniform(.15,.22),rng.uniform(.72,1.12)))
 rng.shuffle(leaves)
 for ax,ay,ang,L,tone in leaves:
  ux,uy=math.cos(ang),math.sin(ang)
  s=((x-ax)*ux+(y-ay)*uy)/L;w=(-(x-ax)*uy+(y-ay)*ux)/L
  prof=np.sin(np.pi*np.clip(s,0,1)**(.76 if hazel else .9))**.75*(.40 if hazel else .27)
  if hazel:prof=np.maximum(prof,.13*(1-np.clip(s,0,1))**5)
  inside=(s>0)&(s<1)&(np.abs(w)<prof)
  shade=(.80+.25*s-.35*np.abs(w))*tone
  col=base[None,None,:]*shade[:,:,None]
  rib=np.abs(w)<.012
  col=np.where(rib[:,:,None],col*1.25,col)
  rgba[inside,:3]=np.clip(col[inside],0,1);rgba[inside,3]=1
 img=bpy.data.images.new(name,n,n,alpha=True);img.pixels.foreach_set(rgba.ravel())
 img.filepath_raw=str(OUT/(name+'.png'));img.file_format='PNG';img.save();bpy.data.images.remove(img)

def low_sphere(g,pos,radius,mat,sides=5,rings=3,stretch=1.0):
 k0=len(g.v)
 for j in range(rings+1):
  th=math.pi*j/rings
  for i in range(sides):
   a=math.tau*i/sides+(.5*j)
   g.verts([pos+Vector((math.cos(a)*radius*math.sin(th),math.sin(a)*radius*math.sin(th),radius*math.cos(th)*stretch))],[(i/sides,j/rings)])
 for j in range(rings):
  for i in range(sides):g.face((k0+j*sides+i,k0+(j+1)*sides+i,k0+(j+1)*sides+(i+1)%sides,k0+j*sides+(i+1)%sides),mat)

def wood(g,source,min_radius,step,sides_for):
 for pts,radii in source.paths:
  if max(radii)<min_radius:continue
  idx=list(range(0,len(pts),step))
  if idx[-1]!=len(pts)-1:idx.append(len(pts)-1)
  g.tube([pts[i] for i in idx],[radii[i] for i in idx],sides_for(max(radii)),0)

# Plaques de feuillage : les feuilles du modèle détaillé regroupées par case ; chaque groupe devient trois plaques
# croisées (deux debout, une presque à plat pour la vue d'en haut), de la taille du groupe.
def cards(g,source,cell,min_leaves,grow,rng):
 cells={}
 for p in source.leaf_centers:cells.setdefault(tuple(math.floor(v/cell) for v in p),[]).append(p)
 count=0
 for pts in cells.values():
  if len(pts)<min_leaves:continue
  c=sum(pts,Vector())/len(pts)
  size=min(cell*2.3,max(cell*1.25,max((p-c).length for p in pts)*2.1))*grow
  yaw=rng.uniform(0,math.pi)
  for k,(u,v) in enumerate([(Vector((math.cos(yaw),math.sin(yaw),0)),Vector((0,0,1))),(Vector((-math.sin(yaw),math.cos(yaw),0)),Vector((0,0,1))),(Vector((math.cos(yaw+.8),math.sin(yaw+.8),0)),Vector((-math.sin(yaw+.8),math.cos(yaw+.8),0)).lerp(Vector((0,0,1)),.25).normalized())]):
   h=size*.5
   ids=g.verts([c-u*h-v*h,c+u*h-v*h,c+u*h+v*h,c-u*h+v*h],[(0,0),(1,0),(1,1),(0,1)])
   g.face((ids,ids+1,ids+2,ids+3),1)
  count+=1
 return count

leaf_cluster('feuilles_pommier',False,11)
leaf_cluster('feuilles_noisetier',True,23)
save_png(bpy.data.images['Ecorce_Pommier_256'],'ecorce_pommier')
save_png(bpy.data.images['Ecorce_Noisetier_256'],'ecorce_noisetier')
col=bpy.data.collections.new('Version_Legere_Jeu');scene.collection.children.link(col)
report={}
for name,hazel in [('Pommier',False),('Noisetier',True)]:
 src=geos[name];rng=random.Random(91 if hazel else 47)
 detail=bpy.data.objects[name+'_Detail'];mats=list(detail.data.materials)
 near=Geo()
 wood(near,src,.02 if hazel else .016,2,lambda r:7 if r>.1 else (5 if r>.035 else 4))
 groups=cards(near,src,.42 if hazel else .48,6,1.0,rng)
 if hazel:
  # Une petite boule par grappe de noisettes (les noisettes d'une grappe sont à quelques cm).
  clusters=[]
  for pos,r in src.fruit_spots:
   if not any((pos-c).length<.09 for c in clusters):clusters.append(pos)
  for pos in clusters[:48]:low_sphere(near,pos,.034,2,5,3,1.1)
  fruits=min(48,len(clusters))
 else:
  # Les pommes du bord de la couronne (les autres sont cachées par le feuillage).
  axis=Vector((0,0,0))
  spots=sorted(src.fruit_spots,key=lambda s:-(Vector((s[0].x,s[0].y,0))-axis).length-s[0].z*.25)[:64]
  for pos,r in spots:low_sphere(near,pos,r*1.05,2,6,3)
  fruits=len(spots)
 far=Geo()
 wood(far,src,.05,3,lambda r:5 if r>.1 else 4)
 cards(far,src,1.25,20,1.05,rng)
 report[name]={}
 for g,suffix,file in [(near,'_Leger',name.lower()+'_jeu'),(far,'_Leger_Loin',name.lower()+'_loin')]:
  ob=g.object(name+suffix,mats,col)
  report[name][file]=sum(len(p.vertices)-2 for p in ob.data.polygons)
  bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
  bpy.ops.export_scene.gltf(filepath=str(OUT/(file+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_image_format='NONE',export_animations=False,export_cameras=False,export_lights=False)
  ob.location.x=detail.location.x+(0 if suffix=='_Leger' else 0);ob.location.y=7.5 if suffix=='_Leger' else 15
  ob.hide_render=True
 report[name]['plaques']=groups;report[name]['fruits']=fruits
 print(name,report[name])
scene['version_jeu']=json.dumps(report)
(HERE/'mesures_jeu.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.wm.save_mainfile()
print('VERSION_JEU_OK')
