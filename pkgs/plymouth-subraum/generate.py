from colour import Color
import os

os.system("rm animation-*.png")
os.system("rm throbber-*.png")

n_frames = 50
frame_mul = 1
for i in range(n_frames):
    c = Color(hue=i/n_frames, saturation=1, luminance=0.5)
    print(c.hex)


    if i % frame_mul == 0:
        os.system("cp subraum_logo_glow.svg subraum_logo_glow_anim.svg")
        os.system(f"sed -i 's/fill:#5e00ff/fill:{c.hex}/g' 'subraum_logo_glow_anim.svg'")
        os.system(f'inkscape --actions="export-type:png;export-filename:animation-{i}.png;export-width:400;export-do" ./subraum_logo_glow_anim.svg')
        #os.system(f"cp animation-{i}.png throbber-{i}.png")
    else:
        print("copy",i)
        os.system(f"cp animation-{(i-1)}.png animation-{i}.png")
        os.system(f"cp animation-{(i-1)}.png throbber-{i}.png")
