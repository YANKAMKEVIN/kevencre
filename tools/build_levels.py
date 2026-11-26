# Kevencre : construit les niveaux en grilles de caractères (1 caractère = 1 case de 48 px)
# Légende :
#  #  sol          =  plateforme traversable   c  papier qui se déchire   X  faux mur (secret)
#  ^  ronces       S  départ                   C  chevalet (point de reprise)
#  *  goutte d'encre   P  pigment légendaire (secret)   K  autel du Vieux Pinceau
#  E  Tache grise (marche)   F  Corbac (vole)   T  Crachin (tire)   O  fleur-ressort
#  D  goutte de recharge (Trait d'encre)   G  cadre de sortie   !  panneau
import os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', 'levels')


class L:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [['.'] * w for _ in range(h)]

    def row(self, hgt):  # rangée de la surface pour une hauteur de sol hgt
        return self.h - hgt

    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch

    def rect(self, x1, x2, y1, y2, ch='#'):
        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                self.put(x, y, ch)

    def ground(self, x1, x2, hgt, ch='#'):
        self.rect(x1, x2, self.h - hgt, self.h - 1, ch)

    def pit(self, x1, x2):
        self.rect(x1, x2, 0, self.h - 1, '.')

    def at(self, x, hgt, ch):  # objet posé sur un sol de hauteur hgt
        self.put(x, self.h - hgt - 1, ch)

    def plat(self, x1, x2, hgt, ch='='):  # plateforme dont le dessus est à la hauteur hgt
        for x in range(x1, x2 + 1):
            self.put(x, self.h - hgt, ch)

    def drops(self, pts):
        for (x, hgt) in pts:
            self.at(x, hgt, '*')

    def arc(self, x1, x2, hgt, peak):
        n = x2 - x1
        for i in range(n + 1):
            t = i / max(1, n)
            yy = hgt + peak * 4 * t * (1 - t)
            self.put(x1 + i, self.h - int(round(yy)) - 1, '*')

    def save(self, name):
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, name), 'w') as f:
            f.write('\n'.join(''.join(r) for r in self.g) + '\n')


# ---------------------------------------------------------------- Niveau 1
def level1():
    l = L(214, 26)
    l.rect(0, 1, 0, 25)                     # bord gauche
    # A : les prés, on apprend à courir et sauter
    l.ground(2, 24, 4)
    l.ground(11, 15, 5)
    l.ground(18, 20, 6)
    l.at(4, 4, 'S')
    l.at(7, 4, '!')                         # panneau 0 : courir / sauter
    l.drops([(12, 5), (13, 5), (14, 5), (19, 6)])
    l.arc(24, 28, 4, 3)
    # petit trou
    l.ground(28, 40, 4)
    l.at(30, 4, '!')                        # panneau 1 : Taches
    l.at(35, 4, 'E')
    # escaliers
    l.ground(41, 43, 5)
    l.ground(44, 46, 7)
    l.ground(47, 52, 10)
    l.drops([(42, 5), (45, 7), (48, 10), (49, 10)])
    l.plat(55, 56, 10)
    l.arc(52, 59, 10, 2)
    l.ground(59, 69, 6)
    l.at(62, 6, 'E')
    # puits du saut contre les murs : pilier flottant + falaise
    l.rect(64, 65, l.row(22), l.row(9))     # pilier (de h22 à h9)
    l.ground(70, 92, 17)                    # falaise
    l.at(67, 6, '!')                        # panneau 2 : rebond mural
    # secret 1 : poche dans le pilier
    l.put(65, l.row(14), 'X'); l.put(65, l.row(15), 'X')
    l.put(64, l.row(14), 'X'); l.put(64, l.row(15), 'X')
    l.put(64, l.row(14) , 'P')
    l.drops([(67, 9), (68, 11), (67, 13), (68, 15)])
    # haut de la falaise
    l.drops([(73, 17), (74, 17), (75, 17)])
    l.at(78, 17, 'C')
    l.at(84, 17, 'E')
    l.ground(93, 96, 13)
    l.ground(97, 99, 10)
    # plateau de l'autel
    l.ground(100, 112, 8)
    l.at(104, 8, 'K')
    l.at(108, 8, '!')                       # panneau 3 : Trait d'encre
    # E : les grands vides
    l.ground(120, 124, 8)
    l.arc(112, 120, 8, 2)
    l.ground(134, 138, 9)
    l.at(129, 11, 'D')
    l.arc(124, 134, 8, 3)
    l.ground(139, 150, 5)
    l.rect(141, 148, l.row(6), l.row(6), '^')
    l.ground(141, 148, 5)
    l.rect(141, 148, l.row(6), l.row(6), '^')
    l.drops([(142, 8), (146, 8)])
    l.at(144, 9, 'D')
    l.ground(151, 156, 8)
    l.ground(149, 150, 8)
    l.at(153, 8, 'C')
    # F : le papier qui se déchire
    l.plat(160, 161, 9, 'c')
    l.plat(165, 166, 10, 'c')
    l.plat(170, 171, 11, 'c')
    l.plat(175, 176, 10, 'c')
    l.drops([(160, 9), (165, 10), (170, 11), (175, 10)])
    l.at(158, 8, '!')                       # panneau 4 : papier
    l.ground(180, 192, 8)
    l.at(184, 8, 'E')
    l.at(189, 8, 'E')
    # G : le grand mur (saut + trait vers le haut)
    l.ground(193, 213, 13)
    l.at(191, 8, '!')                       # panneau 5 : trait vers le haut
    l.drops([(192, 10), (192, 12), (192, 14)])
    # secret 2 : corniche haute
    l.plat(198, 200, 19)
    l.at(199, 19, 'P')
    l.at(197, 19, '*'); l.at(201, 19, '*')
    l.at(209, 13, 'G')
    l.rect(212, 213, 0, 25)
    l.save('1.txt')


