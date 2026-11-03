# Passer de Sideloadly à AltStore

**Ce que vous y gagnez :**

- **Plus de câble chaque semaine.** AltStore renouvelle la signature tout
  seul, par le Wi-Fi, dès que le PC est allumé.
- **Les mises à jour depuis l'iPhone.** Un lien à ouvrir dans Safari, deux
  taps dans AltStore.

**Durée :** une demi-heure, une seule fois. iTunes, iCloud, le mode
développeur et l'identifiant Apple sont déjà en place depuis Sideloadly.

**Principe :** on met d'abord vos fichiers (musique, réglages, fonds) à
l'abri dans un dossier de sauvegarde, on supprime l'ancienne app, on installe
AltStore puis Soundflow, et on remet les fichiers en place. Dans cet ordre,
pas de confusion entre deux icônes Soundflow, pas de souci avec la limite
de 3 apps, et aucun risque de supprimer la mauvaise.

Ce guide fonctionne **même si Soundflow est actuellement désactivé** (les
7 jours de Sideloadly écoulés) : vos fichiers restent accessibles depuis
l'app Fichiers.

> **Union européenne :** le site d'AltStore propose aussi *AltStore PAL*. Ce
> n'est pas le bon : PAL n'installe que des apps de développeurs enregistrés
> auprès d'Apple, pas un fichier `.ipa` personnel. Prenez **AltStore
> Classic**, avec AltServer.

> AltStore évolue et ces informations ont une date. Si un écran diffère,
> la documentation d'altstore.io fait foi.

---

## Étape 1 · Vérifier que vos réglages sont dans le dossier visible

Sur l'iPhone : app **Fichiers** → **Parcourir** → **Sur mon iPhone** →
dossier **Soundflow**.

Vous devez y voir vos MP3 **et** un fichier **`Soundflow-reglages.json`**
(plus, éventuellement, un dossier `Fonds`).

- **Le fichier `Soundflow-reglages.json` est là ?** Parfait, passez à
  l'étape 2.
- **Il n'y est pas, ou le dossier Soundflow n'apparaît pas ?** Votre
  iPhone a encore une ancienne version, qui range les scores et sourdines
  dans un endroit invisible. Il faut la remplacer une fois par la nouvelle
  **avant de continuer**, sinon ces réglages seraient perdus :
  1. sur le PC, téléchargez
     https://github.com/YaronFEYYGAME/Soundflow/releases/download/derniere-version/Soundflow.ipa ;
  2. installez-le avec **Sideloadly**, comme d'habitude ;
  3. si iOS affiche « Développeur non approuvé » : *Réglages → Général →
     VPN et gestion de l'appareil* → « iPhone Developer… » → **Se fier** ;
  4. **ouvrez Soundflow une fois**, puis revérifiez : le fichier doit
     maintenant être là.

## Étape 2 · Mettre vos fichiers à l'abri

Toujours dans **Fichiers → Sur mon iPhone** :

1. Revenez au niveau **Sur mon iPhone** (la liste des dossiers d'apps).
2. Appui long dans une zone vide → **Nouveau dossier** → nommez-le
   **`Sauvegarde Soundflow`**.
3. Ouvrez le dossier **Soundflow**.
4. **Sélectionner** (en haut à droite) → **Tout sélectionner** → bouton
   **⋯** en bas → **Déplacer** → choisissez **Sauvegarde Soundflow** →
   **Déplacer**.
5. **Vérifiez** : `Sauvegarde Soundflow` contient vos MP3,
   `Soundflow-reglages.json` (et `Fonds` si vous en aviez). Le dossier
   Soundflow, lui, est maintenant vide.

« Déplacer » ne duplique rien : c'est instantané et ne demande aucun espace
libre, même pour une grosse bibliothèque.

✋ Ne passez à l'étape 3 que si la sauvegarde contient bien tout.

## Étape 3 · Supprimer l'ancien Soundflow

Écran d'accueil → appui long sur l'icône **Soundflow** → **Supprimer l'app**
→ **Supprimer l'app**.

Sans risque : son dossier est vide, tout est dans la sauvegarde. Cette
suppression libère aussi une place dans la limite des 3 apps.

## Étape 4 · Installer AltServer sur le PC

1. Sur **https://altstore.io**, téléchargez **AltServer pour Windows**, puis
   installez-le.
2. Lancez-le. Pas de fenêtre : il se place dans la **zone de notification**,
   près de l'horloge (parfois derrière la petite flèche `^`).
3. Si Windows demande d'autoriser AltServer dans le pare-feu : **acceptez
   pour les réseaux privés**.
4. Activez la **synchronisation Wi-Fi**, indispensable au renouvellement
   sans câble :
   - iPhone branché, ouvrez **iTunes** ;
   - cliquez sur la petite **icône d'iPhone** en haut à gauche ;
   - onglet **Résumé** → section *Options* → cochez **« Synchroniser avec
     cet iPhone en Wi-Fi »** → **Appliquer**.

## Étape 5 · Installer AltStore sur l'iPhone

1. iPhone **branché et déverrouillé**.
2. Clic sur l'icône d'AltServer → **Install AltStore** → votre iPhone.
3. Identifiant Apple : **le même que pour Sideloadly**, puis son mot de
   passe. Un code à 6 chiffres peut être demandé.
4. Si AltServer signale qu'un certificat existe déjà et propose de le
   révoquer, **acceptez** : il ne servait qu'à l'ancien Soundflow, supprimé
   à l'étape 3.
5. Attendez la notification de fin (une à deux minutes). L'icône
   **AltStore** apparaît sur l'iPhone.
6. Si l'iPhone refuse de l'ouvrir : *Réglages → Général → VPN et gestion
   de l'appareil* → « iPhone Developer… » → **Se fier** (connexion Internet
   nécessaire). Le mode développeur, lui, est déjà actif.

