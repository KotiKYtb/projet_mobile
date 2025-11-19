# Documentation Application Mobile - Angers Mobile App

## Vue d'ensemble

L'application mobile est développée en **Flutter** et permet aux utilisateurs de découvrir, consulter et gérer des événements à Angers. Elle fonctionne en mode **online** et **offline**, avec synchronisation automatique des données.

### Technologies utilisées

- **Flutter** - Framework de développement multiplateforme
- **Dart** - Langage de programmation
- **Provider** - Gestion d'état
- **HTTP** - Communication avec l'API
- **SQFlite** - Base de données locale (SQLite)
- **Flutter Secure Storage** - Stockage sécurisé des tokens
- **Firebase Cloud Messaging** - Notifications push
- **Flutter OSM Plugin** - Cartes OpenStreetMap
- **Connectivity Plus** - Détection de la connectivité réseau
- **Flutter Dotenv** - Variables d'environnement

## Structure du projet

```
lib/
├── api_client.dart          # Client HTTP pour communiquer avec l'API
├── main.dart                # Point d'entrée de l'application
├── token_storage.dart       # Gestion du stockage des tokens JWT
├── config/                  # Configuration
├── models/                  # Modèles de données
├── screens/                 # Écrans de l'application
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── main_screen.dart
│   ├── home_content.dart
│   ├── events_content.dart
│   ├── map_content.dart
│   ├── profile_content.dart
│   ├── event_details_screen.dart
│   └── orga/
│       ├── event_editor.dart
│       └── notification_screen.dart
├── services/                # Services métier
│   ├── connectivity_service.dart
│   ├── firebase_messaging_service.dart
│   ├── local_database.dart
│   ├── map_service.dart
│   ├── sync_service.dart
│   └── theme_service.dart
├── widgets/                 # Widgets réutilisables
└── utils/                   # Utilitaires
```

## Configuration de la connexion à l'API

### Fichier .env

L'application utilise un fichier `.env` à la **racine du projet** pour configurer la connexion à l'API. Ce fichier doit être créé manuellement.

#### Création du fichier .env

1. Créez un fichier nommé `.env` à la racine du projet (même niveau que `pubspec.yaml`)
2. Ajoutez les variables suivantes :

```env
API_IP=192.168.1.100
API_PORT=8080
API_PROTOCOL=http
```

#### Variables d'environnement

- **API_IP** : Adresse IP du serveur API
  - Pour un appareil physique sur le même réseau Wi-Fi : IP locale du PC (ex: `192.168.1.100`)
  - Pour un émulateur Android : `10.0.2.2` (IP spéciale pour accéder à localhost de la machine hôte)
  - Pour un émulateur iOS : `localhost` ou l'IP locale
  - Pour un appareil physique en USB : IP locale du PC

- **API_PORT** : Port du serveur API (défaut: `8080`)

- **API_PROTOCOL** : Protocole utilisé (`http` ou `https`, défaut: `http`)

#### Comment trouver l'IP du serveur

**Sur Windows :**
1. Ouvrez l'invite de commande (cmd)
2. Tapez : `ipconfig`
3. Cherchez "Adresse IPv4" sous votre connexion Wi-Fi/Ethernet
4. Utilisez cette adresse (ex: `192.168.1.100`)

**Sur Mac/Linux :**
1. Ouvrez le terminal
2. Tapez : `ifconfig` (ou `ip addr` sur Linux)
3. Cherchez l'adresse IP de votre interface réseau

**Alternative :**
L'API expose un endpoint `/api/server-info` qui retourne l'IP du serveur. Vous pouvez y accéder depuis votre navigateur une fois l'API démarrée.

#### Modification de l'IP dans le fichier .env

1. Ouvrez le fichier `.env` à la racine du projet
2. Modifiez la valeur de `API_IP` avec la nouvelle adresse IP
3. **Important** : Redémarrez l'application Flutter pour que les changements prennent effet

Exemple :
```env
# Avant
API_IP=192.168.1.100

# Après (nouvelle IP)
API_IP=192.168.1.150
```

#### Configuration pour différents environnements

**Développement local (émulateur Android) :**
```env
API_IP=10.0.2.2
API_PORT=8080
API_PROTOCOL=http
```

**Développement local (appareil physique) :**
```env
API_IP=192.168.1.100
API_PORT=8080
API_PROTOCOL=http
```

**Production :**
```env
API_IP=api.example.com
API_PORT=443
API_PROTOCOL=https
```

### Utilisation dans le code

Le fichier `.env` est chargé au démarrage de l'application dans `main.dart` :

```dart
await dotenv.load(fileName: ".env");
```

