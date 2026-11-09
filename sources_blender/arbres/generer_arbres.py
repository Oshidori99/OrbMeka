# OrbMeka original assets, authored in Blender through MCP. One fixed model per species.
import bpy, math, random, json
from mathutils import Vector
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'sources_blender'/'arbres'
ASSETS=ROOT/'assets'/'trees'
# 09.11.2026 : les fichiers .blend sont rangés hors du dépôt, dans ..Archives OrbMekaBlender (demande de l'utilisateur).
BLEND=ROOT.parent/'Archives OrbMeka'/'Blender'/'arbres_detail.blend'
BLEND.parent.mkdir(parents=True,exist_ok=True)
ASSETS.mkdir(exist_ok=True)
old=bpy.data.scenes.get('OrbMeka_Arbres_Atelier')
if old:
 bpy.context.window.scene=bpy.data.scenes['Scene']
 for ob in list(old.objects):
  data=ob.data;bpy.data.objects.remove(ob,do_unlink=True)
  if isinstance(data,bpy.types.Mesh) and data.users==0:bpy.data.meshes.remove(data)
 bpy.data.scenes.remove(old)
scene=bpy.data.scenes.new('OrbMeka_Arbres_Atelier')
bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1.0
scene.render.engine='BLENDER_EEVEE'
scene.render.threads_mode='FIXED'
scene.render.threads=2
scene.world=bpy.data.worlds.new('Atelier_Ciel')
scene.world.color=(0.2,0.2,0.2)
scene.view_settings.view_transform='AgX'

# Shared 256px original textures: veins and bark pores, no downloaded assets, no alpha overdraw.
def texture(name,hazel=False,bark=False):
 n=256
 y,x=np.mgrid[0:n,0:n].astype(float);u=x/(n-1);v=y/(n-1)
 if bark:
  lines=(np.sin(u*130+np.sin(v*14)*0.8)+np.sin(u*301+np.sin(v*37)*1.3))*0.04
  grain=np.sin(x*1.74+y*5.37)*np.sin(x*4.21-y*2.18)*0.025
  cracks=np.maximum(0,np.sin(u*183+np.sin(v*29)*.9)-.72)*.45
  shade=0.78+lines*1.8+grain-cracks
  if hazel:
   pores=(np.sin(v*215+np.sin(u*91)*0.4)>0.97)&(np.sin(u*73)>0.2)
   shade=shade+pores*0.25
  base=np.array([0.31,0.245,0.16] if hazel else [0.24,0.185,0.12])
  rgb=shade[:,:,None]*base
 else:
  # UV (0.5,0) at petiole, (0.5,1) at tip. Secondary veins angle toward apex.
  dx=abs(u-0.5)
  mid=np.exp(-((u-0.5)/0.012)**2)
  ribs=np.exp(-(np.sin((v-dx*0.65)*math.pi*12)/0.16)**2)*(1-dx*1.3)
  fine=np.sin(u*310+v*81)*np.sin(v*417-u*53)*0.014
  shade=0.80+0.16*v-0.13*dx+fine
  base=np.array([0.25,0.43,0.075] if hazel else [0.16,0.335,0.065])
  rgb=shade[:,:,None]*base+(mid+ribs*0.38)[:,:,None]*np.array([0.055,0.060,0.009])
 rgba=np.ones((n,n,4),dtype=np.float32);rgba[:,:,:3]=np.clip(rgb,0,1)
 img=bpy.data.images.new(name,width=n,height=n)
 img.pixels.foreach_set(rgba.ravel());img.pack()
 return img

