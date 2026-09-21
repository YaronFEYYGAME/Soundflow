# La lecture aléatoire intelligente

Code : [`Soundflow/Domain/SmartShuffle.swift`](../Soundflow/Domain/SmartShuffle.swift)
Tests : [`SoundflowTests/SmartShuffleTests.swift`](../SoundflowTests/SmartShuffleTests.swift)

Un vrai tirage au sort uniforme donne une mauvaise expérience d'écoute : il
rejoue le même morceau deux fois de suite une fois sur *N*, et il ignore
complètement vos goûts. L'algorithme d'ici corrige les deux, en cinq étapes.

## Étape 1 — La sourdine, filtre absolu

Les morceaux en sourdine sont retirés avant toute autre considération. Ils ne
peuvent pas être tirés au sort, quel que soit leur score. Ils restent
parfaitement jouables en tapant dessus dans la liste : la sourdine ne concerne
que le hasard.

## Étape 2 — L'interdiction stricte (« cooldown »)

Les **40 % de la bibliothèque les plus récemment écoutés** sont
temporairement interdits, avec un plafond de 30 morceaux.

| Bibliothèque | Morceaux interdits de rejeu |
|---|---|
| 2 titres | 1 |
| 10 titres | 4 |
| 50 titres | 20 |
| 500 titres | 30 (plafond) |

Deux garde-fous :

- l'interdiction ne peut jamais couvrir toute la bibliothèque (il reste
  toujours au moins un morceau jouable) ;
- si le cas limite se produit quand même — bibliothèque minuscule, ou
  historique saturé de titres depuis mis en sourdine — la contrainte est
  relâchée, **sauf** l'interdiction du morceau qui vient de jouer. C'est la
  promesse qu'on ne casse jamais.

## Étape 3 — La pénalité douce

Passé l'interdiction stricte, un morceau ne redevient pas instantanément aussi
probable que les autres. Il reste pénalisé sur une fenêtre 2,5 fois plus
longue, avec une pénalité qui s'efface progressivement : de ×0,2 juste après
sa sortie de quarantaine, à ×1 une fois bien oublié.

C'est cette étape qui donne l'impression que « ça tourne bien », sans jamais
bloquer un titre de façon rigide.

## Étape 4 — Le score favori

Le score, de −2 à +2, devient un multiplicateur de probabilité :

| Score | Poids | Lecture |
|---:|---:|---|
| +2 | ×3 | trois fois plus probable qu'un morceau neutre |
| +1 | ×2 | deux fois plus probable |
| 0 | ×1 | fréquence normale |
| −1 | ×0,5 | deux fois moins probable |
| −2 | ×0,33 | trois fois moins probable |

L'augmentation est donc bien **proportionnelle au score**, comme demandé. Un
score négatif raréfie sans jamais exclure : l'exclusion totale est le rôle de
la sourdine, qui est un geste explicite et réversible.

## Étape 5 — Le tirage

Chaque candidat reçoit un poids final (score × pénalité de récence), et le
tirage se fait proportionnellement à ces poids.

---

## Ce que ça donne en pratique

Mesures sur 30 000 lectures simulées, bibliothèque de 30 titres, un morceau
noté +2 et un noté −2, tous les autres neutres :

| Morceau | Nombre de lectures |
|---|---:|
| noté **+2** | ~1 530 |
| neutre | ~1 000 |
| noté **−2** | ~485 |

Le rapport n'est pas exactement 3 / 1 / 0,33 : l'interdiction stricte plafonne
mécaniquement un morceau très favorisé (il ne peut pas repasser plus d'une
fois tous les 13 titres). C'est voulu — un morceau adoré ne doit pas devenir
lassant.

## Pourquoi c'est testé aussi sérieusement

Un bug dans du code aléatoire ne se voit pas. Personne ne peut écrire un
rapport de bug utile à partir de « il m'a semblé qu'il répétait ». Les tests
rejouent donc des dizaines de milliers de tirages avec un générateur
**déterministe** (`SeededRandomNumberGenerator`) et vérifient :

- aucune répétition immédiate, sur des bibliothèques de 2 à 50 titres et
  quatre graines différentes ;
- aucun retour avant la fin de l'interdiction stricte, sur 2 000 lectures ;
- aucun morceau en sourdine tiré, sur 3 000 lectures ;
- les fréquences croissent bien de −2 vers +2, sur 40 000 lectures ;
- les cas limites : bibliothèque vide, un seul titre, tout en sourdine.

Un générateur déterministe est indispensable : un test qui échoue une fois sur
cent est pire que pas de test du tout, parce qu'on finit par l'ignorer.
