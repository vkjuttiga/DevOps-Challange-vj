const express = require('express');
const helmet = require('helmet');
const morgan = require('morgan');
const promClient = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;
const ENV = process.env.NODE_ENV || 'development';

// Security middleware
app.use(helmet());
app.use(morgan('combined'));
app.use(express.json());

// Prometheus metrics
const collectDefaultMetrics = promClient.collectDefaultMetrics;
collectDefaultMetrics({ timeout: 5000 });

const httpRequestDurationMicroseconds = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

// Request duration middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDurationMicroseconds
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .observe(duration);
  });
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Readiness probe endpoint
app.get('/ready', (req, res) => {
  res.status(200).json({
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', promClient.register.contentType);
    res.end(await promClient.register.metrics());
  } catch (err) {
    res.status(500).end(err);
  }
});

// Main application endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to DevOps Demo Application',
    version: process.env.APP_VERSION || '1.0.0',
    environment: ENV,
    endpoints: {
      health: '/health',
      ready: '/ready',
      metrics: '/metrics',
      api: '/api/v1'
    }
  });
});

// API v1 routes
app.get('/api/v1/info', (req, res) => {
  res.json({
    app: 'devops-demo-app',
    version: process.env.APP_VERSION || '1.0.0',
    environment: ENV,
    kubernetes: {
      namespace: process.env.NAMESPACE || 'default',
      podName: process.env.POD_NAME || 'unknown',
      nodeName: process.env.NODE_NAME || 'unknown'
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal Server Error' });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT} in ${ENV} mode`);
  console.log(`📊 Metrics available at http://localhost:${PORT}/metrics`);
  console.log(`❤️  Health check at http://localhost:${PORT}/health`);
});

module.exports = app;
