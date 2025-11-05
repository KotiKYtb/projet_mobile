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
  origin: true, // Accepte toutes les origines pour le développement
  credentials: true
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
app.use('/api/users', usersRouter);

// simple route
app.get('/', function(req, res) {
  res.json({ message: "Bienvenu à l'application JWT AUTH EXPRESS MYSQL." });
});

// static files (place after route so '/' returns JSON)
app.use(express.static(path.join(__dirname, 'public')));

// database
const db = require("./models");
const shouldForceSync = process.env.RESET_DB === '1';
db.sequelize
  .sync(shouldForceSync ? { force: true } : { alter: true })
  .then(function() {
    if (shouldForceSync) {
      console.log('Database recreated with { force: true }');
    } else {
      console.log('Database synced');
    }
  })
  .catch(function(e) {
    console.error('Database sync failed:', e.message);
  });

// To recreate DB once: set env RESET_DB=1 before starting the server

// routes
require('./routes/auth.routes')(app);
require('./routes/user.routes')(app);
require('./routes/event.routes')(app);

// Note: Le serveur écoute via bin/www, pas ici
// Si vous lancez directement app.js, décommentez les lignes ci-dessous:
// const PORT = process.env.PORT || 8080;
// app.listen(PORT, '0.0.0.0', function() {
//   console.log(`Server is running on port ${PORT} and listening on all interfaces.`);
// });

// (debug route removed as roles/associations were refactored)

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