L'`ApiClient` lit automatiquement ces variables :

```dart
static String get baseUrl {
  final ip = dotenv.env['API_IP'] ?? 'localhost';
  final port = dotenv.env['API_PORT'] ?? '8080';
  final protocol = dotenv.env['API_PROTOCOL'] ?? 'http';
  return '$protocol://$ip:$port';
}
```

## Installation et démarrage

### Prérequis

- Flutter SDK (version 3.9.2 ou supérieure)
- Android Studio / Xcode (pour iOS)
- Un appareil Android/iOS ou un émulateur

### Installation

1. **Cloner le projet** (si nécessaire)

2. **Installer les dépendances** :
```bash
flutter pub get
```

3. **Créer le fichier .env** à la racine du projet avec la configuration de l'API

4. **Configurer Firebase** (pour les notifications push) :
   - Ajoutez `google-services.json` dans `android/app/` (Android)
   - Configurez Firebase pour iOS si nécessaire

5. **Lancer l'application** :
```bash
flutter run
```

## Fonctionnalités principales

### Authentification

L'application gère l'authentification avec JWT :
- **Inscription** : Création d'un nouveau compte
- **Connexion** : Authentification avec email/mot de passe
- **Session persistante** : L'utilisateur reste connecté même après fermeture de l'app
- **Refresh token** : Renouvellement automatique des tokens expirés
- **Mode offline** : Connexion automatique si session valide en cache

### Gestion des événements

- **Liste des événements** : Affichage paginé de tous les événements
- **Détails d'un événement** : Informations complètes, localisation sur carte
- **Favoris** : Ajout/suppression d'événements en favoris
- **Recherche et filtres** : Recherche par titre, catégorie, date
- **Création/Modification** : Pour les utilisateurs avec rôle "organisation" ou "admin"

### Cartes et géolocalisation

- **Carte interactive** : Affichage des événements sur une carte OpenStreetMap
- **Géolocalisation** : Position de l'utilisateur
- **Navigation** : Ouverture de l'itinéraire dans une app externe

### Notifications push

- **Notifications Firebase** : Réception de notifications push
- **Notifications locales** : Affichage même quand l'app est fermée
- **Gestion des notifications** : Marquer comme lu, masquer
- **Widget Android** : Affichage des événements favoris sur le widget d'accueil

### Mode offline

L'application fonctionne en mode offline :
- **Cache local** : Données stockées dans SQLite
- **Synchronisation** : Synchronisation automatique quand la connexion revient
- **Authentification offline** : Connexion automatique si session valide en cache

### Thème

- **Thème clair/sombre** : Basculement entre les modes
- **Persistance** : Le choix du thème est sauvegardé

## Architecture de l'application

### Gestion d'état

L'application utilise **Provider** pour la gestion d'état :
- `ThemeService` : Gestion du thème clair/sombre
- Services réactifs pour la connectivité et la synchronisation

### Services

#### ApiClient (`lib/api_client.dart`)
Client HTTP centralisé pour toutes les requêtes vers l'API. Gère :
- Construction de l'URL de base depuis `.env`
- Timeout des requêtes (20 secondes)
- Gestion des erreurs
- Toutes les méthodes API (auth, events, favorites, notifications, upload)

#### TokenStorage (`lib/token_storage.dart`)
Gestion sécurisée des tokens JWT :
- Stockage dans Flutter Secure Storage
- Vérification de validité des tokens
- Gestion des refresh tokens
- Nettoyage automatique des tokens expirés

#### LocalDatabase (`lib/services/local_database.dart`)
Base de données locale SQLite pour le cache :
- Stockage des événements
- Stockage des favoris
- Stockage des informations utilisateur
- Synchronisation avec l'API

#### ConnectivityService (`lib/services/connectivity_service.dart`)
Détection de la connectivité réseau :
- Vérification de la connexion Internet
- Mode online/offline
- Gestion de la reconnexion

#### SyncService (`lib/services/sync_service.dart`)
Synchronisation des données :
- Synchronisation des événements
- Synchronisation des favoris
- Gestion des conflits

#### FirebaseMessagingService (`lib/services/firebase_messaging_service.dart`)
Gestion des notifications push :
- Initialisation de Firebase
- Enregistrement des tokens FCM
- Réception des notifications
- Gestion des notifications en background

#### MapService (`lib/services/map_service.dart`)
Service de carte OpenStreetMap :
- Initialisation de la carte
- Affichage des événements
- Géolocalisation

### Écrans principaux

#### LoginScreen
Écran de connexion avec :
- Formulaire email/password
- Lien vers l'inscription
- Gestion des erreurs
- Test de connexion à l'API

