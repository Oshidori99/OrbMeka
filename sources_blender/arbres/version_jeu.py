# OrbMeka : version légère des arbres pour le jeu (09.11.2026). Les modèles détaillés restent dans le fichier Blender.
# Lancer dans Blender (runpy) : relance generer_arbres.py, puis construit pour chaque espèce
#   <Espèce>_Leger : branches à peu de facettes, feuillage en plaques croisées (image de grappe de feuilles), fruits simples ;
#   <Espèce>_Leger_Loin : tronc, grosses branches et quelques grandes plaques (40 à 150 m dans le jeu).
# Exporte assets/trees/<espece>_<taille>_jeu.glb et _loin.glb (tailles 1 à 5, sans images) et les images PNG à côté.
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

# 0.0.6.12 : grappe d'aiguilles de pin (touffes en éventail sur un rameau) et rameau de tilleul (feuilles en cœur, larges).
def needle_cluster(name,seed):
 n=512;rng=np.random.default_rng(seed)
 y,x=np.mgrid[0:n,0:n].astype(np.float32)/(n-1)
 rgba=np.zeros((n,n,4),np.float32)
 def segment(x0,y0,x1,y1,width,color):
  dx,dy=x1-x0,y1-y0;L2=dx*dx+dy*dy+1e-9
  t=np.clip(((x-x0)*dx+(y-y0)*dy)/L2,0,1);d=np.hypot(x-(x0+t*dx),y-(y0+t*dy))
  m=d<width*(1-.5*t)
  rgba[m,:3]=color;rgba[m,3]=1
 twigs=[(.5,.0,.5,.86),(.5,.30,.24,.62),(.5,.48,.78,.78),(.5,.18,.80,.40)]
 for x0,y0,x1,y1 in twigs:segment(x0,y0,x1,y1,.012,np.array([.42,.27,.16]))
 for x0,y0,x1,y1 in twigs:
  for k in range(7):
   t=.25+.75*k/6;cx,cy=x0+(x1-x0)*t,y0+(y1-y0)*t
   heading=math.atan2(y1-y0,x1-x0)
   for j in range(16):
    a=heading+rng.uniform(-1.3,1.3);L=rng.uniform(.07,.12)
    tone=rng.uniform(.75,1.15)
    segment(cx,cy,cx+math.cos(a)*L,cy+math.sin(a)*L,.0065,np.clip(np.array([.20,.36,.30])*tone,0,1))
 img=bpy.data.images.new(name,n,n,alpha=True);img.pixels.foreach_set(rgba.ravel())
 img.filepath_raw=str(OUT/(name+'.png'));img.file_format='PNG';img.save();bpy.data.images.remove(img)

def linden_cluster(name,seed):
 n=512;rng=np.random.default_rng(seed)
 y,x=np.mgrid[0:n,0:n].astype(np.float32)/(n-1)
 rgba=np.zeros((n,n,4),np.float32)
 twigs=[((.5,.0),(.5,.78)),((.5,.2),(.2,.55)),((.5,.38),(.82,.66)),((.5,.56),(.3,.86))]
 for (x0,y0),(x1,y1) in twigs:
  dx,dy=x1-x0,y1-y0;L2=dx*dx+dy*dy
  t=np.clip(((x-x0)*dx+(y-y0)*dy)/L2,0,1);d=np.hypot(x-(x0+t*dx),y-(y0+t*dy))
  m=d<(.010-.005*t);rgba[m,:3]=np.array([.33,.27,.20]);rgba[m,3]=1
 base=np.array([.24,.43,.12]);leaves=[]
 for (x0,y0),(x1,y1) in twigs:
  for k in range(6):
   t=rng.uniform(.2,1.0);ax,ay=x0+(x1-x0)*t,y0+(y1-y0)*t
   ang=math.atan2(y1-y0,x1-x0)+rng.choice([-1,1])*rng.uniform(.6,1.4)
   leaves.append((ax,ay,ang,rng.uniform(.17,.23),rng.uniform(.75,1.12)))
 rng.shuffle(leaves)
 for ax,ay,ang,L,tone in leaves:
  ux,uy=math.cos(ang),math.sin(ang)
  s=((x-ax)*ux+(y-ay)*uy)/L;w=(-(x-ax)*uy+(y-ay)*ux)/L
  sc=np.clip(s,0,1)
  # Feuille en cœur : base large et échancrée, pointe courte ; bord finement denté.
  prof=np.sin(np.pi*sc**.62)**.7*.47*(1+.04*np.sin(sc*60))
  prof=np.maximum(prof,.30*(1-sc)**3)
  inside=(s>.04*np.abs(w)/.3)&(s<1)&(np.abs(w)<prof)
  shade=(.82+.22*s-.30*np.abs(w))*tone
  col=base[None,None,:]*shade[:,:,None]
  col=np.where((np.abs(w)<.011)[:,:,None],col*1.22,col)
  rgba[inside,:3]=np.clip(col[inside],0,1);rgba[inside,3]=1
 img=bpy.data.images.new(name,n,n,alpha=True);img.pixels.foreach_set(rgba.ravel())
 img.filepath_raw=str(OUT/(name+'.png'));img.file_format='PNG';img.save();bpy.data.images.remove(img)

