const errorHandler = (err, req, res, next) => {
  console.error('Error:', err.message);

  if (err.code === 'ECONNREFUSED' || err.name === 'AggregateError') {
    return res.status(503).json({
      error: 'Database service is unavailable. Start PostgreSQL and try again.',
      hint: 'After database is up, run: npm run db:init && npm run db:seed',
    });
  }

  if (err.code === '28P01') {
    return res.status(500).json({
      error: 'Database authentication failed. Check DB_USER and DB_PASSWORD in backend/.env',
    });
  }

  if (err.code === '3D000') {
    return res.status(500).json({
      error: 'Database does not exist. Create it, then run db:init and db:seed.',
    });
  }

  if (err.code === '42P01') {
    return res.status(500).json({
      error: 'Database tables are missing. Run: npm run db:init && npm run db:seed',
    });
  }
  
  if (err.name === 'MulterError') {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large. Maximum size is 5MB.' });
    }
    return res.status(400).json({ error: err.message });
  }

  if (err.code === '23505') {
    return res.status(409).json({ error: 'Resource already exists' });
  }

  if (err.code === '23503') {
    return res.status(400).json({ error: 'Referenced resource does not exist' });
  }

  if (err.code === '23502') {
    return res.status(400).json({ error: 'Missing required field in request data' });
  }

  const status = err.status || 500;
  const message = status === 500 ? 'Internal server error' : err.message;

  res.status(status).json({ error: message });
};

module.exports = errorHandler;
