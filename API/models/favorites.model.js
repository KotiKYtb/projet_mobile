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
      timestamps: true
    }
  );
  return Favorite;
};