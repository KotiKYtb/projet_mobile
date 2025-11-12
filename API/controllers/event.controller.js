const db = require("../models");
const Event = db.event;

exports.list = async function(req, res) {
  try {
    const { page = 1, pageSize = 50, updatedSince } = req.query;
    const where = {};
    if (updatedSince) {
      where.updated_at = { [db.Sequelize.Op.gte]: new Date(updatedSince) };
    }
    const limit = Math.min(parseInt(pageSize), 200) || 50;
    const offset = (Math.max(parseInt(page), 1) - 1) * limit;
    const { rows, count } = await Event.findAndCountAll({
      where,
      order: [["updated_at", "DESC"]],
      limit,
      offset
    });
    res.json({ data: rows, total: count, page: parseInt(page), pageSize: limit });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

exports.getById = async function(req, res) {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) return res.status(404).json({ message: "Not found" });
    res.json(event);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

exports.create = async function(req, res) {
  try {
    // Utiliser req.userId du middleware authJwt pour created_by
    const now = new Date();
    const eventData = {
      ...req.body,
      created_by: req.userId || req.body.created_by,
      // S'assurer que les timestamps sont définis (au cas où Sequelize ne les gère pas automatiquement)
      created_at: now,
      updated_at: now
    };
    const event = await Event.create(eventData);
    res.status(201).json(event);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
};

exports.update = async function(req, res) {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) return res.status(404).json({ message: "Not found" });
    await event.update(req.body);
    res.json(event);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
};

exports.remove = async function(req, res) {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) return res.status(404).json({ message: "Not found" });
    await event.destroy();
    res.status(204).send();
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};


