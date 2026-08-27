const app = require('./src/app');
const sequelize = require('./src/config/db');
require('./src/models'); // load associations

const PORT = process.env.PORT || 5000;

async function start() {
  try {
    await sequelize.authenticate();
    console.log('Database connected successfully.');

    // In development you can sync models automatically.
    // In production, prefer running db/schema.sql manually or use migrations.
    // await sequelize.sync({ alter: true });

    app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
  } catch (err) {
    console.error('Unable to start server:', err);
  }
}

start();
