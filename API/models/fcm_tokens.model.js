module.exports = function(sequelize, Sequelize) {
  const FCMToken = sequelize.define(
    "fcm_tokens",
    {
      token_id: {
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
      token: {
        type: Sequelize.STRING(500),
        allowNull: false,
        unique: true
      },
      device_type: {
        type: Sequelize.STRING,
        allowNull: true,
        comment: 'android, ios, web'
      },
      active: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      }
    },
    {
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
      indexes: [
        {
          unique: true,
          fields: ['token'],
          name: 'fcm_tokens_token_unique'
        },
        {
          fields: ['user_id'],
          name: 'fcm_tokens_user_id_idx'
        }
      ]
    }
  );

  return FCMToken;
};

