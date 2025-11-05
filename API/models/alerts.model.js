module.exports = function(sequelize, Sequelize) {
  const Alert = sequelize.define(
    "alerts",
    {
      alert_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      title: {
        type: Sequelize.STRING,
        allowNull: false
      },
      message: {
        type: Sequelize.TEXT,
        allowNull: true
      },
      type: {
        type: Sequelize.STRING,
        allowNull: false
      },
      active: {
        type: Sequelize.BOOLEAN,
        allowNull: false
      },
      created_by: {
        type: Sequelize.STRING,
        allowNull: false
      }
    },
    {
      timestamps: true
    }
  );
  return Alert;
};