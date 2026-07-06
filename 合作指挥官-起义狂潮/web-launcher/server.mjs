import express from 'express';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { bootstrapRouter } from './routes/bootstrap.mjs';
import { syncRouter } from './routes/sync.mjs';
import { scenarioRouter } from './routes/scenario.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = 17761;

const app = express();
app.use(express.json());
app.use(express.static(__dirname));
app.use('/api', bootstrapRouter, syncRouter, scenarioRouter);

app.listen(PORT, '127.0.0.1', () => {
  console.log(`SC2 web-launcher: http://127.0.0.1:${PORT}/`);
});
