module.exports = function(sequelize, Sequelize) {
  const Event = sequelize.define(
    "events",
    {
      event_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      title: {
        type: Sequelize.STRING,
        allowNull: false
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: true
      },
      startAt: {
        type: Sequelize.DATE,
        allowNull: false
      },
      endAt: {
        type: Sequelize.DATE,
        allowNull: true
      },
      location: {
        type: Sequelize.STRING,
        allowNull: true
      },
      latitude: {
        type: Sequelize.DECIMAL(10, 8),
        allowNull: true
      },
      longitude: {
        type: Sequelize.DECIMAL(11, 8),
        allowNull: true
      },
      category: {
        type: Sequelize.STRING,
        allowNull: true
      },
      image_url: {
        type: Sequelize.STRING,
        allowNull: true
      },
      created_by: {
        type: Sequelize.INTEGER,
        allowNull: false
      }
    },
    {
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at'
    }
  );

  return Event;
};