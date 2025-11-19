const swaggerJsdoc = require('swagger-jsdoc');
const path = require('path');

// Fonction pour obtenir l'URL du serveur depuis les variables d'environnement ou utiliser localhost par défaut
function getServerUrl() {
  const host = process.env.API_IP || 'localhost';
  const port = process.env.API_PORT || process.env.PORT || '8080';
  const protocol = process.env.API_PROTOCOL || 'http';
  return `${protocol}://${host}:${port}`;
}

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Angers Mobile App API',
      version: '1.0.0',
      description: 'Documentation complète de l\'API pour l\'application mobile Angers',
      contact: {
        name: 'API Support',
      },
    },
    servers: [
      {
        url: getServerUrl(),
        description: 'Serveur API',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        User: {
          type: 'object',
          properties: {
            user_id: {
              type: 'integer',
              description: 'ID unique de l\'utilisateur',
              example: 1
            },
            email: {
              type: 'string',
              format: 'email',
              description: 'Adresse email',
              example: 'user@example.com'
            },
            name: {
              type: 'string',
              description: 'Prénom de l\'utilisateur',
              example: 'Jean'
            },
            surname: {
              type: 'string',
              description: 'Nom de famille de l\'utilisateur',
              example: 'Dupont'
            },
            role: {
              type: 'string',
              description: 'Rôle de l\'utilisateur',
              enum: ['user', 'admin', 'organisation'],
              example: 'user'
            },
            profile_picture: {
              type: 'string',
              description: 'URL de la photo de profil',
              nullable: true,
              example: 'http://localhost:8080/images/profiles/profile-1234567890-123456789.png'
            },
            created_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date de création'
            },
            updated_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date de mise à jour'
            }
          }
        },
        Event: {
          type: 'object',
          properties: {
            event_id: {
              type: 'integer',
              description: 'ID unique de l\'événement',
              example: 1
            },
            title: {
              type: 'string',
              description: 'Titre de l\'événement',
              example: 'Concert de jazz'
            },
            description: {
              type: 'string',
              description: 'Description de l\'événement',
              example: 'Un magnifique concert de jazz en plein air'
            },
            startAt: {
              type: 'string',
              format: 'date-time',
              description: 'Date et heure de début de l\'événement'
            },
            endAt: {
              type: 'string',
              format: 'date-time',
              description: 'Date et heure de fin de l\'événement',
              nullable: true
            },
            location: {
              type: 'string',
              description: 'Adresse du lieu de l\'événement',
              example: 'Place du Ralliement, Angers',
              nullable: true
            },
            latitude: {
              type: 'number',
              format: 'float',
              description: 'Latitude GPS',
              example: 47.4739,
              nullable: true
            },
            longitude: {
              type: 'number',
              format: 'float',
              description: 'Longitude GPS',
              example: -0.5517,
              nullable: true
            },
            category: {
              type: 'string',
              description: 'Catégorie de l\'événement',
              example: 'Musique',
              nullable: true
            },
            image_url: {
              type: 'string',
              description: 'URL de l\'image de l\'événement',
              nullable: true
            },
            created_by: {
              type: 'integer',
              description: 'ID de l\'utilisateur créateur',
              example: 1
            },
            created_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date de création'
            },
            updated_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date de mise à jour'
            }
          }
        },
        Favorite: {
          type: 'object',
          properties: {
            user_id: {
              type: 'integer',
              description: 'ID de l\'utilisateur',
              example: 1
            },
            event_id: {
              type: 'integer',
              description: 'ID de l\'événement',
              example: 1
            },
            created_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date d\'ajout aux favoris'
            },
            updated_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date de mise à jour'
            }
          }
        },
        SignupRequest: {
          type: 'object',
          required: ['email', 'password'],
          properties: {
            email: {
              type: 'string',
              format: 'email',
              description: 'Adresse email',
              example: 'user@example.com'
            },
            password: {
              type: 'string',
              description: 'Mot de passe',
              example: 'password123'
            },
            name: {
              type: 'string',
              description: 'Prénom',
              example: 'Jean'
            },
            surname: {
              type: 'string',
              description: 'Nom de famille',
              example: 'Dupont'
            },
            role: {
              type: 'string',
              description: 'Rôle (par défaut: user)',
              enum: ['user', 'admin', 'organisation'],
              example: 'user'
            }
          }
        },
        SigninRequest: {
          type: 'object',
          required: ['email', 'password'],
          properties: {
            email: {
              type: 'string',
              format: 'email',
              description: 'Adresse email',
              example: 'user@example.com'
            },
            password: {
              type: 'string',
              description: 'Mot de passe',
              example: 'password123'
            }
          }
        },
        SigninResponse: {
          type: 'object',
          properties: {
            id: {
              type: 'integer',
              description: 'ID de l\'utilisateur'
            },
            email: {
              type: 'string',
              description: 'Email de l\'utilisateur'
            },
            name: {
              type: 'string',
              description: 'Prénom'
            },
            surname: {
              type: 'string',
              description: 'Nom de famille'
            },
            role: {
              type: 'string',
              description: 'Rôle'
            },
            accessToken: {
              type: 'string',
              description: 'Token JWT d\'accès (valide 24h)'
            },
            refreshToken: {
              type: 'string',
              description: 'Token JWT de rafraîchissement (valide 7 jours)'
            },
            roles: {
              type: 'array',
              items: {
                type: 'string'
              },
              description: 'Liste des rôles'
            }
          }
        },
        RefreshTokenRequest: {
          type: 'object',
          required: ['refreshToken'],
          properties: {
            refreshToken: {
              type: 'string',
              description: 'Token de rafraîchissement'
            }
          }
        },
        RefreshTokenResponse: {
          type: 'object',
          properties: {
            accessToken: {
              type: 'string',
              description: 'Nouveau token JWT d\'accès'
            }
          }
        },
        EventListResponse: {
          type: 'object',
          properties: {
            data: {
              type: 'array',
              items: {
                $ref: '#/components/schemas/Event'
              }
            },
            total: {
              type: 'integer',
              description: 'Nombre total d\'événements'
            },
            page: {
              type: 'integer',
              description: 'Numéro de page actuelle'
            },
            pageSize: {
              type: 'integer',
              description: 'Taille de la page'
            }
          }
        },
        FavoriteListResponse: {
          type: 'object',
          properties: {
            favorites: {
              type: 'array',
              items: {
                $ref: '#/components/schemas/Favorite'
              }
            }
          }
        },
        AddFavoriteRequest: {
          type: 'object',
          required: ['event_id'],
          properties: {
            event_id: {
              type: 'integer',
              description: 'ID de l\'événement à ajouter aux favoris',
              example: 1
            }
          }
        },
        ChangePasswordRequest: {
          type: 'object',
          required: ['oldPassword', 'newPassword'],
          properties: {
            oldPassword: {
              type: 'string',
              description: 'Ancien mot de passe'
            },
            newPassword: {
              type: 'string',
              description: 'Nouveau mot de passe (minimum 6 caractères)',
              minLength: 6
            }
          }
        },
        UpdateRoleRequest: {
          type: 'object',
          required: ['role'],
          properties: {
            role: {
              type: 'string',
              enum: ['user', 'admin', 'organisation'],
              description: 'Nouveau rôle'
            }
          }
        },
        Error: {
          type: 'object',
          properties: {
            message: {
              type: 'string',
              description: 'Message d\'erreur'
            },
            error: {
              type: 'string',
              description: 'Détails de l\'erreur'
            }
          }
        },
        Notification: {
          type: 'object',
          properties: {
            notification_id: {
              type: 'integer',
              description: 'ID unique de la notification',
              example: 1
            },
            title: {
              type: 'string',
              description: 'Titre de la notification',
              example: 'Nouvel événement disponible'
            },
            body: {
              type: 'string',
              description: 'Corps de la notification',
              example: 'Un nouvel événement a été ajouté'
            },
            event_ids: {
              type: 'array',
              items: {
                type: 'integer'
              },
              description: 'Liste des IDs d\'événements concernés'
            },
            created_by: {
              type: 'integer',
              description: 'ID de l\'utilisateur créateur',
              example: 1
            },
            sent_count: {
              type: 'integer',
              description: 'Nombre de notifications envoyées avec succès',
              example: 10
            },
            failed_count: {
              type: 'integer',
              description: 'Nombre de notifications échouées',
              example: 0
            },
            created_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date de création'
            },
            updated_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date de mise à jour'
            }
          }
        },
        UserNotification: {
          type: 'object',
          properties: {
            user_notification_id: {
              type: 'integer',
              description: 'ID unique de la notification utilisateur',
              example: 1
            },
            user_id: {
              type: 'integer',
              description: 'ID de l\'utilisateur',
              example: 1
            },
            notification_id: {
              type: 'integer',
              description: 'ID de la notification',
              example: 1
            },
            event_id: {
              type: 'integer',
              description: 'ID de l\'événement concerné',
              example: 1,
              nullable: true
            },
            read: {
              type: 'boolean',
              description: 'Indique si la notification a été lue',
              example: false
            },
            read_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date de lecture',
              nullable: true
            },
            hidden: {
              type: 'boolean',
              description: 'Indique si la notification est masquée',
              example: false
            },
            created_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date de création'
            },
            title: {
              type: 'string',
              description: 'Titre de la notification',
              example: 'Nouvel événement disponible'
            },
            body: {
              type: 'string',
              description: 'Corps de la notification',
              example: 'Un nouvel événement a été ajouté'
            },
            event_title: {
              type: 'string',
              description: 'Titre de l\'événement concerné',
              nullable: true
            },
            event_location: {
              type: 'string',
              description: 'Localisation de l\'événement concerné',
              nullable: true
            }
          }
        },
        FCMToken: {
          type: 'object',
          properties: {
            token_id: {
              type: 'integer',
              description: 'ID unique du token',
              example: 1
            },
            user_id: {
              type: 'integer',
              description: 'ID de l\'utilisateur',
              example: 1
            },
            token: {
              type: 'string',
              description: 'Token FCM',
              example: 'fcm_token_example_123456'
            },
            device_type: {
              type: 'string',
              enum: ['android', 'ios', 'web'],
              description: 'Type de dispositif',
              example: 'android'
            },
            active: {
              type: 'boolean',
              description: 'Indique si le token est actif',
              example: true
            },
            created_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date de création'
            },
            updated_at: {
              type: 'string',
              format: 'date-time',
              description: 'Date de mise à jour'
            }
          }
        },
        UploadResponse: {
          type: 'object',
          properties: {
            message: {
              type: 'string',
              description: 'Message de confirmation',
              example: 'Image uploadée avec succès'
            },
            imageUrl: {
              type: 'string',
              description: 'URL complète de l\'image uploadée',
              example: 'http://localhost:8080/images/events/event-1234567890-123456789.jpg'
            },
            filename: {
              type: 'string',
              description: 'Nom du fichier uploadé',
              example: 'event-1234567890-123456789.jpg'
            }
          }
        },
        NotificationListResponse: {
          type: 'object',
          properties: {
            notifications: {
              type: 'array',
              items: {
                $ref: '#/components/schemas/Notification'
              }
            }
          }
        },
        UserNotificationListResponse: {
          type: 'object',
          properties: {
            notifications: {
              type: 'array',
              items: {
                $ref: '#/components/schemas/UserNotification'
              }
            }
          }
        },
        FCMTokenListResponse: {
          type: 'object',
          properties: {
            tokens: {
              type: 'array',
              items: {
                $ref: '#/components/schemas/FCMToken'
              }
            }
          }
        },
        RegisterTokenRequest: {
          type: 'object',
          required: ['token'],
          properties: {
            token: {
              type: 'string',
              description: 'Token FCM du dispositif',
              example: 'fcm_token_example_123456'
            },
            device_type: {
              type: 'string',
              enum: ['android', 'ios', 'web'],
              description: 'Type de dispositif',
              example: 'android'
            }
          }
        },
        RemoveTokenRequest: {
          type: 'object',
          required: ['token'],
          properties: {
            token: {
              type: 'string',
              description: 'Token FCM à supprimer',
              example: 'fcm_token_example_123456'
            }
          }
        },
        CreateNotificationRequest: {
          type: 'object',
          required: ['eventIds', 'title', 'body'],
          properties: {
            eventIds: {
              type: 'array',
              items: {
                type: 'integer'
              },
              description: 'Liste des IDs d\'événements',
              example: [1, 2, 3]
            },
            title: {
              type: 'string',
              description: 'Titre de la notification',
              example: 'Nouvel événement disponible'
            },
            body: {
              type: 'string',
              description: 'Corps de la notification',
              example: 'Un nouvel événement a été ajouté'
            }
          }
        },
        SendNotificationRequest: {
          type: 'object',
          required: ['title', 'body'],
          properties: {
            title: {
              type: 'string',
              description: 'Titre de la notification',
              example: 'Nouvel événement disponible'
            },
            body: {
              type: 'string',
              description: 'Corps de la notification',
              example: 'Un nouvel événement a été ajouté'
            },
            data: {
              type: 'object',
              description: 'Données supplémentaires à envoyer avec la notification',
              additionalProperties: true
            }
          }
        },
        SendNotificationToUserRequest: {
          type: 'object',
          required: ['userId', 'title', 'body'],
          properties: {
            userId: {
              type: 'integer',
              description: 'ID de l\'utilisateur destinataire',
              example: 1
            },
            title: {
              type: 'string',
              description: 'Titre de la notification',
              example: 'Nouvel événement disponible'
            },
            body: {
              type: 'string',
              description: 'Corps de la notification',
              example: 'Un nouvel événement a été ajouté'
            },
            data: {
              type: 'object',
              description: 'Données supplémentaires à envoyer avec la notification',
              additionalProperties: true
            }
          }
        },
        SendNotificationToEventRequest: {
          type: 'object',
          required: ['eventId', 'title', 'body'],
          properties: {
            eventId: {
              type: 'integer',
              description: 'ID de l\'événement',
              example: 1
            },
            title: {
              type: 'string',
              description: 'Titre de la notification',
              example: 'Nouvel événement disponible'
            },
            body: {
              type: 'string',
              description: 'Corps de la notification',
              example: 'Un nouvel événement a été ajouté'
            },
            data: {
              type: 'object',
              description: 'Données supplémentaires à envoyer avec la notification',
              additionalProperties: true
            }
          }
        },
        SendNotificationToEventsRequest: {
          type: 'object',
          required: ['eventIds', 'title', 'body'],
          properties: {
            eventIds: {
              type: 'array',
              items: {
                type: 'integer'
              },
              description: 'Liste des IDs d\'événements',
              example: [1, 2, 3]
            },
            title: {
              type: 'string',
              description: 'Titre de la notification',
              example: 'Nouvel événement disponible'
            },
            body: {
              type: 'string',
              description: 'Corps de la notification',
              example: 'Un nouvel événement a été ajouté'
            },
            data: {
              type: 'object',
              description: 'Données supplémentaires à envoyer avec la notification',
              additionalProperties: true
            }
          }
        },
        UpdateNotificationRequest: {
          type: 'object',
          required: ['title', 'body', 'eventIds'],
          properties: {
            title: {
              type: 'string',
              description: 'Titre de la notification',
              example: 'Nouvel événement disponible'
            },
            body: {
              type: 'string',
              description: 'Corps de la notification',
              example: 'Un nouvel événement a été ajouté'
            },
            eventIds: {
              type: 'array',
              items: {
                type: 'integer'
              },
              description: 'Liste des IDs d\'événements',
              example: [1, 2, 3]
            }
          }
        }
      },
    },
  },
  apis: [
    path.join(__dirname, '../routes/*.js')
  ],
};