def mat(name,base,rough=0.75,img=None,double=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*base,1);m.use_nodes=True
 bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 bs.inputs['Base Color'].default_value=(*base,1);bs.inputs['Roughness'].default_value=rough
 if 'Coat Weight' in bs.inputs: bs.inputs['Coat Weight'].default_value=0.15 if rough<0.5 else 0
 if img:
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
  m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
  # Fine relief in Blender; export remains a lightweight base-color texture.
  bump=m.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=0.18
  bump.inputs['Distance'].default_value=0.0015
  m.node_tree.links.new(tex.outputs['Color'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
 m.use_backface_culling=not double
 return m
barkA=mat('Pommier_Ecorce',(.24,.18,.12),img=texture('Ecorce_Pommier_256',bark=True))
barkH=mat('Noisetier_Ecorce_Lenticelles',(.31,.24,.16),img=texture('Ecorce_Noisetier_256',hazel=True,bark=True))
leafA=mat('Pommier_Feuille_Ovale_Nervuree',(.16,.335,.065),img=texture('Feuille_Pommier_256'),double=True)
leafH=mat('Noisetier_Feuille_Cordiforme_Nervuree',(.25,.43,.075),img=texture('Feuille_Noisetier_256',hazel=True),double=True)
fruitA=mat('Pomme_Rouge_Doree',(.42,.045,.014),0.48)
fruitH=mat('Noisette_Coque_Mure',(.42,.23,.08),0.5)

class Geo:
 # record_only : on note seulement la forme (branches, feuilles, fruits) sans construire les sommets, pour la version légère
 # des tailles 1, 2, 4 et 5 (bien plus rapide et sans des millions de triangles en mémoire). Même tirage au hasard.
 def __init__(self,record_only=False): self.record_only=record_only;self.v=[];self.f=[];self.uv=[];self.mi=[];self.col=[];self.leaves=0;self.paths=[];self.leaf_centers=[];self.blades=[];self.fruit_spots=[]
 def verts(self,vs,uv=None,col=(1,1,1,1)):
  k=len(self.v);self.v.extend([tuple(v) for v in vs]);self.uv.extend(uv or [(0,0)]*len(vs));self.col.extend([col]*len(vs));return k
 def face(self,ids,mat): self.f.append(tuple(ids));self.mi.append(mat)
 def tube(self,points,radii,sides=7,mat=0):
  if mat==0 and max(radii)>=.018 and len(points)>2:self.paths.append((points[:],radii[:]))
  if self.record_only:return
  for j,p in enumerate(points):
   tangent=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized()
   a=tangent.cross(Vector((0,1,0)))
   if a.length<0.01:a=tangent.cross(Vector((1,0,0)))
   a.normalize();b=tangent.cross(a)
   ring=[p+(a*math.cos(i*math.tau/sides)+b*math.sin(i*math.tau/sides))*radii[j]*(1+0.055*math.sin(i*5+j*0.7)) for i in range(sides+1)]
   k=self.verts(ring,[(i/sides,j/max(1,len(points)-1)*2) for i in range(sides+1)])
   if j:
    for i in range(sides):self.face((k-sides-1+i,k-sides+i,k+i+1,k+i),mat)
  self.face(tuple(range(k,k+sides)),mat)
 def leaf(self,base,direction,length,rng,hazel=False,low=False):
  axis=Vector(direction).normalized();side=axis.cross(Vector((0,0,1)))
  if side.length<0.01:side=Vector((1,0,0))
  side.normalize();side=side*math.cos(rng.uniform(-0.8,0.8))+axis.cross(side)*math.sin(rng.uniform(-0.8,0.8));side.normalize()
  normal=side.cross(axis).normalized();w=length*(0.43 if hazel else 0.28)
  if self.record_only:
   for k in range(3):rng.uniform(.78,1)
   self.leaves+=1
   if length>.07:self.leaf_centers.append(base+axis*(length*.5))
   return
  # Blades: folded midrib, tapered tip, cordate base for hazel, serrated sides.
  n=4 if low else 6
  vs=[];uv=[]
  for j in range(n+1):
   t=j/n
   profile=math.sin(math.pi*(t**(0.76 if hazel else 0.9)))**0.75
   if hazel:profile=max(profile,0.34*(1-t)**5)
   serr=1+(0.085 if hazel else 0.045)*(1 if j%2 else -1)
   for s in (-1,0,1):
    offset=s*w*profile*serr
    pos=base+axis*(t*length)+side*offset+normal*(length*.045*math.sin(math.pi*t)-abs(s)*length*0.025*profile)
    vs.append(pos);uv.append((.5+offset/(w*2.2),t))
  color=(rng.uniform(.78,1),rng.uniform(.86,1),rng.uniform(.78,1),1)
  self.blades.append((vs[:],uv[:]))
  k=self.verts(vs,uv,color)
  for j in range(n):
   for s in range(2):self.face((k+j*3+s,k+j*3+s+1,k+(j+1)*3+s+1,k+(j+1)*3+s),1)
  self.leaves+=1
  if length>.07:self.leaf_centers.append(base+axis*(length*.5))
 def fruit(self,pos,radius,rng,hazel=False):
  self.fruit_spots.append((pos.copy(),radius))
  if self.record_only:return
  rings=6 if hazel else 9;sides=8 if hazel else 12;k0=len(self.v)
  for j in range(rings+1):
   th=math.pi*j/rings
   for i in range(sides):
    a=math.tau*i/sides
    r=radius*math.sin(th)*(1+(.035 if hazel else .055)*math.cos(a*5)*abs(math.cos(th)))
    z=radius*math.cos(th)*(1.18 if hazel else .9)
    if not hazel:z-=radius*.17*math.exp(-(th/.35)**2)
    color=(1,.85,.62,1) if i%7==0 else (1,1,1,1)
    self.verts([pos+Vector((math.cos(a)*r,math.sin(a)*r,z))],[(i/sides,j/rings)],color)
  for j in range(rings):
   for i in range(sides):self.face((k0+j*sides+i,k0+j*sides+(i+1)%sides,k0+(j+1)*sides+(i+1)%sides,k0+(j+1)*sides+i),2)

 def object(self,name,mats,collection):
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(self.v,[],self.f);mesh.update()
  obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj)
  for m in mats:mesh.materials.append(m)
  uv=mesh.uv_layers.new(name='UVMap');colors=mesh.color_attributes.new(name='Col',type='BYTE_COLOR',domain='POINT')
  colors.data.foreach_set('color',[c for color in self.col for c in color])
  for poly,mi in zip(mesh.polygons,self.mi):
   poly.material_index=mi;poly.use_smooth=True
   for li in poly.loop_indices:uv.data[li].uv=self.uv[mesh.loops[li].vertex_index]
  return obj

# Keep vertex colors in glTF as small natural tonal variation.
for m in (barkA,barkH,leafA,leafH,fruitA,fruitH):
 bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 # glTF exporter handles vertex colors; shader itself stays simple and exportable.


models={};stats={};geos={}
def sample(path,t):
 x=max(0,min(1,t))*(len(path)-1);i=min(len(path)-2,int(x))
 return path[i].lerp(path[i+1],x-i)

def branch(g,start,end,r0,r1,rng,sides=7,segments=6):
 # Every attachment uses this exact sampled curve, never a straight chord.
 delta=end-start;span=delta.length
 side=Vector((-delta.y,delta.x,0)).normalized()
 sway=side*rng.uniform(-.10,.10)*span
 bow=Vector((0,0,min(.25,span*.10)))+sway
 pts=[start+delta*(j/segments)+bow*math.sin(math.pi*j/segments) for j in range(segments+1)]
 rs=[r1+(r0-r1)*(1-j/segments)**.75 for j in range(segments+1)]
 # A short rounded closed tip with finite radius, never a long cone/needle.
 pts.append(end+delta.normalized()*r1*.5);rs.append(r1*.6)
 g.tube(pts,rs,sides)
 return pts

def leaf_on_path(g,path,t,angle,length,rng,hazel):
 attach=sample(path,t)
 direction=Vector((math.cos(angle),math.sin(angle),rng.uniform(-.32,.32))).normalized()
 base=attach+direction*(length*.15)
 # Tiny explicit petiole, two-sided ribbon, connected to the sampled branch.
 side=Vector((-direction.y,direction.x,.15)).normalized()*.0009
 if not g.record_only:
  k=g.verts([attach-side,attach+side,base+side,base-side]);g.face((k,k+1,k+2,k+3),0)
 g.leaf(base,direction,length,rng,hazel)

def tuft(g,path,rng,hazel,dense=True,start=.08):
 # Alternate leaves and a terminal rosette cover each live shoot's rounded end.
 n=13 if dense else 9
 phase=rng.random()*math.tau
 for j in range(n):
  leaf_on_path(g,path,start+(.99-start)*j/(n-1),phase+j*2.399,rng.uniform(.105,.155) if hazel else rng.uniform(.10,.145),rng,hazel)
 for j in range(3):leaf_on_path(g,path,1,phase+j*math.tau/3,.11,rng,hazel)

# 0.0.6.11 : cinq tailles (1 petit, 2 plutôt petit, 3 standard, 4 plutôt grand, 5 grand), pas le même arbre agrandi :
# kz hauteur, kr largeur de la couronne, clear hauteur des premières branches (m), kt épaisseur du tronc.
# Les feuilles, rameaux et fruits gardent leur vraie taille : un grand arbre a plus de branches et de feuilles.
# Pommier standard : environ 7 m, tronc plus large, premières branches vers 2 m (plus réaliste qu'en 0.0.6.10).
APPLE_SIZES={1:(.62,.65,1.0,.50),2:(.95,.92,1.5,.85),3:(1.35,1.25,2.0,1.30),4:(1.55,1.40,2.2,1.55),5:(1.75,1.55,2.4,1.80)}
# Noisetier : [kz, kr, feuillage à partir de (m), kt, nombre de tiges] ; standard environ 5,5 m.
HAZEL_SIZES={1:(.60,.62,.35,.55,5),2:(.95,.86,.60,.85,7),3:(1.40,1.12,.90,1.25,9),4:(1.62,1.28,1.10,1.45,10),5:(1.85,1.42,1.30,1.65,11)}

def make_species(hazel=False,size=3,record_only=False):
 name='Noisetier' if hazel else 'Pommier';rng=random.Random((3107 if hazel else 2173)+(size-3)*101)
 g=Geo(record_only);terminals=[];fruit_anchors=[];secondary=[]
 if not hazel:
  kz,kr,clear,kt=APPLE_SIZES[size]
  # Tronc qui continue en axe central jusqu'en haut ; trois étages de charpentières, le premier à « clear » mètres.
  base=[(0,0,0),(.035,.025,.30),(.07,-.02,.70),(.10,.02,1.10),(.08,.06,1.55),(.12,.04,2.05),(.09,.08,2.60),(.13,.06,3.15),(.10,.10,3.70),(.14,.08,4.20),(.12,.11,4.55)]
  trunk=[Vector((x*kr*.8,y*kr*.8,z*kz)) for x,y,z in base]
  g.tube(trunk,[r*kt for r in [.27,.22,.19,.165,.145,.125,.10,.08,.06,.04,.022]],16)
  for i in range(6):
   a=i*math.tau/6+.2;spread=rng.uniform(.38,.6)*kt**.5
   branch(g,Vector((0,0,.16*kt**.5)),Vector((math.cos(a)*spread,math.sin(a)*spread,-.07)),.115*kt,.025*kt,rng,9,6)
  top=4.55*kz;t0=min(.5,clear/top);t2=.72;t1=(t0+t2)/2
  w=kt**.8;lift=kz*.85
  # [étage sur le tronc (0-1), nombre, portée, hauteur gagnée, rayon de départ, ramifications]
  tiers=[(t0,4,(1.90*kr,2.25*kr),(.35*lift,.60*lift),.095*w,max(3,round(7*kr))),(t1,4 if kr<1.2 else 5,(1.45*kr,1.80*kr),(1.00*lift,1.35*lift),.075*w,max(2,round(5*kr))),(t2,4 if kr<1.2 else 5,(1.05*kr,1.35*kr),(.85*lift,1.15*lift),.055*w,max(2,round(4*kr)))]
  turn=rng.random()*math.tau
  for level,(height,count,reach_range,rise_range,radius,forks) in enumerate(tiers):
   for i in range(count):
    a=turn+i*math.tau/count+level*.79+rng.uniform(-.25,.25)
    start=sample(trunk,height+i*.02)
    reach=rng.uniform(*reach_range)
    end=start+Vector((math.cos(a)*reach,math.sin(a)*reach,rng.uniform(*rise_range)))
    main=branch(g,start,end,radius,.012,rng,12 if level==0 else 10,9)
    for j in range(forks):
     t=.16+j*(.78/forks);origin=sample(main,t)
     angle=a+(-1 if j%2 else 1)*rng.uniform(.45,1.05)
     spread=rng.uniform(.45,.80)*(1-level*.15)*(.75+.25*kr)
     # Étage bas : rameaux presque à plat ; plus haut, ils montent.
     tip=origin+Vector((math.cos(angle)*spread,math.sin(angle)*spread,rng.uniform(.05,.35) if level==0 else rng.uniform(.30,.75)))
     secondary.append((branch(g,origin,tip,.030*(1-t*.55),.006,rng,8,7),angle))
    if level==0:
     # Branches basses presque horizontales dont le bout retombe sous le poids des pommes, comme un vrai pommier.
     droop=branch(g,main[-1],main[-1]+Vector((math.cos(a)*.50*kr,math.sin(a)*.50*kr,-.32*kr**.5)),.014,.005,rng,7,6)
     secondary.append((droop,a))
     terminals.append(branch(g,droop[-1],droop[-1]+Vector((math.cos(a)*.22,math.sin(a)*.22,-.10)),.006,.0025,rng,5,4))
    else:
     terminals.append(branch(g,main[-1],main[-1]+Vector((math.cos(a)*.25,math.sin(a)*.25,.32)),.012,.0027,rng,6,5))
    # Branches basses et du milieu : rameaux feuillus tout le long, aussi vers les côtés et un peu vers le bas.
    if level<2:
     spurs=max(3,round((8 if level==0 else 5)*kr))
     for j in range(spurs):
      t=.08+j*(.80/spurs);origin=sample(main,t)
      angle=a+(-1 if j%2 else 1)*rng.uniform(.9,1.6)
      spread=rng.uniform(.30,.55)
      tip=origin+Vector((math.cos(angle)*spread,math.sin(angle)*spread,rng.uniform(-.35,.05) if level==0 else rng.uniform(-.18,.18)))
      secondary.append((branch(g,origin,tip,.016,.004,rng,6,6),angle))
  # Garnissage entre les étages, pour une couronne pleine.
  infill=max(3,round(5*kr*kr))
  for i in range(infill):
   a=turn+i*2.399+.5;origin=sample(trunk,t0+.04+i*(.84-t0)/infill)
   tip=origin+Vector((math.cos(a)*rng.uniform(.85,1.25)*kr,math.sin(a)*rng.uniform(.85,1.25)*kr,rng.uniform(.35,.65)*lift))
   secondary.append((branch(g,origin,tip,.026,.005,rng,8,7),a))
  # Cime : quelques pousses courtes autour du haut de l'axe, pas de pointe nue.
  for i in range(5):
   a=turn+i*2.399;origin=sample(trunk,.86+i*.03)
   tip=origin+Vector((math.cos(a)*rng.uniform(.60,.90)*kr,math.sin(a)*rng.uniform(.60,.90)*kr,rng.uniform(.45,.80)*lift))
   secondary.append((branch(g,origin,tip,.028,.005,rng,9,8),a))
 else:
  kz,kr,clear,kt,stems=HAZEL_SIZES[size]
  # Touffe de tiges inégales ; feuillage à partir de « clear » mètres (plus haut sur un grand noisetier).
  for i in range(stems):
   a=i*math.tau/stems+rng.uniform(-.23,.23)
   height=rng.uniform(2.85,3.75)*kz;reach=rng.uniform(.65,1.22)*kr
   foot=Vector((math.cos(a)*.16*kt**.5,math.sin(a)*.16*kt**.5,-.015))
   end=Vector((math.cos(a)*reach,math.sin(a)*reach,height))
   stem=branch(g,foot,end,rng.uniform(.055,.08)*kt,.007,rng,10,14)
   start=min(.6,clear/height)
   sides=max(5,round(8*(.7+.3*kz)))
   for j in range(sides):
    t=start+j*(.95-start)/sides;origin=sample(stem,t)
    angle=a+(-1 if j%2 else 1)*rng.uniform(.35,.95)
    spread=(.60+math.sin(math.pi*t)*.38)*rng.uniform(.80,1.1)*kr**.5
    tip=origin+Vector((math.cos(angle)*spread,math.sin(angle)*spread,rng.uniform(.22,.50)))
    secondary.append((branch(g,origin,tip,.017+(1-t)*.012,.0045,rng,7,7),angle))
   tuft(g,stem,rng,True,False,start)
 # Each secondary branches into fine leafy twigs all along its actual curved path.
 for path,angle in secondary:
  for k in range(5 if hazel else 6):
   t=.20+k*(.19 if hazel else .155);origin=sample(path,t)
   a=angle+(-1 if k%2 else 1)*rng.uniform(.55,1.25)
   span=rng.uniform(.32,.55)
   end=origin+Vector((math.cos(a)*span,math.sin(a)*span,rng.uniform(.08,.32)))
   twig=branch(g,origin,end,.007 if hazel else .008,.0022,rng,5,5)
   terminals.append(twig)
   # Noisettes au bout des rameaux (au bord du feuillage, visibles), pommes un peu plus à l'intérieur.
   if rng.random()<(.30 if hazel else .23):fruit_anchors.append(sample(twig,.88 if hazel else .60))
  tuft(g,path,rng,hazel,False)
 for path in terminals:
  tuft(g,path,rng,hazel)
  for j in range(2 if hazel else 3):
   at=sample(path,.35+j*.28);a=rng.random()*math.tau
   end=at+Vector((math.cos(a)*rng.uniform(.18,.30),math.sin(a)*rng.uniform(.18,.30),rng.uniform(-.03,.18)))
   shoot=branch(g,at,end,.0032,.0017,rng,4,4)
   tuft(g,shoot,rng,hazel,False)
 # Fruit pedicels connect to the actual twig, including the involucre of every hazelnut.
 for anchor in fruit_anchors:
  if hazel:
   for j in range(rng.randint(2,3)):
    pos=anchor+Vector(((j-1)*.04,.012,-.06-j*.01))
    g.fruit(pos,.022,rng,True)
    g.tube([anchor,pos+Vector((0,0,.011))],[.0018,.0015],4)
    for k in range(4):
     a=k*math.tau/4
     g.leaf(pos+Vector((0,0,-.01)),Vector((math.cos(a),math.sin(a),.75)),.042,rng,True,True)
  else:
   pos=anchor+Vector((0,0,-.10));radius=rng.uniform(.042,.052)
   g.fruit(pos,radius,rng)
   g.tube([anchor,pos+Vector((0,0,radius*.85))],[.0023,.003],5)
 g.fruit_count=len(fruit_anchors)
 if record_only:
  return g
 # Version détaillée gardée dans le fichier Blender (taille standard) ; la version légère est faite par version_jeu.py.
 col=bpy.data.collections.new(name+'_Taille_%d'%size);scene.collection.children.link(col)
 mats=[barkH,leafH,fruitH] if hazel else [barkA,leafA,fruitA]
 detail=g.object(name+'_Detail',mats,col)
 detail['species']='Corylus avellana' if hazel else 'Malus domestica'
 detail['size']=size;detail['leaf_count']=g.leaves
 detail['source']='Original OrbMeka / Blender';detail['lod_role']='detail'
 detail.location.x=4.5 if hazel else -4.5
 bpy.context.view_layer.update()
 def count(obj):return sum(len(p.vertices)-2 for p in obj.data.polygons)
 stats[name]={'size':size,'triangles_detail':count(detail),'vertices_detail':len(detail.data.vertices),'leaves':g.leaves,'fruits_or_clusters':len(fruit_anchors),'height_m':round(detail.dimensions.z,3),'width_m':round(detail.dimensions.x,3),'lowest_leaf_m':round(min(p.z for p in g.leaf_centers),3)}
 geos[name]=g
 models[name]=detail;print(name,stats[name]);return detail

if __name__=='__main__':
 make_species(False)
 make_species(True)
 scene['OrbMeka_assets']='Revision 4 (0.0.6.11): five sizes, standard size kept in detail here; light game versions by version_jeu.py.'
 scene['stats_json']=json.dumps(stats)
 text=bpy.data.texts.get('OrbMeka_Arbres_Generateur.py') or bpy.data.texts.new('OrbMeka_Arbres_Generateur.py');text.clear();text.write(Path(__file__).read_text(encoding='utf-8'))
 bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
 (OUT/'mesures.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
 print('SOURCE_SAVED',str(BLEND))
