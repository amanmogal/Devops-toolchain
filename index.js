const express = require('express');
const client = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3001;

// Create a Registry to register the metrics
const register = new client.Registry();

// Create a Gauge metric for random data
const randomGauge = new client.Gauge({
  name: 'random_metric',
  help: 'A random metric for testing',
  registers: [register],
});

// Update the gauge metric with random data every 10 seconds
setInterval(() => {
  const randomValue = Math.random() * 100; // Random value between 0 and 100
  randomGauge.set(randomValue);
}, 10000);

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/', (req, res) => {
  res.send('DevOps Toolchain Application');
});

// Start the server
app.listen(PORT, () => {
  console.log(`App listening at http://localhost:${PORT}`);
});
