const { spawnSync } = require("child_process");

const args = process.argv.slice(2);
const supportedTargets = new Set(["web", "apk", "ios", "all"]);
const [firstArg, secondArg] = args;
const target = supportedTargets.has(firstArg) ? firstArg : "web";
const version = supportedTargets.has(firstArg) ? secondArg : firstArg;

if (!version) {
  console.error(
    "Usage: npm run release:web -- 1.0.39+59 | npm run release -- web 1.0.39+59",
  );
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

const buildTargets =
  target === "all" ? ["web", "apk", "ios"] : [target];

for (const buildTarget of buildTargets) {
  const buildArgs =
    buildTarget === "web"
      ? ["build", "web", "--release"]
      : buildTarget === "apk"
        ? ["build", "apk", "--release"]
        : ["build", "ios", "--release", "--no-codesign"];

  const buildResult = spawnSync("flutter", buildArgs, {
    stdio: "inherit",
  });

  if (buildResult.status !== 0) {
    process.exit(buildResult.status ?? 1);
  }

  if (buildTarget === "web") {
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
  }
}
