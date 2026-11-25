# TontiNet, jalon J1 : explication complète du travail réalisé

> Document d'accompagnement du dossier de conception. Il part de zéro : aucune connaissance préalable du
> projet ni du cours n'est supposée.

## 1. Le contexte : qu'est-ce qui était demandé ?

Le cours **« Systèmes répartis et mobiles »** (EC 1INF2324, Master 2, UAC/IFRI, Dr. Emery ASSOGBA) a un
**projet d'équipe fil rouge, TontiNet**, découpé en jalons (J1, J2…). La page 40 des notes de cours donne
le travail du **jalon J1** : rédiger un **dossier de conception de 3 à 5 pages** qui contient quatre choses :

1. l'**architecture**, avec une figure ;
2. pour **chaque échange** entre composants, le choix entre **REST, gRPC ou MQTT**, justifié ;
3. le **format des messages** ;
4. la **sémantique d'appel** de chaque opération.

Ce dossier sera noté et relu par une autre équipe en séance (relecture croisée). Il ne contient pas de
code : c'est le **plan** de l'application avant de la construire.

Le livrable est [J1-dossier-conception.pdf](J1-dossier-conception.pdf) (7 pages : page de garde, sommaire,
5 pages de contenu). Sa source LaTeX est [J1-dossier-conception.tex](J1-dossier-conception.tex).

---

## 2. TontiNet, c'est quoi ?

Une **tontine** est une épargne collective tournante. Prenons 10 membres qui versent chacun 2 000 FCFA à
chaque tour. À chaque tour, un membre (le **bénéficiaire**) reçoit toute la cagnotte. Au tour suivant,
c'est un autre.

**TontiNet** numérise ça. Trois profils l'utilisent :

- **Le collecteur** passe chez les membres, encaisse en liquide et saisit chaque **cotisation** sur son
  téléphone. Il est souvent en zone sans réseau.
- **L'organisatrice** suit tout sur un **tableau de bord web**.
- **Le membre** voit son solde et reçoit des **notifications** sur son application.

Les règles précises (RG1 à RG16, exigences EF/ENF, sécurité SEC, décisions ADR) sont dans le **Cahier des
charges**, la spécification officielle du projet. Le dossier y renvoie par ces identifiants, et aux notes
de cours par « [NC leçon] ».

---

## 3. Les notions de base, expliquées simplement

**Système réparti.** Au lieu d'un seul serveur, on en fait tourner **trois copies identiques** : les
**répliques r1, r2, r3**. Si l'une tombe en panne, les deux autres continuent. Il en faut 3 pour supporter
1 panne : c'est la formule `n = 2f + 1` avec `f = 1`. Il reste alors toujours une **majorité** (2 sur 3).

**Le problème.** Trois copies doivent rester d'accord, alors que le réseau peut couper, ralentir ou perdre
des messages.

**Théorème CAP.** Quand le réseau est coupé entre répliques (une « partition »), il faut choisir :

- **AP (disponibilité)** : on continue d'accepter les écritures, quitte à se mettre d'accord plus tard ;
- **CP (cohérence)** : on refuse d'agir tant qu'on n'est pas sûr d'être d'accord.

**La décision centrale du dossier** tient en une phrase :

> **La collecte est AP, le versement est CP.**

- **Enregistrer une cotisation** doit toujours marcher, même si une réplique est coupée. Le collecteur ne
  peut pas dire au membre « revenez demain ». Et deux ajouts de cotisations ne se contredisent jamais : on
  peut les fusionner plus tard sans conflit.
- **Verser la cagnotte** ne doit jamais arriver deux fois, ni à deux bénéficiaires différents. On préfère
  refuser (« réessayez plus tard ») plutôt que de risquer ça.

---

## 4. Le dossier, section par section

### Section 1 : Objet et hypothèses

Elle pose le cadre :

- **Le dossier est un contrat entre l'équipe serveur et l'équipe mobile.**
- **Pannes supposées.** Une machine peut s'arrêter ou perdre des messages, mais elle ne ment pas.
- **Réseau asynchrone.** On ne sait jamais combien de temps un message mettra. Chaque appel a donc un
  **délai d'attente** (timeout).
- **L'heure du téléphone n'ordonne jamais rien (RG16).** Les horloges des téléphones sont souvent fausses,
  donc on ne s'en sert jamais pour décider « qui est arrivé avant ».

### Section 2 : Architecture (Figure 1)

La figure a trois colonnes.

**À gauche, les terminaux (Flutter) :**

