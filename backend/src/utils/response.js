function sendSuccess(res, {
  statusCode = 200,
  message = 'Success',
  data = null,
  meta = undefined,
} = {}) {
  return res.status(statusCode).json({
    success: true,
    message,
    data,
    meta,
  });
}

function sendError(res, {
  statusCode = 400,
  message = 'Something went wrong',
  errors = undefined,
} = {}) {
  return res.status(statusCode).json({
    success: false,
    message,
    errors,
  });
}

module.exports = {
  sendSuccess,
  sendError,
};
