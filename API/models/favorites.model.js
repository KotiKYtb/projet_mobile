module.exports = function(sequelize, Sequelize) {
  const Favorite = sequelize.define(
    "favorites",
    {
      user_id: {
        type: Sequelize.INTEGER,
        allowNull: false
      },
      event_id: {
        type: Sequelize.INTEGER,
        allowNull: false
      }
    },
    {
      timestamps: true,
      indexes: [
        {
          unique: true,
          fields: ['user_id', 'event_id'],
          name: 'favorites_user_event_unique'
        }
      ]
    }
  );
  return Favorite;
};