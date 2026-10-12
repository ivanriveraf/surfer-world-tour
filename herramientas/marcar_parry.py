"""Genera las versiones MARCADAS a partir del sprite normal.

En las laminas dibujadas el contorno rosa envuelve tambien la espuma y las
burbujas, que estan al lado de la aleta y no debajo: por eso quedaban esas
manchas rosas y no habia forma de recortarlas.

Generandolo desde el sprite normal se resuelve solo:
  - la silueta y la animacion son EXACTAMENTE las del normal
  - el rosa traza solo el contorno del bicho
  - se dibujan al mismo tamano, sin tener que calibrar nada
"""
from PIL import Image
import numpy as np
from scipy import ndimage

ROSA = (255, 62, 165)     # contorno
BRILLO = (255, 150, 210)  # halo suave por fuera
G = 5                     # grosor del contorno

def marcar(src, nf, dst):
    im = Image.open(src).convert("RGBA")
    a = np.array(im)
    fw = im.size[0] // nf
    salida = Image.new("RGBA", (im.size[0] + nf * 2 * G, im.size[1] + 2 * G), (0, 0, 0, 0))
    for k in range(nf):
        fr = a[:, k * fw:(k + 1) * fw]
        al = fr[:, :, 3] > 40
        if not al.any():
            continue
        pad = np.zeros((fr.shape[0] + 2 * G, fw + 2 * G), bool)
        pad[G:-G, G:-G] = al
        # cerrar huecos: si no, cada gotita suelta de espuma se lleva su
        # propio contorno y el sprite queda recargado de rosa
        pad = ndimage.binary_closing(pad, np.ones((9, 9)))
        pad = ndimage.binary_fill_holes(pad)
        anillo = ndimage.binary_dilation(pad, np.ones((3, 3)), iterations=G) & ~pad
        halo = ndimage.binary_dilation(pad, np.ones((3, 3)), iterations=G + 2) & ~pad & ~anillo
        cap = np.zeros((pad.shape[0], pad.shape[1], 4), np.uint8)
        cap[halo] = (*BRILLO, 150)
        cap[anillo] = (*ROSA, 255)
        capa = Image.fromarray(cap, "RGBA")
        base = Image.new("RGBA", capa.size, (0, 0, 0, 0))
        base.paste(Image.fromarray(fr, "RGBA"), (G, G))
        capa.alpha_composite(base)
        salida.alpha_composite(capa, (k * (fw + 2 * G), 0))
    salida.save(dst)
    print(f"{dst:22s} {salida.size[0]}x{salida.size[1]}  {nf} frames de {salida.size[0]//nf}x{salida.size[1]}")

for src, nf, dst in [("shark_fin.png", 4, "parry_shark_fin.png"),
                     ("shark_full.png", 3, "parry_shark.png"),
                     ("buoy.png", 5, "parry_buoy.png"),
                     ("wood.png", 6, "parry_log.png"),
                     ("bird.png", 2, "parry_bird.png")]:
    marcar(src, nf, dst)
