# Installer Soundflow sur votre iPhone, sans Mac

Vous avez un PC Windows et un iPhone. Pas de Mac. C'est jouable, et c'est
gratuit — il faut juste comprendre le problème avant de le contourner.

## Le problème, en deux phrases

Compiler une app iOS **exige macOS** : les outils d'Apple n'existent que là.
Et installer une app sur un iPhone **exige une signature** avec un identifiant
Apple, parce qu'iOS refuse d'exécuter du code qui ne vient de nulle part.

On règle les deux séparément :

| Le problème | La solution |
|---|---|
| Il faut un Mac pour compiler | GitHub en prête un, gratuitement, à chaque fois qu'on le demande |
| Il faut signer pour installer | Un outil Windows signe avec **votre** identifiant Apple, sur votre PC |

Résultat : vous n'avez jamais besoin de posséder un Mac.

---

## Les trois chemins possibles

| | Coût | Mise en place | Renouvellement | Pour qui |
|---|---|---|---|---|
| **A. Sideload depuis le PC** | gratuit | ~45 min | tous les **7 jours** (automatisable) | **Vous, pour commencer** |
| **B. Compte développeur + TestFlight** | 99 €/an | ~2 h | tous les 90 jours | si l'app devient votre lecteur quotidien |
| **C. Louer un Mac dans le cloud** | ~1 €/h | ~1 h | idem A ou B | si vous voulez aussi *développer* |

Ce guide détaille **le chemin A**. Les deux autres sont résumés à la fin.

---

# Chemin A — pas à pas

## Étape 1 · Récupérer le fichier de l'app

Tout se passe dans le navigateur de votre PC.

1. Ouvrez **https://github.com/YaronFEYYGAME/Soundflow**
2. Cliquez sur l'onglet **Actions**, en haut.
3. Dans la colonne de gauche, cliquez sur **« Compiler l'app (.ipa) »**.
4. Cliquez sur l'exécution la plus récente (la ligne du haut).

Vous voyez deux blocs : *Compiler et empaqueter* et *Tests unitaires*.

- **Pastille verte ✅** → parfait, continuez au point 5.
- **Pastille rouge ❌** → la compilation a échoué. Cliquez sur le bloc rouge,
  puis sur l'étape rouge à l'intérieur, pour voir le message d'erreur.
  Copiez-le-moi, on corrige. *C'est une possibilité réelle au premier essai :
  le code n'a jamais été compilé (aucun Mac n'était disponible pour l'écrire).*
- **Aucune exécution dans la liste** → cliquez sur le bouton
  **« Run workflow »** à droite, choisissez la branche
  `claude/iphone-mp3-player-local-855ws8`, et confirmez. Comptez 5 à 10 min.

5. Descendez tout en bas de la page, section **Artifacts**.
6. Cliquez sur **`Soundflow-ipa`** : un fichier ZIP se télécharge.
7. Décompressez-le (clic droit → *Extraire tout*). Vous obtenez
   **`Soundflow-unsigned.ipa`**. C'est l'app. Gardez-la sous la main.

> **Ce qu'est ce fichier :** un `.ipa` est simplement une archive contenant
> l'application. Le nôtre est *non signé* — inutilisable tel quel, et c'est
> normal : la signature est justement l'étape suivante.

## Étape 2 · Préparer le PC

Trois logiciels à installer, dans cet ordre.

**a) iTunes — impérativement la version du site d'Apple**

https://www.apple.com/itunes/download/win64

⚠️ **N'installez pas iTunes depuis le Microsoft Store.** La version du Store
est isolée du reste du système et ne fournit pas les composants dont l'outil
de signature a besoin. C'est l'erreur n°1 sur ce parcours. Si vous avez déjà
la version du Store, désinstallez-la d'abord.

**b) iCloud pour Windows — également depuis le site d'Apple**

Il apporte un composant (`Apple Application Support`) nécessaire au dialogue
avec l'iPhone.

**c) Sideloadly**

https://sideloadly.io — gratuit, Windows et macOS.

