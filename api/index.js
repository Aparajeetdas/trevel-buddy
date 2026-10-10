const { handler } = require('../proxy/server.js');

module.exports = async (req, res) => {
  // When rewritten by Vercel to /api, recover original path from x-matched-path
  if (req.headers['x-matched-path']) {
    req.url = req.headers['x-matched-path'];
  }
  return handler(req, res);
};