#### RegisterScreen
Écran d'inscription avec :
- Formulaire complet (email, password, nom, prénom)
- Validation des champs
- Gestion des erreurs

#### MainScreen
Écran principal avec navigation par onglets :
- **Accueil** : Liste des événements
- **Carte** : Carte avec événements
- **Profil** : Informations utilisateur, paramètres

#### EventDetailsScreen
Détails d'un événement :
- Informations complètes
- Image de l'événement
- Localisation sur carte
- Bouton favori
- Navigation vers l'itinéraire

#### EventEditor (Organisation)
Éditeur d'événements pour les organisations :
- Création/Modification d'événements
- Upload d'images
- Géocodage automatique de l'adresse
- Gestion des dates

## Communication avec l'API

### Configuration de l'URL de base

L'URL de base est construite automatiquement depuis le fichier `.env` :

```dart
static String get baseUrl {
  final ip = dotenv.env['API_IP'] ?? 'localhost';
  final port = dotenv.env['API_PORT'] ?? '8080';
  final protocol = dotenv.env['API_PROTOCOL'] ?? 'http';
  return '$protocol://$ip:$port';
}
```

### Authentification

Les tokens JWT sont envoyés dans le header `x-access-token` :

```dart
headers: {
  'x-access-token': token,
  'Accept': 'application/json',
}
```

### Gestion des erreurs

L'application gère plusieurs types d'erreurs :
- **Timeout** : Si l'API ne répond pas dans les 20 secondes
- **Erreurs réseau** : Connexion impossible
- **Erreurs HTTP** : Codes d'erreur de l'API (401, 403, 404, 500)
- **Mode offline** : Basculement automatique vers le cache local

### Test de connexion

L'application peut tester la connexion à l'API :

```dart
final isConnected = await ApiClient.testConnection();
```

Cette méthode effectue une requête GET sur `/` et retourne `true` si la connexion réussit.

## Dépannage

### L'application ne se connecte pas à l'API

1. **Vérifiez que l'API est démarrée** :
   - L'API doit être lancée et accessible sur le port configuré
   - Testez dans un navigateur : `http://VOTRE_IP:8080`

2. **Vérifiez l'IP dans le fichier .env** :
   - L'IP doit correspondre à l'IP locale du PC serveur
   - Pour un émulateur Android, utilisez `10.0.2.2`
   - Pour un appareil physique, utilisez l'IP locale du PC

3. **Vérifiez le firewall** :
   - Le firewall Windows/Mac peut bloquer les connexions
   - Autorisez le port 8080 dans les règles de firewall

4. **Vérifiez le réseau** :
   - L'appareil mobile et le PC doivent être sur le même réseau Wi-Fi
   - Testez la connexion depuis le navigateur du téléphone

5. **Vérifiez les logs** :
   - Les erreurs de connexion sont affichées dans la console Flutter
   - Recherchez les messages commençant par `❌` ou `⚠️`

### L'application ne charge pas les événements

1. **Vérifiez la connexion Internet** : L'appareil doit être connecté au réseau
2. **Vérifiez les logs de l'API** : Des erreurs peuvent apparaître côté serveur
3. **Vérifiez le mode offline** : L'app peut être en mode offline, vérifiez l'icône de connexion
4. **Réinitialisez le cache** : Supprimez les données de l'application dans les paramètres

### Les notifications push ne fonctionnent pas

1. **Vérifiez la configuration Firebase** :
   - Le fichier `google-services.json` doit être présent
   - Les permissions de notification doivent être accordées

2. **Vérifiez l'enregistrement du token FCM** :
   - Le token doit être enregistré dans l'API après connexion
   - Vérifiez dans les logs de l'API

3. **Vérifiez les permissions** :
   - Android : Autorisez les notifications dans les paramètres de l'app
   - iOS : Autorisez les notifications lors de la première ouverture

## Build et déploiement

### Build Android

```bash
flutter build apk --release
```

Le fichier APK sera généré dans `build/app/outputs/flutter-apk/app-release.apk`

### Build iOS

```bash
flutter build ios --release
```

### Configuration pour la production

Pour la production, modifiez le fichier `.env` avec l'URL de l'API de production :

```env
API_IP=api.votre-domaine.com
API_PORT=8080
API_PROTOCOL=https
```

**Important** : Ne commitez jamais le fichier `.env` avec des credentials de production dans le contrôle de version.

## Structure des données

### Modèle EventItem

Représente un événement dans l'application.

