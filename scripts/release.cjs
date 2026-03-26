const { spawnSync } = require("child_process");

const args = process.argv.slice(2);
const [version] = args;

if (!version) {
  console.error("Usage: npm run release -- 1.0.31+51");
  process.exit(1);
}

const syncResult = spawnSync(
  process.execPath,
  ["scripts/sync-pubspec-version.cjs", version],
  {
    stdio: "inherit",
  },
);

if (syncResult.status !== 0) {
  process.exit(syncResult.status ?? 1);
}

const cleanResult = spawnSync("flutter", ["clean"], {
  stdio: "inherit",
});

if (cleanResult.status !== 0) {
  process.exit(cleanResult.status ?? 1);
}

const buildResult = spawnSync(
  "flutter",
  ["build", "web", "--web-renderer", "html", "--release"],
  {
    stdio: "inherit",
  },
);

if (buildResult.status !== 0) {
  process.exit(buildResult.status ?? 1);
}