*Alternative recommandée si vous comptez garder l'app :* **AltStore**
(https://altstore.io). Plus long à mettre en place, mais il **renouvelle la
signature tout seul** quand le PC et l'iPhone sont sur le même Wi-Fi. Vous
n'aurez plus à y penser chaque semaine. Si vous êtes dans l'Union européenne,
vérifiez aussi ce que propose *AltStore PAL* — la réglementation européenne y
a ouvert des possibilités supplémentaires.

> **Une précaution d'honnêteté :** ces outils suivent les évolutions d'iOS avec
> parfois un temps de retard. Avant de vous lancer, jetez un œil à la page
> d'accueil de l'outil choisi pour confirmer qu'il gère bien la version d'iOS
> de votre iPhone 17. Si ce n'est pas le cas, passez directement au **chemin B**.

## Étape 3 · Préparer l'identifiant Apple

Sideloadly va demander votre identifiant Apple pour signer l'app. Deux
recommandations :

1. **Créez un identifiant Apple secondaire** (appleid.apple.com), dédié à cet
   usage. Rien ne vous y oblige, mais cela évite de confier votre compte
   principal à un outil tiers. Aucun achat, aucune carte bancaire n'est requis.
2. Si vous utilisez votre compte principal, générez un **mot de passe pour
   application** sur https://appleid.apple.com → *Connexion et sécurité* →
   *Mots de passe pour applications*. Vous le collerez à la place de votre vrai
   mot de passe.

## Étape 4 · Installer sur l'iPhone

1. Branchez l'iPhone au PC en USB.
2. Sur l'iPhone, une alerte **« Faire confiance à cet ordinateur ? »** apparaît
   → **Se fier**, puis saisissez votre code.
3. Ouvrez **Sideloadly**.
4. Votre iPhone doit apparaître dans le menu **Device**. *S'il n'apparaît pas :
   voir le dépannage plus bas.*
5. Glissez **`Soundflow-unsigned.ipa`** dans la fenêtre.
6. Saisissez votre identifiant Apple dans le champ **Apple account**.
7. Cliquez sur **Start**.
8. Un code de validation à six chiffres arrive sur votre iPhone → saisissez-le
   dans Sideloadly.
9. Attendez le message **« Done »** (une à trois minutes).

## Étape 5 · Autoriser l'app sur l'iPhone

L'icône Soundflow est apparue, mais elle refusera de s'ouvrir tant que vous
n'aurez pas déclaré lui faire confiance.

1. **Réglages** → **Général** → **VPN et gestion de l'appareil**
2. Sous *App du développeur*, appuyez sur la ligne correspondant à votre
   identifiant Apple.
3. **Se fier à…**, puis confirmez.

Ouvrez Soundflow. 🎉

## Étape 6 · Mettre vos MP3 dedans

C'est le moment le plus agréable, parce qu'il n'y a rien à installer :

1. Ouvrez l'app **Fichiers** de l'iPhone → onglet **Parcourir** →
   **Sur mon iPhone**.
2. Un dossier **Soundflow** s'y trouve.
3. Déposez-y vos MP3 : depuis iCloud Drive, depuis un partage, ou en branchant
   l'iPhone au PC (l'iPhone apparaît dans l'Explorateur Windows).
4. Dans Soundflow, tirez la liste vers le bas pour rafraîchir. Vos morceaux
   sont là.

Le bouton **+** en haut à droite fonctionne aussi, pour ajouter des fichiers un
par un.

---

## Le renouvellement tous les 7 jours

Avec un identifiant Apple gratuit, Apple limite la signature à **7 jours**.
Passé ce délai, l'app refuse de s'ouvrir (elle n'est pas supprimée, et **vos
morceaux, scores et sourdines restent intacts**).

Pour la réactiver : rebranchez l'iPhone et relancez Sideloadly sur le même
fichier. Deux minutes.

**Pour ne plus y penser**, deux options :

- **AltStore** renouvelle automatiquement dès que l'iPhone et le PC sont sur le
  même Wi-Fi, avec le PC allumé. C'est la raison principale de le préférer.
- **Le chemin B** (99 €/an) fait passer cette limite à un an.

Autres limites du compte gratuit, bonnes à connaître : **3 apps installées de
cette façon** au maximum, et **10 nouvelles apps par semaine**.

---

## Dépannage

**Sideloadly ne voit pas l'iPhone**
Presque toujours la version d'iTunes. Désinstallez celle du Microsoft Store,
installez celle du site Apple, redémarrez le PC. Essayez aussi un autre câble
(certains câbles ne transportent que l'alimentation) et un port USB direct,
sans hub.

**« Unable to verify app » / l'app ne s'ouvre pas**
L'étape 5 n'a pas été faite, ou les 7 jours sont écoulés.

**« Maximum number of apps reached »**
Vous avez atteint la limite de 3 apps. Supprimez-en une installée de la même
façon.

**Erreur mentionnant `provisioning profile` ou `entitlements`**
Peu probable ici : Soundflow n'utilise aucune capacité spéciale (pas de
notifications, pas de partage iCloud, pas d'App Groups). La lecture en
arrière-plan est une simple déclaration dans le fichier de configuration, pas
un privilège à demander à Apple. C'est précisément ce qui rend cette app
facile à installer avec un compte gratuit.

**La compilation GitHub échoue**
Envoyez-moi le message d'erreur de l'étape rouge. Le code n'ayant jamais été
compilé sur un vrai Mac, quelques ajustements au premier essai sont attendus.

---

## Chemin B — Compte développeur Apple + TestFlight (99 €/an)

Le confort maximal : l'app s'installe depuis **TestFlight**, comme n'importe
quelle app, sans PC, sans câble, et se met à jour toute seule.

Les grandes lignes :

1. Inscription au *Apple Developer Program* (99 €/an) sur developer.apple.com.
   Faisable depuis un PC ou l'iPhone.
2. Création d'une clé d'API dans *App Store Connect*.
3. Ajout de cette clé dans les **secrets** du dépôt GitHub.
4. Extension du fichier de compilation automatique pour qu'il signe et envoie
   la build à TestFlight.
5. Installation de l'app **TestFlight** sur l'iPhone, et c'est réglé.

Toujours **aucun Mac nécessaire** : c'est GitHub qui fait le travail macOS.
Chaque build reste valable 90 jours, et une nouvelle est produite à chaque
modification du code.

Dites-le-moi si vous voulez prendre cette voie : la partie technique (points 2
à 4) est un travail que je peux faire pour vous.

## Chemin C — Louer un Mac dans le cloud

Utile surtout si vous voulez **modifier** l'app vous-même, pas seulement
l'installer. Des services comme *MacinCloud*, *Scaleway* ou *MacStadium* louent
un Mac accessible à distance depuis votre PC, à l'heure ou au mois. Vous y
installez Xcode et suivez alors la procédure normale décrite dans le README.
