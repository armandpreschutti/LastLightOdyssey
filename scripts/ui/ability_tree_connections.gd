extends Control
## Draws connection lines between ability nodes

var officer_key: String = ""

# Connection Layer Drawing
func _draw():
	var parent = get_parent()
	if not parent is Control: return
	
	var nodes = []
	for child in parent.get_children():
		if child is Control and child != self:
			nodes.append(child)
	
	if nodes.is_empty(): return
	
	var accent = GameState.OFFICER_COLOR.get(officer_key, Color(0.4, 0.7, 1.0))
	
	# Find Level 1 node
	var l1_node = null
	var l2_nodes = []
	var l3_nodes = []
	
	for n in nodes:
		var ab_id = n.ability_id
		var def = GameState.ABILITY_DEFS.get(ab_id, {})
		var tier = def.get("level", 1)
		if tier == 1: l1_node = n
		elif tier == 2: l2_nodes.append(n)
		elif tier == 3: l3_nodes.append(n)
	
	if not l1_node: return
	
	# Draw L1 -> L2
	for l2 in l2_nodes:
		_draw_connection(l1_node, l2, accent)
		
	# Draw L2 -> L3
	# Logic: L2[0] connects to L3[0], L3[1]
	# Logic: L2[1] connects to L3[1], L3[2]
	if l2_nodes.size() == 2 and l3_nodes.size() == 3:
		_draw_connection(l2_nodes[0], l3_nodes[0], accent)
		_draw_connection(l2_nodes[0], l3_nodes[1], accent)
		_draw_connection(l2_nodes[1], l3_nodes[1], accent)
		_draw_connection(l2_nodes[1], l3_nodes[2], accent)


func _draw_connection(from, to, color):
	var start = from.position + from.size / 2
	var end = to.position + to.size / 2
	
	# Determine line style based on "to" node state
	var line_color = color
	var line_width = 2.0
	var alpha = 0.2 # Default faint
	
	if to.is_unlocked:
		alpha = 0.8
		line_width = 3.0
	elif to.is_available:
		alpha = 0.5
		line_width = 2.5
		# Pulse effect? (For now just brighter)
	
	line_color.a = alpha
	
	# Shadow line
	draw_line(start, end, Color(0, 0, 0, alpha * 0.5), line_width + 2.0)
	# Main line
	draw_line(start, end, line_color, line_width)
	# Glow/Points
	draw_circle(start, line_width * 1.5, line_color)
	draw_circle(end, line_width * 1.5, line_color)
