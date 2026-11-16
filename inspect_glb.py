import bpy
import sys

# Inspect a KayKit skeleton GLB: list actions (animation clips) with
# frame ranges, armatures, and handslot empties. Usage:
#   blender -b --python inspect_glb.py -- <glb path>
argv = sys.argv[sys.argv.index("--") + 1:]
path = argv[0]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
print("OBJECTS:")
for o in bpy.data.objects:
    print("  ", o.type, o.name)
print("ACTIONS:")
for a in bpy.data.actions:
    fr = a.frame_range
    print("  ", a.name, "frames %.0f-%.0f" % (fr[0], fr[1]))
print("ARMATURES:")
for o in bpy.data.objects:
    if o.type == 'ARMATURE':
        print("  ", o.name, "bones:", len(o.data.bones))
        for b in o.data.bones:
            if 'hand' in b.name.lower() or 'slot' in b.name.lower():
                print("     hand-ish bone:", b.name)
