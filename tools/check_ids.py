import re

def check_game_state_ids():
    with open('c:/Users/arman/Documents/Godot/Projects/Last Light Odyssey/scripts/autoload/game_state.gd', 'r') as f:
        content = f.read()

    # Find ABILITY_DEFS
    defs_match = re.search(r'const ABILITY_DEFS: Dictionary = \{(.*?)\}', content, re.DOTALL)
    if not defs_match:
        print("Could not find ABILITY_DEFS")
        return
    
    defs_content = defs_match.group(1)
    def_ids = re.findall(r'"(.*?)"\s*:', defs_content)
    print(f"Found {len(def_ids)} ability definitions.")

    # Find OFFICER_ABILITIES
    officer_match = re.search(r'const OFFICER_ABILITIES: Dictionary = \{(.*?)\}', content, re.DOTALL)
    if not officer_match:
        print("Could not find OFFICER_ABILITIES")
        return
    
    officer_content = officer_match.group(1)
    officer_abilities_lists = re.findall(r'\[(.*?)\]', officer_content)
    
    all_referenced_ids = []
    for line in officer_abilities_lists:
        ids = re.findall(r'"(.*?)"', line)
        all_referenced_ids.extend(ids)
    
    print(f"Found {len(all_referenced_ids)} referenced ability IDs.")

    missing_in_defs = [id for id in all_referenced_ids if id not in def_ids]
    if missing_in_defs:
        print(f"ERROR: The following IDs are referenced in OFFICER_ABILITIES but missing in ABILITY_DEFS: {missing_in_defs}")
    else:
        print("All referenced IDs exist in ABILITY_DEFS.")

    # Check for casing differences
    lower_def_ids = [id.lower() for id in def_ids]
    for id in all_referenced_ids:
        if id.lower() in lower_def_ids and id not in def_ids:
            print(f"WARNING: Casing mismatch for ID '{id}'")

check_game_state_ids()
