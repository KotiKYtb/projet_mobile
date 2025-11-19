import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';

class LocalDatabase {
  static Database? _database;
  static const String _tableName = 'users';
  static const String _favoritesTableName = 'favorites';
  static const String _eventsTableName = 'events';
  static const String _notificationsTableName = 'notifications';
  static const String _userNotificationsTableName = 'user_notifications';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'local_cache.db');
    return await openDatabase(
      path,
      version: 5, // Version augmentée pour ajouter profile_picture
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Table users
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER UNIQUE NOT NULL,
        email TEXT NOT NULL,
        name TEXT NOT NULL,
        surname TEXT NOT NULL,
        role TEXT NOT NULL,
        profile_picture TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_sync TEXT
      )
    ''');

    // Table favorites
    await db.execute('''
      CREATE TABLE $_favoritesTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        event_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(user_id, event_id)
      )
    ''');

    // Table events
    await db.execute('''
      CREATE TABLE $_eventsTableName (
        event_id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        location TEXT,
        latitude REAL,
        longitude REAL,
        start_at TEXT NOT NULL,
        end_at TEXT,
        category TEXT,
        image_url TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_sync TEXT
      )
    ''');

    // Table notifications
    await db.execute('''
      CREATE TABLE $_notificationsTableName (
        notification_id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        event_ids TEXT NOT NULL,
        created_by INTEGER NOT NULL,
        sent_count INTEGER NOT NULL DEFAULT 0,
        failed_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_sync TEXT
      )
    ''');

    // Table user_notifications
    await db.execute('''
      CREATE TABLE $_userNotificationsTableName (
        user_notification_id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        notification_id INTEGER NOT NULL,
        event_id INTEGER,
        read INTEGER NOT NULL DEFAULT 0,
        read_at TEXT,
        hidden INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_sync TEXT
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Migration de la base de données: version $oldVersion -> $newVersion');
    
    if (oldVersion < 2) {
      // Ajouter la table favorites pour les versions < 2
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_favoritesTableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          event_id INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(user_id, event_id)
        )
      ''');
    }
    if (oldVersion < 3) {
      // Ajouter la table events pour les versions < 3
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_eventsTableName (
          event_id INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT,
          location TEXT,
          latitude REAL,
          longitude REAL,
          start_at TEXT NOT NULL,
          end_at TEXT,
          category TEXT,
          image_url TEXT,
          created_by TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          last_sync TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      // Ajouter les tables notifications pour les versions < 4
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_notificationsTableName (
          notification_id INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          event_ids TEXT NOT NULL,
          created_by INTEGER NOT NULL,
          sent_count INTEGER NOT NULL DEFAULT 0,
          failed_count INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          last_sync TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_userNotificationsTableName (
          user_notification_id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL,
          notification_id INTEGER NOT NULL,
          event_id INTEGER,
          read INTEGER NOT NULL DEFAULT 0,
          read_at TEXT,
          hidden INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          last_sync TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      // Ajouter la colonne profile_picture pour les versions < 5
      print('Ajout de la colonne profile_picture à la table users...');
      try {
        // Vérifier d'abord si la colonne existe
        final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info($_tableName)');
        final hasProfilePicture = columns.any((col) => col['name'] == 'profile_picture');
        
        if (!hasProfilePicture) {
          await db.execute('ALTER TABLE $_tableName ADD COLUMN profile_picture TEXT');
          print('Colonne profile_picture ajoutée avec succès !');
        } else {
          print('La colonne profile_picture existe déjà.');
        }
      } catch (e) {
        // La colonne existe peut-être déjà, ignorer l'erreur
        print('Erreur lors de l\'ajout de profile_picture: $e');
        // Essayer quand même de continuer
      }
    }
    
    print('Migration terminée.');
  }

  static Future<void> insertOrUpdateUser(UserModel user) async {
    final db = await database;
    await db.insert(
      _tableName,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    return List.generate(maps.length, (i) => UserModel.fromMap(maps[i]));
  }

  static Future<UserModel?> getUserById(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  static Future<UserModel?> getCurrentUser() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'last_sync DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  static Future<void> deleteUser(int userId) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  static Future<void> clearAllUsers() async {
    final db = await database;
    await db.delete(_tableName);
  }

  static Future<void> updateLastSync(int userId) async {
    final db = await database;
    await db.update(
      _tableName,
      {'last_sync': DateTime.now().toIso8601String()},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  static Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // ========== MÉTHODES POUR LES FAVORIS ==========

  /// Insère ou met à jour un favori dans le cache local
  static Future<void> insertOrUpdateFavorite({
    required int userId,
    required int eventId,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      _favoritesTableName,
      {
        'user_id': userId,
        'event_id': eventId,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Supprime un favori du cache local
  static Future<void> deleteFavorite({
    required int userId,
    required int eventId,
  }) async {
    final db = await database;
    await db.delete(
      _favoritesTableName,
      where: 'user_id = ? AND event_id = ?',
      whereArgs: [userId, eventId],
    );
  }

  /// Récupère tous les favoris d'un utilisateur depuis le cache local
  static Future<List<int>> getFavoriteEventIds(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _favoritesTableName,
      columns: ['event_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return maps.map((map) => map['event_id'] as int).toList();
  }

  /// Vérifie si un événement est en favori pour un utilisateur
  static Future<bool> isFavorite({
    required int userId,
    required int eventId,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _favoritesTableName,
      where: 'user_id = ? AND event_id = ?',
      whereArgs: [userId, eventId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// Synchronise les favoris depuis l'API (remplace tous les favoris existants)
  static Future<void> syncFavorites({
    required int userId,
    required List<int> eventIds,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Commencer une transaction pour garantir la cohérence
    await db.transaction((txn) async {
      // Supprimer tous les favoris existants pour cet utilisateur
      await txn.delete(
        _favoritesTableName,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Insérer les nouveaux favoris
      for (final eventId in eventIds) {
        await txn.insert(
          _favoritesTableName,
          {
            'user_id': userId,
            'event_id': eventId,
            'created_at': now,
            'updated_at': now,
          },
        );
      }
    });
  }

  /// Supprime tous les favoris d'un utilisateur
  static Future<void> clearFavorites(int userId) async {
    final db = await database;
    await db.delete(
      _favoritesTableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Supprime tous les favoris de tous les utilisateurs
  static Future<void> clearAllFavorites() async {
    final db = await database;
    await db.delete(_favoritesTableName);
  }

  // ========== MÉTHODES POUR LES ÉVÉNEMENTS ==========

  /// Convertit un EventItem en Map pour la base de données
  static Map<String, dynamic> _eventToMap(Map<String, dynamic> eventJson) {
    final now = DateTime.now().toIso8601String();
    return {
      'event_id': eventJson['event_id'] as int,
      'title': eventJson['title'] as String,
      'description': eventJson['description'] as String?,
      'location': eventJson['location'] as String?,
      'latitude': eventJson['latitude'] != null 
          ? (eventJson['latitude'] is num 
              ? eventJson['latitude'].toDouble() 
              : double.tryParse(eventJson['latitude'].toString()))
          : null,
      'longitude': eventJson['longitude'] != null
          ? (eventJson['longitude'] is num
              ? eventJson['longitude'].toDouble()
              : double.tryParse(eventJson['longitude'].toString()))
          : null,
      'start_at': eventJson['startAt'] as String,
      'end_at': eventJson['endAt'] as String?,
      'category': eventJson['category'] as String?,
      'image_url': eventJson['image_url'] as String?,
      'created_by': eventJson['created_by']?.toString(),
      'created_at': now,
      'updated_at': now,
      'last_sync': now,
    };
  }

  /// Convertit un Map de la base de données en EventItem JSON
  static Map<String, dynamic> _mapToEventJson(Map<String, dynamic> map) {
    return {
      'event_id': map['event_id'] as int,
      'title': map['title'] as String,
      'description': map['description'] as String?,
      'location': map['location'] as String?,
      'latitude': map['latitude'] as double?,
      'longitude': map['longitude'] as double?,
      'startAt': map['start_at'] as String,
      'endAt': map['end_at'] as String?,
      'category': map['category'] as String?,
      'image_url': map['image_url'] as String?,
      'created_by': map['created_by'] as String?,
    };
  }

  /// Sauvegarde une liste d'événements dans le cache local
  static Future<void> saveEvents(List<Map<String, dynamic>> eventsJson) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // Supprimer tous les événements existants
      await txn.delete(_eventsTableName);

      // Insérer les nouveaux événements
      for (final eventJson in eventsJson) {
        final eventMap = _eventToMap(eventJson);
        await txn.insert(
          _eventsTableName,
          eventMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    print(' ${eventsJson.length} événements sauvegardés dans le cache local');
  }

  /// Récupère tous les événements depuis le cache local
  static Future<List<Map<String, dynamic>>> getAllEvents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _eventsTableName,
      orderBy: 'start_at ASC',
    );
    
    return maps.map((map) => _mapToEventJson(map)).toList();
  }

  /// Récupère un événement par son ID depuis le cache local
  static Future<Map<String, dynamic>?> getEventById(int eventId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _eventsTableName,
      where: 'event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return _mapToEventJson(maps.first);
    }
    return null;
  }

  /// Supprime tous les événements du cache local
  static Future<void> clearAllEvents() async {
    final db = await database;
    await db.delete(_eventsTableName);
  }

  /// Met à jour la date de synchronisation des événements
  static Future<void> updateEventsLastSync() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      _eventsTableName,
      {'last_sync': now},
    );
  }

  // ========== MÉTHODES POUR LES NOTIFICATIONS ==========

  /// Sauvegarde une liste de notifications dans le cache local
  static Future<void> saveNotifications(List<Map<String, dynamic>> notificationsJson) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // Supprimer toutes les notifications existantes
      await txn.delete(_notificationsTableName);

      // Insérer les nouvelles notifications
      for (final notificationJson in notificationsJson) {
        await txn.insert(
          _notificationsTableName,
          {
            'notification_id': notificationJson['notification_id'] as int,
            'title': notificationJson['title'] as String,
            'body': notificationJson['body'] as String,
            'event_ids': notificationJson['event_ids'] is String 
                ? notificationJson['event_ids'] 
                : (notificationJson['event_ids'] as List).map((e) => e.toString()).join(','),
            'created_by': notificationJson['created_by'] as int,
            'sent_count': notificationJson['sent_count'] as int? ?? 0,
            'failed_count': notificationJson['failed_count'] as int? ?? 0,
            'created_at': notificationJson['created_at'] as String? ?? now,
            'updated_at': notificationJson['updated_at'] as String? ?? now,
            'last_sync': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    print(' ${notificationsJson.length} notifications sauvegardées dans le cache local');
  }

  /// Récupère toutes les notifications depuis le cache local
  static Future<List<Map<String, dynamic>>> getAllNotifications() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _notificationsTableName,
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) {
      // Convertir event_ids de String vers List<int>
      final eventIdsStr = map['event_ids'] as String;
      final eventIds = eventIdsStr.isNotEmpty
          ? eventIdsStr.split(',').map((e) => int.tryParse(e.trim()) ?? 0).where((e) => e > 0).toList()
          : <int>[];
      
      return {
        'notification_id': map['notification_id'] as int,
        'title': map['title'] as String,
        'body': map['body'] as String,
        'event_ids': eventIds,
        'created_by': map['created_by'] as int,
        'sent_count': map['sent_count'] as int,
        'failed_count': map['failed_count'] as int,
        'created_at': map['created_at'] as String,
        'updated_at': map['updated_at'] as String,
      };
    }).toList();
  }

  /// Supprime toutes les notifications du cache local
  static Future<void> clearAllNotifications() async {
    final db = await database;
    await db.delete(_notificationsTableName);
  }

  // ========== MÉTHODES POUR LES USER_NOTIFICATIONS ==========

  /// Sauvegarde les notifications reçues par un utilisateur dans le cache local
  static Future<void> saveUserNotifications({
    required int userId,
    required List<Map<String, dynamic>> userNotificationsJson,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // Supprimer toutes les notifications de cet utilisateur
      await txn.delete(
        _userNotificationsTableName,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Insérer les nouvelles notifications
      for (final userNotificationJson in userNotificationsJson) {
        await txn.insert(
          _userNotificationsTableName,
          {
            'user_notification_id': userNotificationJson['user_notification_id'] as int,
            'user_id': userId,
            'notification_id': userNotificationJson['notification_id'] as int,
            'event_id': userNotificationJson['event_id'] as int?,
            'read': (userNotificationJson['read'] as bool? ?? false) ? 1 : 0,
            'read_at': userNotificationJson['read_at'] as String?,
            'hidden': (userNotificationJson['hidden'] as bool? ?? false) ? 1 : 0,
            'created_at': userNotificationJson['created_at'] as String? ?? now,
            'updated_at': userNotificationJson['updated_at'] as String? ?? now,
            'last_sync': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    print(' ${userNotificationsJson.length} notifications utilisateur sauvegardées dans le cache local');
  }

  /// Récupère toutes les notifications reçues par un utilisateur depuis le cache local
  /// Fait un JOIN avec les tables notifications et events pour récupérer les données complètes
  static Future<List<Map<String, dynamic>>> getUserNotifications(int userId) async {
    final db = await database;
    
    // Faire un JOIN pour récupérer les données complètes
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        un.user_notification_id,
        un.user_id,
        un.notification_id,
        un.event_id,
        un.read,
        un.read_at,
        un.hidden,
        un.created_at,
        un.updated_at,
        n.title,
        n.body,
        e.title as event_title,
        e.location as event_location
      FROM $_userNotificationsTableName un
      LEFT JOIN $_notificationsTableName n ON un.notification_id = n.notification_id
      LEFT JOIN $_eventsTableName e ON un.event_id = e.event_id
      WHERE un.user_id = ? AND un.hidden = 0
      ORDER BY un.created_at DESC
    ''', [userId]);
    
    return maps.map((map) => {
      'user_notification_id': map['user_notification_id'] as int,
      'user_id': map['user_id'] as int,
      'notification_id': map['notification_id'] as int,
      'event_id': map['event_id'] as int?,
      'read': (map['read'] as int) == 1,
      'read_at': map['read_at'] as String?,
      'hidden': (map['hidden'] as int) == 1,
      'created_at': map['created_at'] as String,
      'updated_at': map['updated_at'] as String?,
      'title': map['title'] as String? ?? 'Notification',
      'body': map['body'] as String? ?? '',
      'event_title': map['event_title'] as String?,
      'event_location': map['event_location'] as String?,
    }).toList();
  }

  /// Marque une notification comme lue dans le cache local
  static Future<void> markUserNotificationAsRead({
    required int userId,
    required int userNotificationId,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      _userNotificationsTableName,
      {
        'read': 1,
        'read_at': now,
      },
      where: 'user_notification_id = ? AND user_id = ?',
      whereArgs: [userNotificationId, userId],
    );
  }

  /// Marque toutes les notifications d'un utilisateur comme lues dans le cache local
  static Future<void> markAllUserNotificationsAsRead(int userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      _userNotificationsTableName,
      {
        'read': 1,
        'read_at': now,
      },
      where: 'user_id = ? AND read = 0',
      whereArgs: [userId],
    );
  }

  /// Masque une notification dans le cache local
  static Future<void> hideUserNotification({
    required int userId,
    required int userNotificationId,
  }) async {
    final db = await database;
    await db.update(
      _userNotificationsTableName,
      {'hidden': 1},
      where: 'user_notification_id = ? AND user_id = ?',
      whereArgs: [userNotificationId, userId],
    );
  }

  /// Supprime toutes les notifications d'un utilisateur du cache local
  static Future<void> clearUserNotifications(int userId) async {
    final db = await database;
    await db.delete(
      _userNotificationsTableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Supprime toutes les notifications utilisateur du cache local
  static Future<void> clearAllUserNotifications() async {
    final db = await database;
    await db.delete(_userNotificationsTableName);
  }
}
