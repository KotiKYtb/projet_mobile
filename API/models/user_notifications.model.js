module.exports = function(sequelize, Sequelize) {
  const UserNotification = sequelize.define(
    "user_notifications",
    {
      user_notification_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      user_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'users',
          key: 'user_id'
        }
      },
      notification_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'notifications',
          key: 'notification_id'
        }
      },
      event_id: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: {
          model: 'events',
          key: 'event_id'
        },
        comment: 'ID de l\'événement concerné par cette notification'
      },
      read: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false
      },
      read_at: {
        type: Sequelize.DATE,
        allowNull: true
      },
      hidden: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
        comment: 'Si true, la notification est masquée de l\'affichage'
      }
    },
    {
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
      indexes: [
        {
          fields: ['user_id']
        },
        {
          fields: ['notification_id']
        },
        {
          fields: ['read']
        }
      ]
    }
  );
  return UserNotification;
};

