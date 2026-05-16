const ActivityLog = require('../models/ActivityLog');

function loggerMiddleware(req, res, next) {
  req.logActivity = async ({
    action,
    details,
    entityType,
    entityId,
  }) => {
    if (!req.user) {
      return null;
    }

    return ActivityLog.create({
      user: req.user._id,
      userName: req.user.name,
      action,
      details,
      entityType,
      entityId,
    });
  };

  next();
}

module.exports = loggerMiddleware;
