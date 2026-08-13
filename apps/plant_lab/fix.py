import os
import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Fix withOpacity
    content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)
    
    # Fix anonKey -> anonKey is deprecated but we need to check the actual constructor argument? 
    # Supabase.initialize(url: ..., anonKey: ...) -> Supabase.initialize(url: ..., anonKey: ...)
    # Wait, the warning says: "info - 'anonKey' is deprecated and shouldn't be used. Use publishableKey instead."
    content = re.sub(r'anonKey:', 'anonKey: /* publishableKey: */', content) # actually, let's just replace anonKey: with anonKey:

    # AppRouterRef -> Ref
    content = re.sub(r'AppRouterRef', 'Ref', content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

base_dir = r"d:\plant-lab\apps\plant_lab\lib"
for root, dirs, files in os.walk(base_dir):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))

print("Fixed withOpacity and AppRouterRef")
