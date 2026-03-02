import sys

content = open('scenes/ui/turn_order_panel.tscn').read()
nodes = content.split('\n[node name="')

# nodes[0] is everything up to first [node name=  (wait, no, first node is '[gd_scene... \n\n[node name="TurnOrderPanel"')
# let's be more precise
parts = content.split('\n[node name="')

slots = {}
others = []

# Because the first split is just `[gd_scene...`, parts[0] string is that header plus the first newline before `[node name="TurnOrderPanel"`.
header = parts[0]

for p in parts[1:]:
    # p starts with the rest of the name, e.g., 'TurnOrderPanel" type="PanelContainer"...'
    name = p.split('"')[0]
    full_node = '\n[node name="' + p
    if name.startswith('Slot'):
        slots[name] = full_node
    else:
        others.append(full_node)

arrow_text = '''
[node name="CurrentArrow" type="Label" parent="VBoxContainer/{name}"]
layout_mode = 1
anchors_preset = 4
anchor_top = 0.5
anchor_bottom = 0.5
offset_left = -20.0
offset_top = -11.0
offset_right = -5.0
offset_bottom = 12.0
grow_vertical = 2
theme_override_colors/font_color = Color(1, 0.95, 0.5, 1)
theme_override_font_sizes/font_size = 18
text = "▶"
horizontal_alignment = 1
vertical_alignment = 1'''

new_order = ['SlotNext3', 'SlotNext2', 'SlotNext1', 'SlotCurrent', 'SlotPast']

# Others: TurnOrderPanel, VBoxContainer
# Then others are child layers inside the slots, wait!
# 'SlotPast/Portrait' is separated as well!? Oh wait, children are NOT `name="SlotPast/Portrait"`, they are `name="Portrait" parent="VBoxContainer/SlotPast"`
# So my script logic was WRONG.

# Let's write a proper parser.
import re

blocks = re.split(r'\n(?=\[node name=")', content)
# blocks[0] is header + ext_resources
out_blocks = []

scene_slots = {
    'SlotPast': [],
    'SlotCurrent': [],
    'SlotNext1': [],
    'SlotNext2': [],
    'SlotNext3': [],
}

current_slot = None

for b in blocks:
    if b.startswith('[node name="'):
        match = re.search(r'\[node name="([^"]+)"', b)
        parent_match = re.search(r'parent="([^"]+)"', b)
        
        name = match.group(1) if match else ""
        parent = parent_match.group(1) if parent_match else ""
        
        if name in scene_slots:
            current_slot = name
            scene_slots[name].append(b)
        elif current_slot and ('VBoxContainer/' + current_slot) in parent:
            scene_slots[current_slot].append(b)
        else:
            out_blocks.append(b)
            current_slot = None
    else:
        out_blocks.append(b)

with open('scenes/ui/turn_order_panel.tscn', 'w') as f:
    f.write(out_blocks[0]) # Header
    f.write(out_blocks[1]) # TurnOrderPanel
    f.write('\n' + out_blocks[2].lstrip()) # VBoxContainer
    
    for s in new_order:
        for node in scene_slots[s]:
            f.write('\n' + node.lstrip())
        arrow = arrow_text.format(name=s)
        f.write('\n' + arrow.lstrip())
