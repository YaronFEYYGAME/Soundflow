# Soundflow

Lecteur MP3 pour iPhone, pensé pour une seule chose : écouter longtemps, au
casque, sans y penser.

- **Fichiers locaux** déposés sur l'appareil (aucun compte, aucun réseau).
- **Lecture aléatoire intelligente** : jamais deux fois le même morceau
  d'affilée, pas de répétition rapprochée, et une fréquence d'apparition
  pilotée par un score favori.
- **Score favori de −2 à +2** et **mise en sourdine** par morceau, tous deux
  accessibles en un ou deux taps, jamais cachés dans un menu.
- **File d'attente** : un balayage vers la droite sur un morceau l'ajoute à
  la suite ; la file se consulte et se réordonne depuis l'écran de lecture.
- **Fonds personnalisés** (images ou GIF) qui remplacent les pochettes,
  écran verrouillé compris.
- **Lecture en arrière-plan** stable : écran verrouillé, centre de contrôle,
  boutons du casque, reprise après un appel téléphonique.

Pas de playlists, pas d'égaliseur, pas de statistiques. C'est volontaire.

Toute la bibliothèque — musique, réglages (`Soundflow-reglages.json`) et
fonds (dossier `Fonds`) — tient dans un seul dossier, visible dans l'app
Fichiers. La sauvegarder ou la transférer, c'est déplacer ce dossier.

---

## Installer l'app sur un iPhone

**Vous n'avez pas de Mac ?** C'est le cas le plus courant, et c'est prévu :
suivez **[`docs/INSTALLER-SANS-MAC.md`](docs/INSTALLER-SANS-MAC.md)**. GitHub
compile l'app sur un Mac prêté gratuitement, et vous l'installez depuis un PC
Windows.

## Démarrer sur un Mac

Prérequis : **Xcode 16 ou plus récent** (gratuit sur le Mac App Store) et un
iPhone sous **iOS 17 ou plus récent**.

1. Ouvrez `Soundflow.xcodeproj` (double-clic).
2. En haut de la fenêtre, choisissez la destination : un simulateur d'iPhone,
   ou votre iPhone s'il est branché.
3. Onglet **Signing & Capabilities** du projet → cochez *Automatically manage
   signing* et choisissez votre équipe (votre identifiant Apple suffit pour
   installer sur votre propre appareil). Changez aussi le *Bundle Identifier*
   `com.example.Soundflow` pour quelque chose qui vous appartient, par exemple
   `com.votrenom.Soundflow`.
4. Appuyez sur **⌘R** pour lancer, **⌘U** pour exécuter les tests.

### Mettre des MP3 dedans

Deux façons, au choix :

- **Depuis l'app** : bouton **+** en haut à droite, puis choisissez vos
  fichiers dans l'app Fichiers.
- **Depuis un Mac** : branchez l'iPhone, ouvrez le Finder, onglet *Fichiers*,
  et glissez vos MP3 sur le dossier *Soundflow*. L'app les détecte au
  prochain passage au premier plan. C'est la méthode la plus rapide pour une
  grosse bibliothèque.

---

## Ce qu'il y a dans le dépôt

```
Soundflow/
├── App/          Démarrage de l'app et assemblage des objets partagés
├── Domain/       Modèles et règles métier — aucun code Apple spécifique
├── Data/         Accès aux fichiers et sauvegarde des réglages
├── Playback/     Moteur audio, session audio, écran verrouillé
└── UI/           Écrans SwiftUI
SoundflowTests/   Tests unitaires (surtout l'algorithme aléatoire)
docs/             Explications détaillées
```

## Pour aller plus loin

- [`docs/INSTALLER-SANS-MAC.md`](docs/INSTALLER-SANS-MAC.md) — installer
  l'app depuis un PC Windows, pas à pas.
- [`docs/PASSER-A-ALTSTORE.md`](docs/PASSER-A-ALTSTORE.md) — passer de
  Sideloadly à AltStore sans rien perdre.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — comment les couches sont
  séparées, et **comment ajouter une source iCloud ou Dropbox** plus tard.
- [`docs/ALGORITHME-ALEATOIRE.md`](docs/ALGORITHME-ALEATOIRE.md) — le
  fonctionnement exact de la lecture aléatoire, avec des chiffres.
- [`docs/DECISIONS-TECHNIQUES.md`](docs/DECISIONS-TECHNIQUES.md) — chaque
  choix important, expliqué et justifié.
