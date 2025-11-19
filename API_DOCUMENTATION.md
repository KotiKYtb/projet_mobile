# Documentation API - Angers Mobile App

## Vue d'ensemble

L'API est une application Node.js/Express qui fournit un backend RESTful pour l'application mobile Angers. Elle utilise JWT pour l'authentification, Sequelize comme ORM, et supporte à la fois MySQL et SQLite comme bases de données.

### Technologies utilisées

- **Node.js** avec **Express.js** - Framework web
- **Sequelize** - ORM pour la gestion de la base de données
- **SQLite** (par défaut) ou **MySQL** - Base de données
- **JWT (JSON Web Tokens)** - Authentification
- **Firebase Admin SDK** - Envoi de notifications push
- **Swagger/OpenAPI** - Documentation interactive
- **Multer** - Gestion des uploads de fichiers
- **Node Geocoder** - Géocodage des adresses

### Architecture

L'API suit une architecture MVC (Model-View-Controller) :

- **Models** (`/models`) - Définition des modèles de données et relations
- **Controllers** (`/controllers`) - Logique métier
- **Routes** (`/routes`) - Définition des endpoints
- **Middleware** (`/middleware`) - Authentification et validation
- **Services** (`/services`) - Services externes (Firebase, géocodage)
- **Config** (`/config`) - Configuration (DB, auth, Swagger)

## Configuration

### Variables d'environnement

L'API cherche le fichier `.env` dans l'ordre suivant :
1. `API/.env`
2. `.env` (racine du projet)

Variables importantes :
- `PORT` - Port d'écoute du serveur (défaut: 8080)
- `USE_MYSQL` - `1` pour utiliser MySQL, sinon SQLite
- `SECRET` - Clé secrète pour signer les JWT
- `REFRESH_SECRET` - Clé secrète pour les refresh tokens
- `RESET_DB` - `1` pour forcer la recréation de la base de données

### Base de données

Par défaut, l'API utilise **SQLite** avec le fichier `data.sqlite`. Pour utiliser MySQL, définissez `USE_MYSQL=1` dans le `.env` et configurez `config/db.config.js`.

La synchronisation de la base de données se fait automatiquement au démarrage :
- `RESET_DB=1` : Force la recréation complète (supprime toutes les données)
- Sinon : Utilise `alter: true` pour MySQL, synchronisation simple pour SQLite

## Authentification

L'API utilise JWT (JSON Web Tokens) pour l'authentification. Les tokens sont envoyés dans le header `x-access-token` ou `Authorization: Bearer <token>`.

### Rôles utilisateurs

- **user** - Utilisateur standard
- **admin** - Administrateur (accès complet)
- **organisation** - Organisation (peut créer/modifier des événements)

### Middleware d'authentification

- `verifyToken` - Vérifie la validité du token JWT
- `isAdmin` - Vérifie que l'utilisateur est admin
- `isAdminOrOrganisation` - Vérifie que l'utilisateur est admin ou organisation

## Routes de l'API

> **Note** : Pour la documentation complète et interactive avec exemples de requêtes/réponses, consultez Swagger UI à `http://localhost:8080/api-docs` une fois l'API démarrée.

### Routes d'authentification (`/api/auth`)

#### POST `/api/auth/signup`
Inscription d'un nouvel utilisateur.
- **Body** : `email`, `password`, `name` (optionnel), `surname` (optionnel), `role` (optionnel)
- **Validation** : Vérifie que l'email n'existe pas déjà et que le rôle est valide
- **Réponse** : Message de succès

#### POST `/api/auth/signin`
Connexion d'un utilisateur.
- **Body** : `email`, `password`
- **Réponse** : `accessToken`, `refreshToken`, `id`, `email`, `role`, `name`, `surname`
- **Erreurs** : 401 si identifiants incorrects, 404 si utilisateur non trouvé

#### POST `/api/auth/refresh`
Rafraîchit un token d'accès expiré.
- **Body** : `refreshToken`
- **Réponse** : Nouveau `accessToken`
- **Important** : Le refresh token doit être valide et non expiré

### Routes des événements (`/api/events`)

