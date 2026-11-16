"""bake_rogue.py - DEEPFALL Chunk 1: bake the KayKit Skeleton Rogue to 2D.

Same recipe as the 2026-11-13 Skeleton Warrior bake (Blender 4.2.3
headless, Cycles CPU, ortho side view from -Y, transparent):
  source: staged kaykit-skeletons Skeleton_Rogue.glb + Skeleton_Crossbow.gltf
          parented to handslot.r (the sample render shows the rogue
          with a crossbow; the game AI is melee-only, so the crossbow
          is a visual weapon and the attack is a 1H stab)
  walk:  Walking_A_Rig frames [0, 7, 13, 20]
  attack: 1H_Melee_Attack_Stab_Rig frames [2, 13, 24, 35]
  idle:  Idle_Rig frame [13]
Renders 512px PNGs to bake-out/; build_chunk1_enemies.py's sibling
post-process (bake_rogue_post.py) trims/scales them into
assets/enemies/skeleton-rogue/ (256px) and assets/enemies_px/
skeleton-rogue/ (26px + outline + death frames).

Usage:
  blender -b --python bake_rogue.py -- [test|full]
  test = one idle frame only, for facing/lighting checks.
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
STAGING = "/home/hatch/workspace/asset-pipeline/staging/deepfall/kaykit-skeletons"
GLB = os.path.join(STAGING, "addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Rogue.glb")
XBOW = os.path.join(STAGING, "addons/kaykit_character_pack_skeletons/Assets/gltf/Skeleton_Crossbow.gltf")
OUT = os.path.join(HERE, "bake-out", "skeleton-rogue")

MODE = "full"
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    MODE = argv[0]

CLIPS = [
    ("walk", "Walking_A_Rig", [0, 7, 13, 20]),
    ("attack", "1H_Melee_Attack_Stab_Rig", [2, 13, 24, 35]),
    ("idle", "Idle_Rig", [13]),
]
if MODE == "test":
    CLIPS = [("idle", "Idle_Rig", [13])]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
rig = None
for o in bpy.data.objects:
    if o.type == 'ARMATURE':
        rig = o
        break
assert rig is not None, "no armature in rogue GLB"

# Crossbow into the right hand slot (same pattern as the warrior's blade).
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=XBOW)
new_objs = [o for o in bpy.data.objects if o not in before]
# Parent every new top-level object to handslot.r.
for o in new_objs:
    if o.parent is None:
        o.parent = rig
        o.parent_type = 'BONE'
        o.parent_bone = 'handslot.r'
        o.matrix_parent_inverse = rig.matrix_world.inverted()

# --- Camera: ortho side view from -Y. The rig faces -Y in KayKit
# space (a -Y camera sees it front-on), so rotate -90 deg about Z
# to put the profile facing screen-left (-X), matching the Warrior
# bake convention (warrior idle faces left).
rig.rotation_mode = 'XYZ'  # GLB imports the rig as QUATERNION; euler sets are no-ops there
rig.rotation_euler = (0, 0, -1.5708)
# Frame the character: measure the mesh bounds at the idle pose.
rig.animation_data.action = bpy.data.actions["Idle_Rig"]
bpy.context.scene.frame_set(13)
bpy.context.view_layer.update()
import mathutils
mn = mathutils.Vector((1e9, 1e9, 1e9))
mx = mathutils.Vector((-1e9, -1e9, -1e9))
for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    for v in o.bound_box:
        w = o.matrix_world @ mathutils.Vector(v)
        mn = mathutils.Vector(map(min, mn, w))
        mx = mathutils.Vector(map(max, mx, w))
print("BOUNDS min=%s max=%s" % (tuple(round(v, 3) for v in mn), tuple(round(v, 3) for v in mx)))
cx = (mn.x + mx.x) / 2.0
cz = (mn.z + mx.z) / 2.0
height = mx.z - mn.z
width = mx.x - mn.x

cam_data = bpy.data.cameras.new("bake_cam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = max(height, mx.x - mn.x) * 1.15
cam = bpy.data.objects.new("bake_cam", cam_data)
bpy.context.scene.collection.objects.link(cam)
cam.location = (cx, -10.0, cz)
cam.rotation_euler = (1.5708, 0, 0)  # look along +Y
bpy.context.scene.camera = cam

# --- Light: sun from the camera side + soft world ambient.
sun_data = bpy.data.lights.new("bake_sun", type='SUN')
sun_data.energy = 3.0
sun = bpy.data.objects.new("bake_sun", sun_data)
bpy.context.scene.collection.objects.link(sun)
sun.location = (cx - 2.0, -4.0, cz + 3.0)
sun.rotation_euler = (0.6, 0.2, 0.4)
world = bpy.data.worlds.new("bake_world")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.45, 0.45, 1.0)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
bpy.context.scene.world = world

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 32
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'

os.makedirs(OUT, exist_ok=True)
for kind, action_name, frames in CLIPS:
    rig.animation_data.action = bpy.data.actions[action_name]
    for i, f in enumerate(frames):
        scene.frame_set(f)
        scene.render.filepath = os.path.join(OUT, "%s_%d.png" % (kind, i))
        bpy.ops.render.render(write_still=True)
        print("BAKED %s_%d (action %s frame %d)" % (kind, i, action_name, f))
print("BAKE DONE -> %s" % OUT)
