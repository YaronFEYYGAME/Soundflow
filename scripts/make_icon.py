# Génère l'icône de l'application : Soundflow/Assets.xcassets/AppIcon.appiconset/AppIcon.png
#
# Usage (Pillow requis) :
#   python3 -m pip install pillow
#   python3 scripts/make_icon.py Soundflow/Assets.xcassets/AppIcon.appiconset/AppIcon.png
#
# Pour changer l'aspect de l'icône, modifier les couleurs TOP / BOTTOM ou la
# géométrie de la note ci-dessous, puis relancer. Une seule image de
# 1024 × 1024 suffit : Xcode produit toutes les autres tailles.
#
import math, sys
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 4                      # suréchantillonnage pour l'anticrénelage
S = SIZE * SS

# --- Fond : dégradé diagonal dans la teinte d'accent de l'app -------------
TOP = (84, 136, 246)        # haut-gauche, plus lumineux
BOTTOM = (28, 56, 158)      # bas-droite, plus profond
bg = Image.new("RGB", (SIZE, SIZE))
px = bg.load()
for y in range(SIZE):
    for x in range(SIZE):
        t = (x + y) / (2 * (SIZE - 1))
        t = t * t * (3 - 2 * t)          # lissage : transition plus douce
        px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))

# --- Double croche, dessinée en coordonnées 1024 puis mise à l'échelle -----
DX, DY = -18, 11                         # recentrage de la silhouette
K = 1.1                                  # agrandissement autour du centre
def P(x, y):
    x = (x + DX - 512) * K + 512
    y = (y + DY - 512) * K + 512
    return (x * SS, y * SS)

def ellipse_points(cx, cy, rx, ry, angle_deg, n=240):
    a = math.radians(angle_deg)
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = cx + rx * math.cos(t) * math.cos(a) - ry * math.sin(t) * math.sin(a)
        y = cy + rx * math.cos(t) * math.sin(a) + ry * math.sin(t) * math.cos(a)
        pts.append(P(x, y))
    return pts

def draw_note(draw, fill):
    # Têtes de notes, inclinées comme en gravure musicale.
    draw.polygon(ellipse_points(392, 704, 90, 64, -22), fill=fill)
    draw.polygon(ellipse_points(672, 644, 90, 64, -22), fill=fill)
    # Hampes.
    # Elles s'arrêtent à mi-hauteur de la barre : c'est le bord incliné de
    # la barre, et non le sommet plat des hampes, qui dessine le contour.
    draw.rectangle([P(448, 350), P(478, 694)], fill=fill)
    draw.rectangle([P(728, 284), P(758, 634)], fill=fill)
    # Barre de ligature, parallèle à l'axe des têtes.
    draw.polygon([P(448, 300), P(758, 234), P(758, 330), P(448, 396)], fill=fill)

# Ombre portée discrète, pour détacher la note du fond.
shadow = Image.new("L", (S, S), 0)
draw_note(ImageDraw.Draw(shadow), 255)
shadow = shadow.resize((SIZE, SIZE), Image.LANCZOS)
shadow = shadow.transform((SIZE, SIZE), Image.AFFINE, (1, 0, 0, 0, 1, -10))  # décalée vers le bas
shadow = shadow.filter(ImageFilter.GaussianBlur(18))
shadow_layer = Image.new("RGB", (SIZE, SIZE), (10, 20, 60))
bg.paste(shadow_layer, (0, 0), shadow.point(lambda v: int(v * 0.35)))

# Note blanche.
mask = Image.new("L", (S, S), 0)
draw_note(ImageDraw.Draw(mask), 255)
mask = mask.resize((SIZE, SIZE), Image.LANCZOS)
bg.paste(Image.new("RGB", (SIZE, SIZE), (255, 255, 255)), (0, 0), mask)

# Icône opaque, carrée, sans coins arrondis : c'est iOS qui applique le
# masque. (Une icône avec transparence serait remplie de noir par iOS.)
out = sys.argv[1]
bg.save(out, "PNG", optimize=True)
im = Image.open(out)
print(out, im.size, im.mode)