#### GET `/api/events`
Liste paginée de tous les événements.
- **Query params** : `page` (défaut: 1), `pageSize` (défaut: 50, max: 200), `updatedSince` (optionnel)
- **Accès** : Public (pas d'authentification requise)
- **Réponse** : Liste paginée avec `data`, `total`, `page`, `pageSize`, `totalPages`

#### GET `/api/events/:id`
Récupère un événement spécifique par son ID.
- **Accès** : Public
- **Réponse** : Objet événement complet avec créateur et favoris

#### POST `/api/events`
Crée un nouvel événement.
- **Authentification** : Requise (Admin ou Organisation)
- **Body** : `title` (requis), `startAt` (requis), `endAt` (optionnel), `description`, `location`, `category`, `image_url`
- **Réponse** : Événement créé avec ID
- **Géocodage** : Si `location` est fourni, les coordonnées GPS sont automatiquement calculées

#### PUT `/api/events/:id`
Met à jour un événement existant.
- **Authentification** : Requise (Admin ou Organisation)
- **Body** : Tous les champs sont optionnels (seuls ceux fournis seront mis à jour)
- **Réponse** : Événement mis à jour

#### DELETE `/api/events/:id`
Supprime un événement.
- **Authentification** : Requise (Admin ou Organisation)
- **Réponse** : 204 No Content si succès

### Routes des favoris (`/api/favorites`)

#### GET `/api/favorites`
Récupère la liste des favoris de l'utilisateur connecté.
- **Authentification** : Requise
- **Réponse** : Liste des événements favoris avec détails complets

#### POST `/api/favorites`
Ajoute un événement aux favoris.
- **Authentification** : Requise
- **Body** : `event_id`
- **Réponse** : 201 si ajouté, 200 si déjà en favoris

#### DELETE `/api/favorites/:eventId`
Retire un événement des favoris.
- **Authentification** : Requise
- **Réponse** : Message de confirmation

### Routes des notifications (`/api/notifications`)

#### POST `/api/notifications/token`
Enregistre un token FCM (Firebase Cloud Messaging) pour l'utilisateur connecté.
- **Authentification** : Requise
- **Body** : `token` (FCM token), `device_type` (optionnel)
- **Important** : Permet à l'API d'envoyer des notifications push à l'utilisateur

#### DELETE `/api/notifications/token`
Supprime un token FCM.
- **Authentification** : Requise
- **Body** : `token`

#### GET `/api/notifications`
Récupère toutes les notifications créées (pour les admins/organisations).
- **Authentification** : Requise (Admin ou Organisation)
- **Réponse** : Liste des notifications avec statistiques

#### POST `/api/notifications`
Crée une notification sans l'envoyer.
- **Authentification** : Requise (Admin ou Organisation)
- **Body** : `title`, `body`, `eventIds` (tableau d'IDs d'événements)
- **Réponse** : Notification créée

#### PUT `/api/notifications/:id`
Met à jour une notification existante.
- **Authentification** : Requise (Admin ou Organisation)
- **Body** : `title`, `body`, `eventIds`

#### POST `/api/notifications/:id/send`
Envoie une notification existante par son ID.
- **Authentification** : Requise (Admin ou Organisation)
- **Action** : Envoie la notification à tous les utilisateurs ayant les événements en favoris

#### DELETE `/api/notifications/:id`
Supprime une notification.
- **Authentification** : Requise (Admin ou Organisation)

#### GET `/api/notifications/received`
Récupère les notifications reçues par l'utilisateur connecté.
- **Authentification** : Requise
- **Réponse** : Liste des notifications avec statut (lu/non lu, masqué)

#### PUT `/api/notifications/received/:id/read`
Marque une notification comme lue.
- **Authentification** : Requise

#### PUT `/api/notifications/received/read-all`
Marque toutes les notifications comme lues.
- **Authentification** : Requise

#### PUT `/api/notifications/received/:id/hide`
Masque une notification de l'affichage.
- **Authentification** : Requise

#### POST `/api/notifications/test`
Envoie une notification de test à l'utilisateur connecté.
- **Authentification** : Requise
- **Body** : `title` (optionnel), `body` (optionnel)

#### POST `/api/notifications/events`
Envoie une notification à tous les utilisateurs ayant des événements spécifiques en favoris.
- **Authentification** : Requise (Admin ou Organisation)
- **Body** : `title`, `body`, `eventIds`, `data` (optionnel)

### Routes d'upload (`/api/upload`)

#### POST `/api/upload/image`
Upload une image d'événement.
- **Authentification** : Requise (Admin ou Organisation)
- **Content-Type** : `multipart/form-data`
- **Body** : `image` (fichier image)
- **Formats supportés** : jpeg, jpg, png, gif, webp, heic
- **Taille max** : 10MB
- **Réponse** : URL de l'image uploadée
- **Stockage** : Images stockées dans `API/public/images/`

### Routes utilisateurs (`/api/users`)

#### GET `/api/users/me`
Récupère les informations de l'utilisateur connecté.
- **Authentification** : Requise
- **Réponse** : Profil utilisateur complet

#### GET `/api/users`
Récupère la liste de tous les utilisateurs.
- **Authentification** : Requise (Admin)

#### GET `/api/users/public`
Récupère la liste publique des utilisateurs (sans données sensibles).
- **Accès** : Public

#### PUT `/api/users/:id/role`
Met à jour le rôle d'un utilisateur.
- **Authentification** : Requise (Admin)
- **Body** : `role`

#### PUT `/api/users/change-password`
Change le mot de passe de l'utilisateur connecté.
- **Authentification** : Requise
- **Body** : `oldPassword`, `newPassword`

### Routes générales

#### GET `/`
Message de bienvenue de l'API.

#### GET `/api/server-info`
Informations du serveur pour la découverte automatique.
- **Réponse** : `ip`, `port`, `baseUrl`, `allIPs`
- **Utile** : Pour que l'application mobile découvre automatiquement l'IP du serveur

## Services

### Service Firebase (`services/firebase.service.js`)
Gère l'envoi de notifications push via Firebase Cloud Messaging (FCM). Nécessite un fichier `firebase-service-account.json` avec les credentials Firebase.

### Service de géocodage (`services/geocoding.service.js`)
Convertit les adresses en coordonnées GPS (latitude/longitude) en utilisant Node Geocoder. Les coordonnées sont automatiquement calculées lors de la création/modification d'un événement avec une localisation.

## Documentation Swagger

L'API expose une documentation Swagger interactive à l'adresse :
```
http://localhost:8080/api-docs
```

Cette documentation permet de :
- Voir toutes les routes disponibles
- Tester les endpoints directement depuis le navigateur
- Voir les schémas de données
- Comprendre les paramètres requis

## Démarrage de l'API

1. Installer les dépendances :
```bash
cd API
npm install
```

2. Configurer le fichier `.env` (optionnel, des valeurs par défaut sont utilisées)

3. Démarrer l'API :
```bash
npm start
```

L'API sera accessible sur `http://localhost:8080` et écoutera sur toutes les interfaces réseau (`0.0.0.0`) pour permettre l'accès depuis des appareils mobiles sur le même réseau.

## Gestion des erreurs

L'API retourne des codes HTTP standards :
- **200** - Succès
- **201** - Créé avec succès
- **204** - Succès sans contenu
- **400** - Erreur de validation/requête invalide
- **401** - Non authentifié
- **403** - Accès refusé (permissions insuffisantes)
- **404** - Ressource non trouvée
- **500** - Erreur serveur

Les réponses d'erreur contiennent un objet JSON avec un champ `message` décrivant l'erreur.

## Sécurité

- Les mots de passe sont hashés avec **bcryptjs**
- Les tokens JWT ont une expiration (configurable)
- CORS est configuré pour autoriser les requêtes depuis n'importe quelle origine (développement)
- Les uploads de fichiers sont limités en taille et type
- Validation des données d'entrée via middleware

## Base de données

### Modèles principaux

- **User** - Utilisateurs avec rôles
- **Event** - Événements avec géolocalisation
- **Favorite** - Relation many-to-many entre User et Event
- **FCMToken** - Tokens Firebase pour les notifications push
- **Notification** - Notifications créées
- **UserNotification** - Notifications reçues par les utilisateurs

### Relations

- User ↔ Event (via Favorite) - Many-to-many
- User → Event (created_by) - Un utilisateur peut créer plusieurs événements
- User → FCMToken - Un utilisateur peut avoir plusieurs tokens
- User → Notification (created_by) - Un utilisateur peut créer plusieurs notifications
- User → UserNotification - Un utilisateur peut recevoir plusieurs notifications
- Event → UserNotification - Une notification peut être liée à un événement