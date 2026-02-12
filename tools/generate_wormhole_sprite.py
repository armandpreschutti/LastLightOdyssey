from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import math
import random

def create_wormhole_sprite(output_path, size=(64, 64)):
    print(f"Generating wormhole sprite at size {size}...")
    
    # Create a new image with transparency
    img = Image.new('RGBA', size, (0, 0, 0, 0))
    pixels = img.load()
    
    center_x, center_y = size[0] / 2, size[1] / 2
    max_radius = size[0] / 2 - 1
    
    # Parameters for the wormhole
    rotation_speed = 8.0  # High rotation for tight spiral
    arms = 2 # 2 main arms
    
    for x in range(size[0]):
        for y in range(size[1]):
            dx = x - center_x
            dy = y - center_y
            dist = math.sqrt(dx*dx + dy*dy)
            angle = math.atan2(dy, dx)
            
            # 1. Event Horizon (The Void)
            # Sharp black circle in the middle
            horizon_radius = max_radius * 0.25
            if dist < horizon_radius:
                # Anti-aliased edge for the hole
                alpha = 255
                if dist > horizon_radius - 1.0:
                    alpha = int(255 * (horizon_radius - dist))
                
                # Pure black
                pixels[x, y] = (0, 0, 0, alpha)
                continue
                
            if dist > max_radius:
                continue

            # Normalized distance from horizon to edge (0 to 1)
            norm_dist = (dist - horizon_radius) / (max_radius - horizon_radius)
            
            # 2. Accretion Disk (The Swirl)
            
            # Logarithmic spiral effect
            # As we get closer to the horizon, velocity increases (angle twists more)
            twist = angle + (1.0 / (norm_dist + 0.1)) * 1.5
            
            # Base brightness from spiral arms
            # sin produces -1 to 1. Map to 0 to 1
            spiral_val = math.sin(twist * arms)
            spiral_intensity = (spiral_val + 1) / 2
            
            # Sharpen the arms to make them distinct streaks
            spiral_intensity = pow(spiral_intensity, 3.0)
            
            # 3. Radial Gradient (Brighter near horizon)
            # Brightness falls off as we go out
            radial_brightness = 1.0 / (norm_dist + 0.2)
            radial_brightness = min(2.0, radial_brightness) # Cap/Glow
            
            # 4. Noise/Texture
            noise = random.uniform(0.8, 1.2)
            
            # Combine
            total_intensity = spiral_intensity * radial_brightness * noise
            
            # 5. Coloring
            # Spectrum: White (Hot) -> Cyan -> Purple -> Blue (Cold/Edge)
            
            r, g, b = 0, 0, 0
            
            if total_intensity > 1.5:
                # White hot
                r, g, b = 255, 255, 255
            elif total_intensity > 0.8:
                # Cyan/Bright Blue
                # Interp between White and Cyan
                t = (total_intensity - 0.8) / 0.7
                r = int(0 + 255 * t)
                g = 255
                b = 255
            elif total_intensity > 0.4:
                # Purple/Pink
                # Interp between Cyan and Purple
                t = (total_intensity - 0.4) / 0.4
                r = int(180 * (1-t))
                g = int(0 + 255 * t)
                b = 255
            else:
                # Deep Blue/Violet
                r = int(80 * total_intensity)
                g = 0
                b = int(180 * total_intensity + 50)

            # 6. Alpha Calculation
            # Solid near horizon, fades out at edge
            alpha = int(255 * min(1.0, total_intensity))
            
            # Soft circular mask at outermost edge
            if norm_dist > 0.9:
                edge_fade = (1.0 - norm_dist) / 0.1
                alpha = int(alpha * edge_fade)
                
            # Clamping
            r = min(255, max(0, r))
            g = min(255, max(0, g))
            b = min(255, max(0, b))
            
            pixels[x, y] = (r, g, b, alpha)

    # Apply a light blur to smooth the noise
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    
    # Save
    img.save(output_path)
    print(f"Saved to {output_path}")

if __name__ == "__main__":
    output_file = r'c:\Users\arman\Documents\Godot\Projects\Last Light Odyssey\assets\sprites\navigation\wormhole.png'
    create_wormhole_sprite(output_file, size=(64, 64))