// Générer la spec par défaut (sans requête)
let swaggerSpec;
try {
  swaggerSpec = swaggerJsdoc(options);
  
  // S'assurer que la spec a bien tous les champs requis
  if (!swaggerSpec.openapi && !swaggerSpec.swagger) {
    swaggerSpec.openapi = '3.0.0';
  }
  if (!swaggerSpec.info) {
    swaggerSpec.info = options.definition.info;
  }
  if (!swaggerSpec.paths) {
    swaggerSpec.paths = {};
  }
  if (!swaggerSpec.components) {
    swaggerSpec.components = options.definition.components;
  }
  
  // Valider que le JSON est valide
  JSON.stringify(swaggerSpec);
} catch (error) {
  console.error('Erreur lors de la génération de la documentation Swagger:', error.message);
  console.error('Stack:', error.stack);
  // En cas d'erreur, retourne une définition minimale pour que l'application puisse démarrer
  swaggerSpec = {
    openapi: '3.0.0',
    info: options.definition.info,
    servers: options.definition.servers,
    components: options.definition.components,
    paths: {}
  };
}

// Fonction pour obtenir la spec Swagger avec l'URL mise à jour depuis la requête
function getSwaggerSpec(req) {
  // Cloner la spec pour éviter de modifier l'original
  const spec = JSON.parse(JSON.stringify(swaggerSpec));
  
  // Si une requête est fournie, utiliser son URL
  if (req) {
    const protocol = req.protocol || 'http';
    const host = req.get('host') || 'localhost:8080';
    const baseUrl = `${protocol}://${host}`;
    
    // Mettre à jour l'URL du serveur dans la spec
    if (spec.servers && spec.servers.length > 0) {
      spec.servers[0].url = baseUrl;
    }
  }
  
  return spec;
}

// Exporter à la fois la spec par défaut et la fonction pour générer dynamiquement
module.exports = swaggerSpec;
module.exports.getSwaggerSpec = getSwaggerSpec;