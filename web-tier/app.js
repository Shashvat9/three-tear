const express = require('express');
const app = express();
const port = 3000;

// A simple endpoint that might eventually call the app-tier
app.get('/', (req, res) => {
  res.send('Hello from the Web Tier! Trying to reach App Tier...');
  // In a real app, you'd make an HTTP request to the app-tier here
  // For example, using axios or node-fetch:
  // fetch('http://<app-tier-load-balancer-dns-name>/app')
  //   .then(response => response.text())
  //   .then(data => res.send(`Web Tier says: Hello! App Tier responded with: ${data}`))
  //   .catch(err => res.status(500).send(`Error connecting to app tier: ${err.message}`));
});

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.listen(port, () => {
  console.log(`Web tier listening at http://localhost:${port}`);
});