## Étape 6 · Installer Soundflow avec AltStore

Tout se passe sur l'iPhone.

1. **Safari** →
   **https://github.com/YaronFEYYGAME/Soundflow/releases/download/derniere-version/Soundflow.ipa**
   → **Télécharger**.
2. **AltStore** → onglet **Mes apps** → **+** en haut à gauche →
   **Téléchargements** → **Soundflow.ipa**.
3. Attendez la fin de l'installation : l'icône Soundflow réapparaît.
4. **Ouvrez Soundflow une fois** (il est vide, c'est normal), puis
   revenez à l'écran d'accueil. Cette ouverture crée son dossier dans
   l'app Fichiers.

## Étape 7 · Remettre vos fichiers en place

1. **Fichiers → Sur mon iPhone → Sauvegarde Soundflow**.
2. **Sélectionner** → **Tout sélectionner** → **⋯** → **Déplacer** →
   dossier **Soundflow** → **Déplacer**.
3. ⚠️ Si l'iPhone demande quoi faire de **`Soundflow-reglages.json`** ou du
   dossier **`Fonds`** : choisissez **Remplacer**. Surtout pas « Garder les
   deux » : Soundflow resterait sur des réglages vides.
4. Ouvrez **Soundflow** : musique, scores et sourdines sont là.
5. Le dossier `Sauvegarde Soundflow`, désormais vide, peut être supprimé.

*Si vous utilisiez un fond personnalisé, re-choisissez-le d'un tap dans
l'onglet Fonds : les images sont revenues, seul le choix est à refaire.*

## Étape 8 · Régler le renouvellement automatique

1. **AltStore → Mes apps** : Soundflow y figure, avec son délai
   d'expiration (« 7 jours »).
2. **Réglages de l'iPhone → AltStore** : **Actualisation en arrière-plan**
   doit être activée.
3. **Sur le PC**, AltServer doit tourner. Pour ne plus y penser, lancez-le
   au démarrage de Windows : si son menu propose une option de lancement
   automatique, cochez-la ; sinon, **Windows + R** → `shell:startup` →
   **OK**, et glissez un raccourci d'AltServer dans le dossier qui s'ouvre.

**Ensuite, rien à faire.** Quand l'expiration approche et que l'iPhone et
le PC (allumé, AltServer lancé) sont sur le même Wi-Fi, AltStore renouvelle
seul.

- **Forcer un renouvellement** (avant un départ, par exemple) : AltStore →
  Mes apps → **Tout actualiser**, PC allumé, même Wi-Fi.
- **Si les 7 jours passent malgré tout :** rien n'est perdu. L'app refuse
  de s'ouvrir jusqu'au prochain renouvellement ; musique et réglages
  restent intacts.

---

## Mettre à jour Soundflow, désormais

Depuis l'iPhone, sans le PC :

1. Safari →
   **https://github.com/YaronFEYYGAME/Soundflow/releases/download/derniere-version/Soundflow.ipa**
   → Télécharger.
2. AltStore → Mes apps → **+** → Téléchargements → **Soundflow.ipa**.

AltStore remplace l'app sur place : tout est conservé, et le compteur des
7 jours repart à zéro.

*Astuce :* ajoutez ce lien à l'écran d'accueil (Safari → Partager → « Sur
l'écran d'accueil »).

Ce lien pointe toujours vers la dernière version **ayant passé les tests**.

---

## Dépannage

**AltServer ne voit pas l'iPhone**
iTunes doit venir du site d'Apple (pas du Microsoft Store). Vérifiez que
l'iPhone est déverrouillé et essayez un autre câble.

**« Could not find AltServer » lors d'un renouvellement**
PC éteint, AltServer non lancé, Wi-Fi différents, ou synchronisation Wi-Fi
non cochée dans iTunes (étape 4). Dernier suspect : le pare-feu Windows.

**« Maximum number of apps »**
La limite des 3 apps est atteinte : supprimez une autre app installée par
Sideloadly ou AltStore.

**Erreur mentionnant « anisette » ou identifiant Apple refusé**
Mettez AltServer à jour depuis altstore.io, puis réessayez.

**Soundflow est vide après l'étape 7**
Probablement « Garder les deux » sur le fichier de réglages. Dans
Fichiers, dossier Soundflow : supprimez `Soundflow-reglages.json`, puis
renommez `Soundflow-reglages 2.json` en `Soundflow-reglages.json`.
Revenez dans Soundflow : il le relira.

**Le dossier Soundflow n'apparaît pas dans Fichiers à l'étape 7**
Ouvrez Soundflow une fois (étape 6, point 4), puis revenez dans Fichiers.