# ---------------------------------------------------------------- Niveau 2
def level2():
    l = L(262, 34)
    l.rect(0, 1, 0, 33)
    # A : lisière de la forêt
    l.ground(2, 22, 5)
    l.at(4, 5, 'S')
    l.at(8, 5, '!')                         # panneau 0 : fleurs-ressorts
    l.at(14, 5, 'O')
    l.ground(17, 22, 11)                    # haut talus franchi grâce à la fleur
    l.drops([(14, 8), (14, 10), (14, 12)])
    l.ground(23, 30, 11)
    l.at(27, 11, 'E')
    # B : enfilade de vides au-dessus d'un ravin, avec Corbacs
    l.ground(37, 41, 11)
    l.arc(30, 37, 11, 3)
    l.at(39, 15, 'F')
    l.ground(49, 52, 12)
    l.at(45, 14, 'D')
    l.arc(41, 49, 11, 3)
    l.ground(53, 64, 9)
    l.at(57, 9, 'C')
    l.at(61, 9, 'T')
    # C : sous-bois, plafond de ronces
    l.ground(65, 92, 6)
    l.rect(68, 96, 0, l.row(13), '#')
    for x in range(70, 89, 1):
        l.put(x, l.row(12), '^') if x % 6 in (0, 1, 2) else None
    l.at(73, 6, 'E')
    l.at(81, 6, 'E')
    l.drops([(70, 6), (72, 6), (76, 6), (78, 6), (84, 6), (86, 6)])
    # secret 3 : faux mur au plafond, au fond du sous-bois
    l.rect(91, 93, l.row(14), l.row(13), 'X')
    l.rect(90, 94, l.row(17), l.row(15), '.')
    l.put(92, l.row(14), 'P')
    l.drops([(92, 8), (92, 10)])
    l.ground(93, 100, 6)
    # D : la grande chute d'eau : montée verticale (deux murs)
    l.ground(101, 104, 6)
    l.rect(105, 106, l.row(30), l.row(9))   # mur gauche du puits (flottant)
    l.rect(111, 114, l.row(30), l.row(1))   # mur droit (plein)
    l.ground(105, 110, 4)
    l.at(103, 6, '!')                       # panneau 1 : rebond + trait
    l.at(108, 4, 'C')
    l.at(108, 12, 'D')
    l.at(108, 20, 'D')
    l.drops([(107, 8), (109, 10), (107, 14), (109, 16), (107, 22), (109, 24)])
    l.at(108, 27, 'F')
    # sortie en haut à droite
    l.ground(115, 130, 25)
    l.rect(115, 130, 0, l.row(25) - 4, '.')
    l.at(120, 25, 'E')
    l.at(126, 25, 'C')
    # E : descente des cascades, plateformes et ressorts
    l.plat(134, 136, 22)
    l.plat(140, 142, 19)
    l.at(141, 19, 'T')
    l.plat(146, 148, 16)
    l.ground(150, 160, 13)
    l.at(155, 13, 'O')
    l.drops([(135, 22), (141, 21), (147, 16), (155, 16), (155, 19)])
    l.plat(153, 158, 22)
    l.ground(161, 170, 22)
    l.at(166, 22, 'E')
    l.at(168, 22, 'C')
    # F : traversée des nénuphars de papier, Corbacs
    l.plat(175, 176, 21, 'c')
    l.plat(181, 182, 22, 'c')
    l.at(184, 25, 'F')
    l.plat(187, 188, 21, 'c')
    l.at(191, 24, 'D')
    l.plat(195, 196, 22, 'c')
    l.drops([(175, 21), (181, 22), (187, 21), (195, 22)])
    l.ground(200, 214, 20)
    l.at(205, 20, 'T')
    l.at(209, 20, 'E')
    # secret 4 : sous la falaise, au bout d'un vide à franchir au trait
    l.ground(200, 214, 20)
    l.plat(186, 189, 12)
    l.at(186, 12, 'P')
    l.at(189, 12, 'O')
    l.drops([(183, 13), (184, 14)])
    l.ground(215, 224, 16)
    l.at(219, 16, 'C')
    # G : dernière enfilade, ronces au sol
    l.ground(225, 252, 5)
    l.rect(225, 252, l.row(6), l.row(6), '^')
    l.ground(229, 231, 14)
    l.ground(237, 239, 13)
    l.at(234, 17, 'D')
    l.ground(245, 247, 14)
    l.at(242, 17, 'F')
    l.drops([(230, 14), (238, 13), (246, 14)])
    l.ground(253, 261, 14)
    l.at(257, 14, 'G')
    l.rect(260, 261, 0, 33)
    l.save('2.txt')


