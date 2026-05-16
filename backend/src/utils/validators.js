const { body, param, query, validationResult } = require('express-validator');

function handleValidationErrors(req, res, next) {
  const result = validationResult(req);

  if (result.isEmpty()) {
    return next();
  }

  return res.status(422).json({
    success: false,
    message: 'Validation failed',
    errors: result.array().map((error) => ({
      field: error.path,
      message: error.msg,
    })),
  });
}

const mongoIdParam = (field = 'id') => (
  param(field).isMongoId().withMessage(`${field} must be a valid MongoDB id`)
);

const optionalMongoIdQuery = (field) => (
  query(field).optional().isMongoId().withMessage(`${field} must be a valid MongoDB id`)
);

const positiveNumberBody = (field) => (
  body(field).isFloat({ min: 0 }).withMessage(`${field} must be a positive number`)
);

module.exports = {
  body,
  param,
  query,
  handleValidationErrors,
  mongoIdParam,
  optionalMongoIdQuery,
  positiveNumberBody,
};
