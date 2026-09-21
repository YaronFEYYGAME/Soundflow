# Décisions techniques, expliquées

Ce document existe parce que vous découvrez Swift : chaque choix structurant
y est justifié, avec l'alternative écartée et la raison.

---

## 1. Swift + SwiftUI, et rien d'autre

**Retenu :** Swift, SwiftUI, AVFoundation — uniquement des briques Apple.
**Écarté :** React Native, Flutter, ou une bibliothèque audio tierce.

Une app de lecture audio passe son temps dans trois API Apple : la session
audio, le lecteur, et l'écran verrouillé. Tout cadre multiplateforme ajoute
une couche d'adaptation par-dessus, qui traîne toujours du retard sur les
nouveautés d'iOS et rajoute une dépendance à maintenir. Pour un besoin
« lecture fiable en arrière-plan », c'est du risque sans contrepartie.

**Zéro dépendance externe** est un choix assumé : rien à mettre à jour, rien
qui casse quand un projet GitHub est abandonné.

*Contrepartie :* l'app est iPhone/iPad seulement. Si Android devenait un
objectif, il faudrait réécrire l'interface — mais la logique de `Domain/` est
du Swift pur, facilement transposable.

---

## 2. `AVPlayer` plutôt que `AVAudioPlayer`

**Retenu :** `AVPlayer`.
**Écarté :** `AVAudioPlayer`, plus simple.

`AVAudioPlayer` ne lit que des fichiers déjà intégralement présents sur le
disque. `AVPlayer` lit indifféremment un fichier local et une URL réseau, avec
gestion du tampon.

