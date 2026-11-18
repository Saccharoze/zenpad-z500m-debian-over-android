import os, struct, sys
root = sys.argv[1]                      # e.g. /usr/share/icons/invisible
cdir = os.path.join(root, 'cursors'); os.makedirs(cdir, exist_ok=True)
# Xcursor file: header + 1 TOC entry + one 1x1 fully transparent image chunk
img = struct.pack('<IIIIIIIII', 36, 0xfffd0002, 32, 1, 1, 1, 0, 0, 0) + struct.pack('<I', 0)
data = struct.pack('<4sIII', b'Xcur', 16, 0x10000, 1) + struct.pack('<III', 0xfffd0002, 32, 28) + img
open(os.path.join(cdir, 'default'), 'wb').write(data)
names = set(os.listdir('/usr/share/icons/Adwaita/cursors'))
names |= set('''left_ptr xterm hand1 hand2 watch left_ptr_watch crosshair fleur question_arrow X_cursor arrow
top_left_arrow sb_h_double_arrow sb_v_double_arrow top_side bottom_side left_side right_side top_left_corner
top_right_corner bottom_left_corner bottom_right_corner plus pencil pirate dnd-move dnd-copy dnd-link dnd-none
ibeam pointer text wait progress help context-menu cell vertical-text alias copy move no-drop not-allowed grab
grabbing all-scroll col-resize row-resize n-resize e-resize s-resize w-resize ne-resize nw-resize se-resize
sw-resize ew-resize ns-resize nesw-resize nwse-resize zoom-in zoom-out size_ver size_hor size_bdiag size_fdiag
size_all split_h split_v openhand closedhand whats_this pointing_hand forbidden circle center_ptr right_ptr
draft_large draft_small target tcross ul_angle ur_angle ll_angle lr_angle cross'''.split())
n = 0
for name in sorted(names):
    if name == 'default': continue
    p = os.path.join(cdir, name)
    if os.path.lexists(p): os.remove(p)
    os.symlink('default', p); n += 1
open(os.path.join(root, 'index.theme'), 'w').write('[Icon Theme]\nName=invisible\nComment=All cursors transparent (Android draws the mouse pointer)\n')
print('cursor names:', n + 1)