```dart
class EventItem {
  final int eventId;              // ID unique de l'événement
  final String title;             // Titre de l'événement (requis)
  final String? description;      // Description détaillée (optionnel)
  final String? location;         // Adresse textuelle (optionnel)
  final double? latitude;         // Latitude GPS (optionnel, calculé automatiquement)
  final double? longitude;        // Longitude GPS (optionnel, calculé automatiquement)
  final DateTime startAt;         // Date et heure de début (requis)
  final DateTime? endAt;          // Date et heure de fin (optionnel)
  final String? category;         // Catégorie de l'événement (optionnel)
  final String? imageUrl;         // URL de l'image (optionnel)
  final String? createdBy;        // ID de l'utilisateur créateur (optionnel)

  // Getters utilitaires
  String get id => eventId.toString();
  String get place => location ?? 'Lieu non spécifié';
  DateTime get date => startAt;
}
```

**Méthodes :**
- `factory EventItem.fromJson(Map<String, dynamic> json)` - Crée un EventItem depuis les données JSON de l'API

**Localisation :** `lib/screens/events_content.dart`

---

### Modèle UserModel

Représente un utilisateur dans l'application. Utilisé pour le cache local et la gestion des sessions.

```dart
class UserModel {
  final int? id;                  // ID local en base SQLite (auto-incrémenté)
  final int userId;               // ID utilisateur depuis l'API (unique)
  final String email;             // Email de l'utilisateur (requis)
  final String name;              // Prénom (requis)
  final String surname;            // Nom de famille (requis)
  final String role;              // Rôle: 'user', 'admin', 'organisation'
  final DateTime createdAt;        // Date de création du compte
  final DateTime updatedAt;        // Date de dernière modification
  final DateTime? lastSync;       // Date de dernière synchronisation avec l'API
}
```

**Méthodes :**
- `Map<String, dynamic> toMap()` - Convertit en Map pour SQLite
- `factory UserModel.fromMap(Map<String, dynamic> map)` - Crée depuis SQLite
- `factory UserModel.fromApi(Map<String, dynamic> apiData)` - Crée depuis les données API
- `UserModel copyWith({...})` - Crée une copie avec des champs modifiés

**Table SQLite :** `users`
- Colonnes : `id`, `user_id`, `email`, `name`, `surname`, `role`, `created_at`, `updated_at`, `last_sync`
- Index unique sur `user_id`

**Localisation :** `lib/models/user_model.dart`

---

### Modèle NotificationItem (Notifications créées)

Représente une notification créée par un admin/organisation. Utilisé dans l'écran de gestion des notifications.

```dart
class NotificationItem {
  final int notificationId;       // ID unique de la notification
  final String title;              // Titre de la notification (requis)
  final String body;               // Corps du message (requis)
  final List<int> eventIds;        // Liste des IDs d'événements concernés
  final int sentCount;             // Nombre de notifications envoyées avec succès
  final int failedCount;           // Nombre de notifications échouées
  final DateTime createdAt;       // Date de création
  final int? createdBy;            // ID de l'utilisateur créateur
}
```

**Méthodes :**
- `factory NotificationItem.fromJson(Map<String, dynamic> json)` - Crée depuis les données JSON de l'API

**Localisation :** `lib/screens/orga/notification_screen.dart`

---

### Modèle NotificationItem (Notifications reçues)

Représente une notification reçue par l'utilisateur. Utilisé dans l'écran des notifications utilisateur.

```dart
class NotificationItem {
  final int userNotificationId;    // ID unique de la notification reçue
  final String title;              // Titre de la notification
  final String body;                // Corps du message
  bool read;                        // Statut de lecture (modifiable)
  final int? eventId;               // ID de l'événement lié (optionnel)
  final String? eventTitle;         // Titre de l'événement (optionnel)
  final String? eventLocation;      // Localisation de l'événement (optionnel)
  final DateTime createdAt;         // Date de réception
}
```

**Méthodes :**
- `factory NotificationItem.fromJson(Map<String, dynamic> json)` - Crée depuis les données JSON de l'API

**Note :** Même nom de classe que le modèle précédent mais usage différent (un pour créer, un pour recevoir).

**Localisation :** `lib/screens/infos_content.dart`

---

### Modèle Favorite (Base de données locale)

Structure de la table des favoris dans la base de données SQLite locale.

**Table SQLite :** `favorites`

```sql
CREATE TABLE favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  event_id INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(user_id, event_id)
)
```

**Champs :**
- `id` - ID local (auto-incrémenté)
- `user_id` - ID de l'utilisateur
- `event_id` - ID de l'événement
- `created_at` - Date de création (ISO 8601)
- `updated_at` - Date de mise à jour (ISO 8601)
- Contrainte unique sur `(user_id, event_id)` pour éviter les doublons

