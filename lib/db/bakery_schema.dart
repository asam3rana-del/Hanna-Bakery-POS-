/// Bakery tables (DB v39): cake / custom orders, recipes aur production log.
///
/// Sab `CREATE ... IF NOT EXISTS` — naye install ([AppDatabase._onCreate]) aur purane DB ka upgrade
/// ([AppDatabase._onUpgrade], oldVersion < 39) dono yahi list chalate hain. Ye tables sirf is device par hain
/// (cloud sync mein nahi); in se banne wali cash rows aur stock badlao aam tareeqe se sync hote hain.
const bakeryTablesSql = <String>[
  '''
    CREATE TABLE IF NOT EXISTS bakery_orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customerName TEXT NOT NULL,
      phone TEXT NOT NULL DEFAULT '',
      item TEXT NOT NULL,
      flavour TEXT NOT NULL DEFAULT '',
      weight REAL NOT NULL DEFAULT 0,
      weightUnit TEXT NOT NULL DEFAULT 'lb',
      cakeMessage TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT '',
      homeDelivery INTEGER NOT NULL DEFAULT 0,
      address TEXT NOT NULL DEFAULT '',
      total REAL NOT NULL DEFAULT 0,
      advance REAL NOT NULL DEFAULT 0,
      paid REAL NOT NULL DEFAULT 0,
      deliveryAt INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      createdBy TEXT NOT NULL DEFAULT '',
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL DEFAULT 0,
      closedAt INTEGER NOT NULL DEFAULT 0
    )
  ''',
  'CREATE INDEX IF NOT EXISTS index_bakery_orders_deliveryAt ON bakery_orders(deliveryAt)',
  'CREATE INDEX IF NOT EXISTS index_bakery_orders_status ON bakery_orders(status)',
  '''
    CREATE TABLE IF NOT EXISTS recipes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      barcode TEXT NOT NULL UNIQUE,
      yieldQty REAL NOT NULL DEFAULT 1,
      note TEXT NOT NULL DEFAULT '',
      updatedAt INTEGER NOT NULL DEFAULT 0
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS recipe_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      recipeId INTEGER NOT NULL,
      barcode TEXT NOT NULL,
      qty REAL NOT NULL
    )
  ''',
  'CREATE INDEX IF NOT EXISTS index_recipe_items_recipeId ON recipe_items(recipeId)',
  '''
    CREATE TABLE IF NOT EXISTS production_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      recipeId INTEGER NOT NULL DEFAULT 0,
      barcode TEXT NOT NULL,
      productName TEXT NOT NULL DEFAULT '',
      batches REAL NOT NULL DEFAULT 1,
      producedQty REAL NOT NULL,
      materialCost REAL NOT NULL DEFAULT 0,
      note TEXT NOT NULL DEFAULT '',
      createdBy TEXT NOT NULL DEFAULT '',
      createdAt INTEGER NOT NULL
    )
  ''',
  'CREATE INDEX IF NOT EXISTS index_production_log_createdAt ON production_log(createdAt)',
];
