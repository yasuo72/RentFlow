const { sendError } = require('../utils/response');

function allowRoles(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return sendError(res, {
        statusCode: 403,
        message: 'You do not have permission to perform this action.',
      });
    }

    return next();
  };
}

module.exports = allowRoles;