**Méthodes disponibles dans LocalDatabase :**
- `insertOrUpdateFavorite({required int userId, required int eventId})` - Ajoute ou met à jour un favori
- `deleteFavorite({required int userId, required int eventId})` - Supprime un favori
- `getFavoriteEventIds(int userId)` - Récupère tous les IDs d'événements favoris d'un utilisateur
- `isFavorite({required int userId, required int eventId})` - Vérifie si un événement est en favori
- `syncFavorites({required int userId, required List<int> eventIds})` - Synchronise les favoris depuis l'API
- `clearFavorites(int userId)` - Supprime tous les favoris d'un utilisateur
- `clearAllFavorites()` - Supprime tous les favoris

**Localisation :** `lib/services/local_database.dart`

---

### Structure de la base de données locale (SQLite)

L'application utilise SQLite pour le cache local avec le fichier `local_cache.db`.

#### Table `users`

Stocke les informations des utilisateurs pour le mode offline.

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER UNIQUE NOT NULL,
  email TEXT NOT NULL,
  name TEXT NOT NULL,
  surname TEXT NOT NULL,
  role TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_sync TEXT
)
```

**Index :** Index unique sur `user_id`

#### Table `favorites`

Stocke les favoris des utilisateurs pour le mode offline.

```sql
CREATE TABLE favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  event_id INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(user_id, event_id)
)
```

**Index :** Contrainte unique sur `(user_id, event_id)`

**Version de la base :** Version 2 (la table favorites a été ajoutée dans la version 2)

**Localisation :** `lib/services/local_database.dart`

---

### Correspondance avec l'API

Les modèles de l'application mobile correspondent aux modèles de l'API backend :

| Modèle Mobile | Modèle API | Description |
|--------------|------------|-------------|
| `EventItem` | `Event` | Événements avec géolocalisation |
| `UserModel` | `User` | Utilisateurs avec rôles |
| `NotificationItem` (créée) | `Notification` | Notifications créées par admin/orga |
| `NotificationItem` (reçue) | `UserNotification` | Notifications reçues par utilisateurs |
| `Favorite` (table) | `Favorite` | Relation many-to-many User ↔ Event |

**Note :** Les événements ne sont pas stockés localement en base de données, ils sont toujours récupérés depuis l'API. Seuls les utilisateurs et les favoris sont mis en cache localement pour le mode offline.

---

### Classes utilitaires (non stockées en base)

#### _UserListItem

Classe utilitaire privée pour l'affichage des utilisateurs dans la liste (écran profil admin). Représente les mêmes données que `UserModel` mais sans les champs de cache local.

```dart
class _UserListItem {
  final int userId;               // ID utilisateur depuis l'API
  final String email;             // Email de l'utilisateur
  final String name;              // Prénom
  final String surname;            // Nom de famille
  final String role;              // Rôle: 'user', 'admin', 'organisation'
  final DateTime createdAt;        // Date de création du compte
  final DateTime updatedAt;        // Date de dernière modification
}
```

**Méthodes :**
- `factory _UserListItem.fromJson(Map<String, dynamic> json)` - Crée depuis les données JSON de l'API

**Note :** Classe privée (commence par `_`) utilisée uniquement pour l'affichage dans l'interface admin. Les données utilisateur complètes sont gérées par `UserModel`.

**Localisation :** `lib/screens/profile_content.dart`

#### ProfileSection

Classe utilitaire pour organiser les sections du profil utilisateur.

```dart
class ProfileSection {
  final String title;             // Titre de la section
  final IconData icon;             // Icône de la section
  final List<Widget> content;      // Contenu de la section
  bool isExpanded;                 // État d'expansion (modifiable)
}
```

**Note :** Classe utilitaire pour l'interface, pas un modèle de données.

**Localisation :** `lib/screens/profile_content.dart`

## Permissions requises

### Android (`android/app/src/main/AndroidManifest.xml`)

- `INTERNET` - Pour les requêtes HTTP
- `ACCESS_FINE_LOCATION` - Pour la géolocalisation
- `ACCESS_COARSE_LOCATION` - Pour la géolocalisation
- `CAMERA` - Pour l'upload d'images (optionnel)
- `READ_EXTERNAL_STORAGE` - Pour l'upload d'images (optionnel)

## Support et contribution

Pour toute question ou problème, consultez :
- La documentation de l'API : `API_DOCUMENTATION.md`
- Les logs de l'application (console Flutter)
- Les logs de l'API (console Node.js)