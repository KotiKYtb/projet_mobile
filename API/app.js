var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
var createError = require('http-errors');
var cors = require('cors');

var indexRouter = require('./routes/index');
var usersRouter = require('./routes/users');

var app = express();
var corsOptions = {
  origin: "http://localhost:3000"
};

//app.set('views', path.join(__dirname, 'views'));
//app.set('view engine', 'jade');
app.use(cors(corsOptions));
app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use('/', indexRouter);
app.use('/users', usersRouter);

// simple route
app.get('/', function(req, res) {
  res.json({ message: "Bienvenu à l'application JWT AUTH EXPRESS MYSQL." });
});

// static files (place after route so '/' returns JSON)
app.use(express.static(path.join(__dirname, 'public')));

// database
const db = require("./models");
const Role = db.role;

// synchronize database (auto-migrate in dev) and ensure base roles exist
db.sequelize.sync({ alter: true }).then(async function() {
  try {
    await Role.findOrCreate({ where: { id: 1 }, defaults: { id: 1, name: 'user' } });
    await Role.findOrCreate({ where: { id: 2 }, defaults: { id: 2, name: 'moderator' } });
    await Role.findOrCreate({ where: { id: 3 }, defaults: { id: 3, name: 'admin' } });
    console.log('Base roles ensured');
  } catch (e) {
    console.error('Failed ensuring base roles:', e.message);
  }
});

// Drop and Resync Database with { force: true } on dev only
// db.sequelize.sync({ force: true }).then(() => {
//   console.log('Drop and Resync Database with { force: true }');
//   initial();
// });

// routes
require('./routes/auth.routes')(app);
require('./routes/user.routes')(app);
require('./routes/event.routes')(app);

// set port, listen for requests
const PORT = process.env.PORT || 8080;
app.listen(PORT, function() {
  console.log(`Server is running on port ${PORT}.`);
});

// DEBUG: expose all users with roles (and stored password hash)
// NOTE: For development only. Do NOT enable in production.
app.get('/api/debug/users', async function(req, res) {
  try {
    const users = await db.user.findAll();
    const data = await Promise.all(users.map(async function(u) {
      const roles = await u.getRoles();
      return {
        id: u.id,
        username: u.username,
        email: u.email,
        password_plain: u.password_plain,
        password: u.password, // hashed password as stored
        roles: roles.map(function(r) { return r.name; })
      };
    }));
    res.json(data);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// la fonction initial va créer 3 enregistrements dans la table role de la BDD
function initial() {
  Role.create({ id: 1, name: "user" });
  Role.create({ id: 2, name: "moderator" });
  Role.create({ id: 3, name: "admin" });
}

// catch 404 and forward to error handler
app.use(function(req, res, next) {
  next(createError(404));
});

// error handler
app.use(function(err, req, res, next) {
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};
  res.status(err.status || 500);
  res.json({ error: res.locals.message });
});

module.exports = app;