Comme l'ajout d'une source en ligne est un objectif annoncé, choisir
`AVAudioPlayer` aujourd'hui signifierait réécrire toute la lecture le jour
venu. Le surcoût de complexité de `AVPlayer` (observation d'état via KVO) est
payé une fois, ici, dans un seul fichier.

---

## 3. Un fichier JSON, pas une base de données

**Retenu :** un fichier JSON dans `Application Support`.
**Écarté :** SwiftData, Core Data, SQLite.

Les données à conserver tiennent en quelques dizaines d'octets par morceau :
un score, un booléen, et une liste d'identifiants. Aucune requête complexe,
aucune relation, aucun besoin de recherche indexée.

Une base de données apporterait ici des migrations de schéma, un risque de
corruption, des verrous — c'est-à-dire de nouveaux modes de panne, pour un
bénéfice nul. **Moins de pièces mobiles, moins de bugs.**

Trois précautions rendent ce fichier sûr :

1. **écriture atomique** — le système écrit un fichier temporaire puis le
   renomme ; une app tuée en pleine sauvegarde ne corrompt rien ;
2. **numéro de version croissant** — une sauvegarde partie plus tôt ne peut
   pas écraser une plus récente arrivée entre-temps ;
3. **démarrage tolérant** — un fichier illisible fait repartir l'app sur des
   réglages neutres au lieu de planter.

*Quand revoir ce choix :* si l'on ajoutait des playlists, des statistiques
d'écoute détaillées, ou une bibliothèque de plusieurs dizaines de milliers de
titres.

---

## 4. Les fichiers dans `Documents`, visibles de l'extérieur

**Retenu :** `Documents/`, exposé via l'app Fichiers et le Finder.
**Écarté :** un dossier privé, import uniquement depuis l'app.

Deux réglages dans le projet (`UIFileSharingEnabled` et
`LSSupportsOpeningDocumentsInPlace`) suffisent à faire apparaître le dossier
Soundflow dans l'app Fichiers et dans le Finder du Mac. Transférer 300 MP3
devient un glisser-déposer, au lieu de 300 passages par un sélecteur de
fichiers.

C'est une fonctionnalité importante obtenue sans écrire une seule ligne de
code — et elle rend aussi le débogage bien plus simple.

---

## 5. `@Observable` plutôt que `ObservableObject`

**Retenu :** la macro `@Observable` (iOS 17+).
**Écarté :** `ObservableObject` + `@Published`.

C'est le mécanisme recommandé par Apple depuis iOS 17. Il redessine
uniquement les vues qui lisent réellement une propriété modifiée, là où
`@Published` notifie tout le monde. Sur une liste de plusieurs centaines de
morceaux mise à jour deux fois par seconde pendant la lecture, la différence
est visible.

La mécanique interne (jetons d'observation, piles de navigation, compteurs)
est marquée `@ObservationIgnored` : aucune raison de redessiner un écran
parce qu'un compteur privé a bougé.

*Contrepartie :* iOS 17 minimum. Sur un projet neuf en 2026, ce n'est pas une
contrainte.

---

## 6. `iOS 17` comme version minimale

Permet `@Observable`, `ContentUnavailableView`, les API asynchrones modernes
d'AVFoundation, et `.onChange` à deux paramètres. Descendre à iOS 16
obligerait à des contournements dans presque tous les fichiers, pour gagner
une fraction négligeable du parc d'appareils.

---

## 7. Mode langage Swift 5, pas Swift 6

**Retenu :** `SWIFT_VERSION = 5.0`.

Le code est écrit proprement du point de vue de la concurrence (acteurs,
`@MainActor`, `Sendable`), mais le mode Swift 6 transforme en **erreurs** un
grand nombre de situations que les API Apple elles-mêmes n'ont pas encore
toutes rattrapées. Pour un premier projet, cela signifie des heures passées à
combattre le compilateur au lieu d'écrire l'app.

Le passage à Swift 6 sera simple plus tard : la structure est déjà la bonne.

---

## 8. Un acteur pour les fichiers

`LocalAudioSource` est un `actor`. Swift garantit alors qu'un seul morceau de
code à la fois touche au système de fichiers. Cela élimine par construction
toute une famille de bugs difficiles à reproduire : un import lancé pendant un
scan, deux imports simultanés, une suppression au milieu d'une lecture de
dossier.

---

## 9. Les décisions « anti-crash »

L'exigence était « aucun crash pendant l'écoute ». Concrètement :

| Risque | Traitement |
|---|---|
| Fichier corrompu ou format non lu | Vérifié (`isPlayable`) avant d'entrer dans la bibliothèque ; en lecture, on passe au suivant |
| Plusieurs fichiers illisibles d'affilée | Arrêt au bout de 5 échecs consécutifs, avec un message — plutôt qu'une boucle infinie qui vide la batterie |
| Casque débranché | Pause immédiate (sinon la musique part dans le haut-parleur) |
| Appel téléphonique, Siri, alarme | Pause automatique, puis reprise si le système l'autorise |
| Services audio réinitialisés par iOS | Session reconfigurée, lecture mise en pause proprement |
| Morceau en cours supprimé | Lecture arrêtée proprement au lieu de jouer dans le vide |
| Fichier de réglages corrompu | Démarrage sur des réglages neutres |
| Tous les morceaux en sourdine | Message explicite, plutôt qu'un bouton sans effet |

Aucune de ces situations n'utilise `try!` ou `!` sur une valeur optionnelle :
il n'y a, volontairement, aucun point de plantage forcé dans le code.

---

## 10. Les deux réglages toujours visibles

L'exigence était « un ou deux gestes maximum, jamais un menu caché ».

- **Dans la liste** : deux petits boutons `−` / `+` autour du score, et un
  bouton de sourdine, affichés en permanence sur chaque ligne. Un tap = un
  cran.
- **Sur l'écran de lecture** : un sélecteur à cinq positions (−2 … +2) — un
  tap suffit pour atteindre n'importe quelle valeur — et un bouton de sourdine
  de grande taille.

Détail d'implémentation qui compte : les boutons d'une ligne de liste doivent
utiliser `.buttonStyle(.borderless)`. Sans cela, iOS traite la ligne entière
comme un seul bouton et les contrôles deviennent inutilisables — un piège
classique de SwiftUI.

La suppression, elle, reste sur un balayage latéral : c'est une action rare et
irréversible, on ne la met pas sous le doigt.
