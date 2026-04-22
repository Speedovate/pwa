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
  // Flutter 3.41 no longer accepts the legacy --web-renderer flag.
  ["build", "web", "--release"],
  {
    stdio: "inherit",
  },
);

if (buildResult.status !== 0) {
  process.exit(buildResult.status ?? 1);
}

const cacheBustResult = spawnSync(
  process.execPath,
  ["scripts/apply-web-cache-busters.cjs"],
  {
    stdio: "inherit",
  },
);

if (cacheBustResult.status !== 0) {
  process.exit(cacheBustResult.status ?? 1);
}
