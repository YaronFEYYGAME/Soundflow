# Passer de Sideloadly à AltStore

**Ce que vous y gagnez :**

- **Plus de câble chaque semaine.** AltStore renouvelle la signature tout
  seul, par le Wi-Fi, dès que le PC est allumé.
- **Les mises à jour depuis l'iPhone.** Un lien à ouvrir dans Safari, deux
  taps dans AltStore. Plus besoin du PC pour installer une nouvelle version.

**Est-ce compliqué ?** Non. Comptez une demi-heure, une seule fois. Le plus
dur est déjà fait : iTunes, iCloud, le mode développeur et l'identifiant
Apple sont en place depuis Sideloadly.

**Ce qu'il faut savoir avant de commencer.** AltStore installera très
probablement Soundflow comme une **nouvelle** app, à côté de l'ancienne (il
lui donne un identifiant interne légèrement différent). Vous aurez donc
brièvement deux icônes Soundflow, et la nouvelle sera vide. L'étape 4
transfère votre musique, vos scores et vos sourdines de l'une à l'autre. En
suivant les étapes dans l'ordre, **rien n'est perdu**.

> **Si vous êtes dans l'Union européenne :** le site d'AltStore propose
> aussi *AltStore PAL*. Ce n'est pas celui qu'il vous faut : PAL n'installe
> que des apps publiées par des développeurs enregistrés auprès d'Apple, pas
> un fichier `.ipa` personnel. Prenez **AltStore Classic**, avec AltServer.

> **Une précaution d'honnêteté :** AltStore évolue, et mes informations ont
> une date. Si un écran ne ressemble pas à ce qui est décrit ici, la
> documentation officielle sur altstore.io fait foi.

---

## Étape 0 · Une dernière mise à jour avec Sideloadly

La nouvelle version de Soundflow range vos réglages dans le dossier visible
depuis l'app Fichiers — c'est ce qui permettra de les transférer. Il faut
donc qu'elle ait tourné **au moins une fois** dans l'app actuelle.

1. Téléchargez la nouvelle version (sur le PC) :
   **https://github.com/YaronFEYYGAME/Soundflow/releases/download/derniere-version/Soundflow.ipa**
2. Installez-la avec Sideloadly, comme d'habitude.
3. Ouvrez Soundflow une fois. Vérifiez que vos scores et vos sourdines sont
   toujours là.

Pour contrôler : app **Fichiers** → *Sur mon iPhone* → **Soundflow**. Un
fichier `Soundflow-reglages.json` doit maintenant s'y trouver, à côté de vos
MP3. Ce sont vos réglages.

## Étape 1 · Installer AltServer sur le PC

1. Sur **https://altstore.io**, téléchargez **AltServer pour Windows**, puis
   installez-le.
2. Lancez-le. Il n'ouvre pas de fenêtre : il se loge dans la **zone de
   notification**, près de l'horloge (parfois caché derrière la petite
   flèche `^`).
3. Activez la **synchronisation Wi-Fi** — c'est elle qui permettra le
   renouvellement sans câble :
   - iPhone branché, ouvrez **iTunes** ;
   - cliquez sur la petite icône d'iPhone en haut à gauche ;
   - onglet **Résumé** → section *Options* → cochez **« Synchroniser avec cet
     iPhone en Wi-Fi »** → **Appliquer**.

## Étape 2 · Installer AltStore sur l'iPhone

1. iPhone branché et **déverrouillé**.
2. Clic sur l'icône d'AltServer → **Install AltStore** → votre iPhone.
3. Identifiant Apple : **le même compte secondaire que pour Sideloadly**,
   puis son mot de passe.
4. Attendez la notification de fin (une à deux minutes).
5. Si l'iPhone refuse d'ouvrir AltStore : *Réglages → Général → VPN et
   gestion de l'appareil* → votre identifiant → **Se fier**. (Le mode
   développeur, lui, est déjà actif.)

## Étape 3 · Installer Soundflow avec AltStore

Tout se passe sur l'iPhone.

1. Ouvrez **Safari** et allez sur :
   **https://github.com/YaronFEYYGAME/Soundflow/releases/download/derniere-version/Soundflow.ipa**
   → **Télécharger**.
2. Ouvrez **AltStore** → onglet **Mes apps** → bouton **+** en haut à
   gauche.
3. Choisissez **Téléchargements** → **Soundflow.ipa**.
4. Attendez la fin de l'installation.

Regardez maintenant votre écran d'accueil :

- **Une seule icône Soundflow, avec votre musique dedans ?** AltStore a
  remplacé l'app sur place. Tout est conservé : passez directement à
  l'étape 6.
- **Deux icônes Soundflow ?** C'est le cas prévu. Passez à l'étape 4.

> **Limite des 3 apps :** avec un identifiant Apple gratuit, trois apps
> installées de cette façon au maximum. AltStore + l'ancien Soundflow + le
> nouveau = 3 : ça passe tout juste. L'étape 5 libère une place.

## Étape 4 · Transférer musique et réglages

1. Ouvrez le **nouveau** Soundflow (celui qui est vide), puis quittez-le.
   Cette ouverture crée son dossier dans l'app Fichiers.