- **Le tableau de bord web** de l'organisatrice.
- **L'application collecteur**, en 4 couches :
  - **l'interface**, qui ne lit et n'écrit que dans la base locale ;
  - **le stockage local**, une base SQLite chiffrée, avec une **outbox** (file d'attente des envois) ;
  - **le synchroniseur**, qui envoie la file au serveur. S'il échoue, il réessaie après 2 s, puis 4, 8…
    jusqu'à 64 s, avec un peu de hasard (la « gigue ») pour que tous les téléphones ne réessaient pas en
    même temps ;
  - **le client réseau**, seul à connaître l'adresse du serveur.
- **L'application membre**, pour les soldes et les notifications.

L'application est **« hors connexion d'abord »** (offline-first). La saisie est enregistrée **sur le
téléphone d'abord** et part au serveur quand le réseau revient.

**Au milieu, le service réparti :**

- **Traefik**, le **point d'entrée unique**. C'est un « proxy inverse » : tout le monde frappe à sa porte,
  et il redirige vers une réplique disponible. Il gère aussi le chiffrement (TLS 1.3) et limite le débit
  contre les abus.
- **Les 3 répliques r1, r2, r3**, qui font tourner le même programme. À un instant donné, l'une est
  **leader** (r1 sur le dessin) et les autres sont **suiveurs**.
- **Le courtier MQTT (Mosquitto)**, la « poste » des notifications.
- **Prometheus et Grafana**, qui collectent les métriques et tracent les courbes de supervision.

**À droite, l'extérieur :**

- **Le prestataire de paiement** (de type Mobile Money). Dans le projet, il est **simulé** par un petit
  serveur FastAPI.

**Les mécanismes internes :**

- **Chemin AP, les cotisations : G-Set CRDT.**
  - Un *G-Set* (« grow-only set ») est un ensemble où l'on ne fait qu'ajouter. Pour fusionner deux copies,
    on fait l'**union**, toujours sans conflit.
  - Chaque cotisation a un **UUID**, un identifiant unique **généré par le téléphone**. Grâce à lui, la
    même cotisation envoyée deux fois n'est comptée qu'une fois.
  - **Quorum W = 2** : une écriture est considérée sûre dès que 2 répliques sur 3 l'ont.
  - **Anti-entropie** : toutes les 5 s, les répliques comparent ce qu'elles ont et comblent leurs trous.
- **Chemin CP, paramètres, bénéficiaires et versements : Raft.**
  - **Raft** est un algorithme de **consensus**. Un leader propose des entrées dans un journal, et une
    entrée n'est validée que si une majorité l'a recopiée.
  - On utilise la bibliothèque Python PySyncObj.
  - Un suiveur qui reçoit une telle opération la **transfère au leader**.
- **Le versement est une saga**, une suite d'étapes avec un « plan de marche arrière » :
  - T1 geler le tour ;
  - T2 débiter le compte de la tontine ;
  - T3 créditer le bénéficiaire ;
  - T4 marquer le tour comme payé.
  - Si T3 échoue, on **compense** : C2 annule le débit, puis C1 dégèle le tour.
- **Les notifications passent par une outbox.** Côté serveur, la notification est écrite **dans la même
  transaction** que la cotisation, puis publiée plus tard. Une cotisation enregistrée finit donc toujours
  par être notifiée, et jamais l'inverse.

Les **pastilles numérotées 1 à 9** sur la figure renvoient aux lignes du tableau de la section 3.

### Section 3 : Choix de communication (Tableau 1)

Il y a trois technologies possibles :

| Techno | En une phrase | Bon pour |
|---|---|---|
| **REST** | HTTP + JSON, comme un site web | parler au monde extérieur (téléphones, navigateur, prestataire) |
| **gRPC** | appels de fonctions à distance, en binaire (Protobuf), avec un contrat strict | serveur ↔ serveur, rapide et typé |
| **MQTT** | publication/abonnement via un courtier : on « publie sur un sujet », les abonnés reçoivent | notifications vers des appareils souvent déconnectés |

Les 9 échanges et le choix retenu :

1. **Mobile → API : REST.** Ça passe partout (proxys, pare-feu). Le `PUT` avec un identifiant client est
   rejouable sans danger. gRPC ferait gagner à peine 0,8 Mo par mois, calcul tiré de l'activité 2.2 du
   cours.
2. **Tableau de bord → API : REST**, la même API.
3. **Réplique ↔ réplique (réplication) : gRPC + mTLS.** Le mTLS fait que chaque serveur prouve son
   identité à l'autre.
4. **Suiveur → leader : gRPC**, pour transmettre les opérations CP.
5. **Consensus : Raft**, sur le protocole TCP propre à PySyncObj. C'est imposé par la bibliothèque
   (ADR-03).
6. **Réplique → courtier → membre : MQTT, QoS 1.** On garde une session persistante et des messages
   « retenus » : le téléphone éteint récupère ses notifications au réveil.
7. **Courtier → tableau de bord : MQTT sur WebSocket.** La mise à jour en direct survit même si la
   réplique qui a servi la page tombe.
8. **Leader → prestataire : REST + `Idempotency-Key`.** On a choisi une saga plutôt qu'un « commit à deux
   phases », car un service externe ne peut pas y participer et ce protocole bloque en cas de panne
   (ADR-04).
9. **Prometheus → répliques : HTTP `GET /metrics`**, pour la supervision.

Le texte sous le tableau précise :

- **Pas de gRPC jusqu'au téléphone.** Le gain est négligeable et le débogage plus dur.
- **Pas de connexion permanente sur le téléphone.** Android et iOS la coupent en arrière-plan.
- **Sécurité** : TLS 1.3, jeton JWT de 15 min, ACL (droits d'accès) sur le courtier, et **aucune donnée
  personnelle** dans les sujets MQTT ni dans les journaux.

### Section 4 : Format des messages

**Règles du JSON :**

- montants en **entiers** en FCFA, jamais de nombres à virgule, qui provoquent des erreurs d'arrondi ;
- identifiant = **UUID créé sur le téléphone** ;
- dates ISO 8601 en UTC ;
- `saisie_le` est seulement indicatif (RG16) ;
- un en-tête `X-Request-Id` suit la requête de bout en bout, pour le débogage.

**Listing 1**, une vraie requête `PUT /v1/cotisations/{uuid}` et sa réponse :

- `doublon` indique si la cotisation était déjà connue ;
- `solde_tour` est le solde **recalculé** ;
- `replication` vaut `"quorum"` (2 répliques ont écrit) ou `"degradee"` (une seule). Dans ce dernier cas,
  le téléphone renvoie la cotisation plus tard, sans danger.

**Les erreurs** suivent la norme **RFC 9457** (format standard des erreurs HTTP), avec un `code` stable
comme `ID_CONTENU_DIFFERENT` ou `PAS_DE_MAJORITE`.

**Synchronisation descendante.** Pour savoir « ce que le téléphone a déjà reçu », le curseur est un
**vecteur de versions** (un compteur par réplique), pas une date.

**Listing 2**, le contrat **Protobuf** entre répliques :

- le message `Cotisation` ;
- le service `Replication` : `Repliquer` écrit avec W = 2, `Comparer` sert à l'anti-entropie, `Recuperer`
  renvoie un flux ;
- le service `Coordination`, pour qu'un suiveur transmette au leader.

Un numéro de champ supprimé est marqué `reserved` et ne doit jamais être réutilisé, sinon les anciennes et
nouvelles versions se comprennent de travers.

**Tableau 2, les sujets MQTT** (par exemple `tontinet/{t}/membres/{m}/cotisations`) :

- on y précise la QoS et si le message est retenu ;
- ils ne contiennent **que des identifiants opaques**, jamais de nom ni de numéro de téléphone (RG7) ;
- chaque message a un `event_id`, et l'application ignore un `event_id` déjà vu.

### Section 5 : Sémantique d'appel (Tableau 3 + Figure 2)

C'est la notion la plus importante du cours. Quand on envoie une requête et qu'on **ne reçoit pas de
réponse**, on ne sait pas si elle a été traitée. Il y a trois stratégies :

- **Au plus une fois** : on ne réessaie jamais. Pas de doublon, mais on risque une perte.
- **Au moins une fois** : on réessaie jusqu'à avoir une réponse. Pas de perte, mais on risque un doublon.
- **Exactement une fois** : impossible à garantir directement. On l'obtient par **« au moins une fois +
  idempotence »**.

**Idempotent** veut dire qu'exécuter l'opération deux fois revient au même que l'exécuter une fois. Par
exemple, « mettre la lumière sur allumé » est idempotent, alors que « appuyer sur l'interrupteur » ne l'est
pas.

La règle d'or : **on ne réessaie automatiquement que ce qui est idempotent.**

Le **tableau 3** applique ça à chaque opération :

- **Enregistrer une cotisation** : idempotent grâce à l'UUID.
  - Même contenu → `doublon: true`.
  - Contenu différent avec le même identifiant → erreur 409 (RG8).
  - On réessaie sur erreur réseau, délai dépassé ou 5xx, jamais sur 4xx.
- **Lectures** : on peut réessayer librement.
- **Créer une tontine, inscrire un membre…** : `PUT` sur un identifiant + numéro de version, 409 en cas de
  conflit.
- **Désigner le bénéficiaire** : validé par le leader, 503 s'il n'y a pas de majorité.
- **Déclencher le versement, annuler une cotisation** : **au plus une fois**. Une `Idempotency-Key` et une
  règle d'unicité (un seul versement par tontine et par tour) dans Raft font qu'une réémission renvoie
  simplement le même `versement_id`.
- **Connexion, rafraîchissement du jeton** : pas de réessai automatique.
- **Appels gRPC, étapes de saga, publications MQTT** : au moins une fois, rendus sûrs par des clés
  (`{versement_id}:T2`, `event_id`…).

La **figure 2** (diagramme de séquence) raconte une histoire concrète en 3 actes :

1. **Saisie locale.** Le collecteur saisit, la cotisation est enregistrée sur le téléphone avec le statut
   « en attente », affichée en moins de 300 ms, même sans réseau.
2. **Synchronisation.**
   - Le téléphone envoie un `PUT` à la réplique r2.
   - r2 vérifie les règles et écrit la cotisation et la ligne d'outbox ensemble.
   - Elle réplique en gRPC vers r1 et r3. Dès le premier accusé de réception, on a W = 2.
   - Elle répond `200`, et le téléphone passe la cotisation en « synchronisée ».
3. **Notification.** L'outbox publie en MQTT et le courtier livre à l'application du membre.

**L'encadré « alt » est le cas piège.** La réponse `200` se perd en route. Le téléphone attend 5 s, puis
renvoie **le même `PUT` avec le même UUID**. Le serveur reconnaît un **doublon** : le solde ne change pas et
il n'y a pas de seconde notification. C'est la démonstration visuelle d'« au moins une fois +
idempotence ».

Le dernier paragraphe résume **quand réessayer** :

- réseau, délai ou 5xx → oui, si l'opération est idempotente ;
- 401 → rafraîchir le jeton puis réessayer une fois ;
- 403, 404, 409, 422 → jamais.

---

## 5. La partie « fabrication » du document

- **Le modèle.** Le rapport `description_quiepousequi.pdf` a servi de gabarit. Son préambule LaTeX est
  repris à l'identique : police 12 pt, interligne 1,5, marges de 2,5 cm, en-têtes, style des tableaux et
  des listings, couleur des liens, logos UAC et IFRI sur la page de garde.
- **Les figures.** Elles sont **dessinées en TikZ**, directement dans le `.tex` (ce ne sont pas des
  images). Elles restent donc nettes à tous les zooms, avec la même police que le texte.
- **L'historique.**
  - Le PDF a d'abord été produit via Markdown + un script Python.
  - Il a ensuite été converti en LaTeX, à la demande.
  - Tout le circuit Python a été supprimé.
  - Enfin, la section 6, « Écarts », qui listait nos choix s'écartant du cahier des charges, a été retirée.
- **Compiler.** Depuis `docs/conception/` ou sur Overleaf, compiler deux fois pour que le sommaire et les
  renvois se mettent à jour :

  ```bash
  pdflatex J1-dossier-conception.tex && pdflatex J1-dossier-conception.tex
  ```

- **Les fichiers** dans `docs/conception/` :
  - le `.tex` (la source) ;
  - le `.pdf` (le livrable) ;
  - les deux logos ;
  - un [README.md](README.md) qui explique tout ça ;
  - ce fichier d'explication.

---

## 6. À savoir avant la relecture croisée

Depuis la suppression de la section 6, deux choix ne sont plus justifiés dans le texte, et l'autre équipe
peut les relever :

- **Le tableau de bord en MQTT sur WebSocket.** Le cahier des charges prévoyait un WebSocket servi par une
  réplique.
- **Le service gRPC `Coordination`**, qui n'est pas dans le cahier des charges.

Réponses courtes si la question est posée :

- pour le tableau de bord : il continue de fonctionner si la réplique qui a servi la page tombe ;
- pour `Coordination` : il faut bien un canal pour qu'un suiveur transmette au leader une opération reçue.
