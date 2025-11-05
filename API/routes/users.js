var express = require('express');
var router = express.Router();
const controller = require('../controllers/users.controller');
const { authJwt } = require('../middleware');

/* GET users listing. */
router.get('/', [authJwt.verifyToken], controller.list);

/* GET users listing (public route for testing). */
router.get('/public', controller.list);

/* PUT update user role (admin only). */
router.put('/:userId/role', [authJwt.verifyToken], controller.updateRole);

/* GET current user info. */
router.get('/me', [authJwt.verifyToken], controller.getCurrentUser);

module.exports = router;