2. App **Fichiers** → *Sur mon iPhone*. Vous voyez **deux dossiers
   Soundflow**.
3. Ouvrez celui qui **contient vos MP3**.
4. **Sélectionner** (en haut à droite) → **Tout sélectionner** → bouton
   **⋯** en bas → **Déplacer**.
5. Choisissez l'**autre** dossier Soundflow (celui sans MP3) → **Déplacer**.
6. Si l'iPhone demande quoi faire de `Soundflow-reglages.json` : choisissez
   **Remplacer**. *C'est important* — « Garder les deux » laisserait le
   nouveau Soundflow sur des réglages vides.

« Déplacer » plutôt que « Copier » : vos MP3 ne sont pas dupliqués, donc
aucun besoin d'espace libre supplémentaire, même pour une grosse
bibliothèque.

Ouvrez le nouveau Soundflow : votre musique, vos scores et vos sourdines
sont là. Si l'app était restée ouverte en arrière-plan, elle relit ses
réglages d'elle-même en revenant au premier plan.

*Les fonds personnalisés, s'il y en a, se déplacent avec le reste (dossier
`Fonds`). Il faudra seulement re-choisir celui que vous utilisiez : un tap
dans l'onglet Fonds.*

## Étape 5 · Supprimer l'ancien Soundflow

Ouvrez les deux apps Soundflow. Celle qui affiche votre musique est la
bonne. **Supprimez l'autre, celle qui est vide** : appui long sur son icône →
*Supprimer l'app*.

⚠️ Ne vous trompez pas de sens : supprimer une app efface aussi son dossier.
Si les deux affichent encore de la musique (vous avez copié au lieu de
déplacer), gardez celle qui figure dans **AltStore → Mes apps**.

## Étape 6 · Vérifier le renouvellement automatique

1. **AltStore → Mes apps** : Soundflow y figure, avec son délai
   d'expiration (« 7 jours »).
2. **Réglages de l'iPhone → AltStore** : **Actualisation en arrière-plan**
   doit être activée.
3. **Sur le PC**, AltServer doit tourner. Pour ne pas avoir à y penser,
   lancez-le au démarrage de Windows : si son menu propose une option de
   lancement automatique, cochez-la ; sinon, touches **Windows + R** →
   tapez `shell:startup` → **OK**, et glissez un raccourci d'AltServer dans
   le dossier qui s'ouvre.

**Comment se passe le renouvellement ensuite :** quand l'expiration
approche, et que l'iPhone et le PC (allumé, AltServer lancé) sont sur le
même Wi-Fi, AltStore renouvelle seul, en arrière-plan. Vous n'avez rien à
faire.

**Pour forcer un renouvellement** (avant un départ en vacances, par
exemple) : AltStore → Mes apps → **Tout actualiser**, PC allumé et même
Wi-Fi.

Et si les 7 jours passent malgré tout, rien n'est perdu : l'app refuse
simplement de s'ouvrir jusqu'au prochain renouvellement. Musique et
réglages restent intacts.

---

## Mettre à jour Soundflow, désormais

Chaque fois que je publie une nouvelle version :

1. Sur l'iPhone, Safari →
   **https://github.com/YaronFEYYGAME/Soundflow/releases/download/derniere-version/Soundflow.ipa**
   → Télécharger.
2. AltStore → Mes apps → **+** → Téléchargements → **Soundflow.ipa**.

AltStore remplace l'app sur place : **tout est conservé**, et le compteur des
7 jours repart à zéro au passage.

*Astuce :* ajoutez ce lien à vos favoris Safari, ou à l'écran d'accueil
(bouton Partager → « Sur l'écran d'accueil »).

Ce lien pointe toujours vers la dernière version **ayant passé les tests**.
Une version dont la compilation ou les tests échouent n'y est jamais publiée.

---

## Dépannage

**AltServer ne voit pas l'iPhone**
Même cause qu'avec Sideloadly : presque toujours la version d'iTunes (celle
du Microsoft Store ne convient pas). Vérifiez aussi que l'iPhone est
déverrouillé.

**« Could not find AltServer » lors d'un renouvellement**
Le PC est éteint, AltServer n'est pas lancé, les deux appareils ne sont pas
sur le même Wi-Fi, ou la synchronisation Wi-Fi n'est pas cochée dans iTunes
(étape 1). Dernier suspect : le pare-feu Windows, qui peut demander
d'autoriser AltServer au premier lancement — acceptez pour les réseaux
privés.

**« Maximum number of apps »**
La limite des 3 apps est atteinte. Supprimez l'ancien Soundflow (étape 5),
ou toute autre app installée par Sideloadly ou AltStore.

**Erreur mentionnant « anisette » ou refus de l'identifiant Apple**
Mettez AltServer à jour depuis altstore.io, puis réessayez. Ce type d'erreur
vient en général d'un changement côté Apple, que la dernière version
d'AltServer prend en compte.

**Le nouveau Soundflow est vide après l'étape 4**
Vous avez sans doute choisi « Garder les deux » pour le fichier de
réglages. Dans l'app Fichiers, supprimez `Soundflow-reglages.json`, puis
renommez `Soundflow-reglages 2.json` en `Soundflow-reglages.json`. Revenez
dans Soundflow : il le relira.