leaf_cluster('feuilles_pommier',False,11)
leaf_cluster('feuilles_noisetier',True,23)
needle_cluster('feuilles_pin',31)
linden_cluster('feuilles_tilleul',37)
for image,file in [('Ecorce_Pommier_256','ecorce_pommier'),('Ecorce_Noisetier_256','ecorce_noisetier'),('Ecorce_Pin_256','ecorce_pin'),('Ecorce_Tilleul_256','ecorce_tilleul')]:
 save_png(bpy.data.images[image],file)
col=bpy.data.collections.new('Version_Legere_Jeu');scene.collection.children.link(col)
report={}
# 0.0.6.11 : cinq tailles par espèce (1 petit … 3 standard … 5 grand). La taille 3 reprend le modèle détaillé
# construit ci-dessus ; les autres sont construites « en forme seulement » (generer_arbres.py, record_only).
# 0.0.6.12 : pin et tilleul. [nom, fichier, construction, case des plaques, feuilles mini par plaque, rangée dans l'atelier]
SPECIES=[('Pommier','pommier',lambda s,r,v=0:G['make_species'](False,s,r,v),.48,6,4),
 ('Noisetier','noisetier',lambda s,r,v=0:G['make_species'](True,s,r,v),.42,6,14),
 ('Pin','pin',G['make_pine'],.50,3,30),
 ('Tilleul','tilleul',G['make_linden'],.60,6,50)]
for name,file_name,build,cell,min_leaves,row in SPECIES:
 detail=bpy.data.objects[name+'_Detail'];mats=list(detail.data.materials)
 report[name]={}
 # 0.0.6.21 (#177) : trois formes par taille ; la forme 1 garde ses fichiers, les autres : <espece>_<taille>_f2 et _f3.
 for variant,size in [(v,s) for v in range(3) for s in range(1,6)]:
  src=geos[name] if (size==3 and variant==0) else build(size,True,variant)
  rng=random.Random(len(file_name)*13+size+variant*7919)
  form='' if variant==0 else '_f%d'%(variant+1)
  used=mats+[G['holeM']] if src.holes else mats
  near=Geo()
  wood(near,src,.02 if name!='Pommier' else .016,2,lambda r:7 if r>.1 else (5 if r>.035 else 4))
  for axis_at,out,up,r in src.holes:G['draw_hole'](near,axis_at,out,up,r,10)
  groups=cards(near,src,cell,min_leaves,1.25 if name=='Tilleul' else 1.0,rng)
  fruits=0
  if name=='Noisetier':
   # Une petite boule par grappe de noisettes (les noisettes d'une grappe sont à quelques cm).
   clusters=[]
   for pos,r in src.fruit_spots:
    if not any((pos-c).length<.09 for c in clusters):clusters.append(pos)
   limit=round(48*(.5+.25*size))
   for pos in clusters[:limit]:low_sphere(near,pos,.034,2,5,3,1.1)
   fruits=min(limit,len(clusters))
  elif name=='Pommier':
   # Les pommes du bord de la couronne (les autres sont cachées par le feuillage).
   limit=round(64*(.5+.25*size))
   spots=sorted(src.fruit_spots,key=lambda s:-Vector((s[0].x,s[0].y,0)).length-s[0].z*.25)[:limit]
   for pos,r in spots:low_sphere(near,pos,r*1.05,2,6,3)
   fruits=len(spots)
  elif name=='Pin':
   # Pommes de pin : petites, allongées, pendantes.
   for pos,r in src.fruit_spots[:40]:low_sphere(near,pos,.028,2,5,3,1.6)
   fruits=min(40,len(src.fruit_spots))
  far=Geo()
  wood(far,src,.05,3,lambda r:5 if r>.1 else 4)
  if name in ('Pommier','Noisetier'):cards(far,src,1.25,8 if size<3 else 20,1.05,rng)
  else:cards(far,src,1.9,6,1.1,rng)
  entry={}
  for g,suffix,file in [(near,'_Leger',f'{file_name}_{size}{form}_jeu'),(far,'_Leger_Loin',f'{file_name}_{size}{form}_loin')]:
   ob=g.object(f'{name}_T{size}{form}{suffix}',used if g is near else mats,col)
   entry[file]=sum(len(p.vertices)-2 for p in ob.data.polygons)
   bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
   bpy.ops.export_scene.gltf(filepath=str(OUT/(file+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_image_format='NONE',export_animations=False,export_cameras=False,export_lights=False)
   # Rangés dans l'atelier : une rangée par espèce, tailles de gauche à droite ; version de loin derrière.
   ob.location=((size-3)*14.0+variant*80.0,row+(8 if suffix=='_Leger_Loin' else 0),0)
   ob.hide_render=True
   if suffix=='_Leger':entry['hauteur_m']=round(ob.dimensions.z,2)
  entry['plaques']=groups;entry['fruits']=fruits
  report[name][f'{size}{form}']=entry
  print(name,size,form,entry)
scene['version_jeu']=json.dumps(report)
(HERE/'mesures_jeu.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.wm.save_mainfile()
print('VERSION_JEU_OK')
