module.exports = function(sequelize, Sequelize) {
    const Event = sequelize.define(
      "alerts",
      {
        event_id: {
          type: Sequelize.INTEGER,
          primaryKey: true,
          autoIncrement: true
        },
        user_id: {
          type: Sequelize.INTEGER,
          allowNull: false,
          foreignKey: 'user_id'
        },
        created_at: {
          type: Sequelize.DATE,
          allowNull: false
        },
        updated_at: {
          type: Sequelize.DATE,
          allowNull: false
        }
      }, {
        timestamps: true
      }
    );
    return Alert;
  };