# ---------------------------------------------------------------- Niveau 3 (ascension)
def level3():
    l = L(48, 72)
    l.rect(0, 1, 0, 71); l.rect(46, 47, 0, 71)
    l.rect(2, 45, 67, 71)                   # fond du canyon
    l.rect(2, 3, 18, 50)                    # paroi gauche épaisse
    l.put(5, 66, 'S'); l.put(8, 66, '!')
    def ledge(x1, x2, r, ch='#', th=2):
        l.rect(x1, x2, r, r + th - 1 if ch == '#' else r, ch)
    ledge(14, 19, 64); ledge(22, 27, 61); ledge(30, 37, 58); ledge(40, 45, 55)
    l.rect(33, 38, 66, 66, '^')
    l.put(20, 66, 'E'); l.put(34, 57, 'E'); l.put(32, 57, 'C')
    l.drops([(16, 62), (24, 59), (38, 55), (42, 53)]) if False else None
    for (x, r) in [(16, 63), (24, 60), (35, 57), (43, 54)]: l.put(x, r, '*')
    # cheminée droite
    l.rect(40, 41, 38, 52)
    ledge(30, 41, 38)
    l.put(43, 46, 'D'); l.put(44, 42, '*'); l.put(43, 50, '*')
    l.put(34, 37, 'C'); l.put(38, 37, 'E')
    # vers la gauche : papier
    ledge(24, 26, 36, 'c'); ledge(17, 19, 35, 'c')
    l.put(25, 35, '*'); l.put(18, 34, '*')
    ledge(4, 12, 34)
    l.put(11, 33, 'T')
    # secret : poche dans la paroi gauche
    l.put(3, 33, 'X'); l.put(3, 32, 'X'); l.put(2, 33, 'P'); l.put(2, 32, '.')
    # cheminée gauche
    l.rect(8, 9, 21, 31)
    ledge(8, 20, 20)
    l.put(6, 26, 'D'); l.put(5, 29, '*'); l.put(6, 23, '*')
    l.put(15, 19, 'C')
    # traversée vers la droite
    ledge(24, 26, 19, '='); l.put(29, 17, 'D'); l.put(32, 14, 'F')
    ledge(33, 35, 18, '='); ledge(38, 40, 16, 'c'); ledge(41, 45, 14)
    l.put(44, 13, 'T')
    for (x, r) in [(25, 18), (29, 15), (34, 17), (39, 15)]: l.put(x, r, '*')
    # montée finale
    ledge(35, 37, 11, '='); ledge(28, 30, 8, '=')
    ledge(10, 24, 5)
    l.put(36, 10, '*'); l.put(29, 7, '*')
    l.put(20, 4, 'E')
    l.put(13, 4, 'G')
    l.save('3.txt')


if __name__ == '__main__':
    level1(); level2(); level3()
    print('niveaux écrits dans', os.path.abspath(OUT))
