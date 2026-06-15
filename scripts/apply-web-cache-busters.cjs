const fs = require("fs");
const path = require("path");

const rootDir = process.cwd();
const pubspecPath = path.join(rootDir, "pubspec.yaml");
const flutterBootstrapPath = path.join(rootDir, "build", "web", "flutter_bootstrap.js");
const flutterServiceWorkerPath = path.join(
  rootDir,
  "build",
  "web",
  "flutter_service_worker.js",
);

function getVersionTag() {
  const pubspec = fs.readFileSync(pubspecPath, "utf8");
  const match = pubspec.match(/^version:\s*([^\s]+)\s*$/m);
  if (!match) {
    throw new Error("Could not find a valid `version:` entry in pubspec.yaml");
  }

  return match[1];
}

function updateFlutterBootstrap(versionTag) {
  const bootstrap = fs.readFileSync(flutterBootstrapPath, "utf8");
  const mainJsPathPattern = /"mainJsPath":"main\.dart\.js(?:\?v[^"]*)?"/;

  if (!mainJsPathPattern.test(bootstrap)) {
    throw new Error("Could not find mainJsPath in build/web/flutter_bootstrap.js");
  }

  let nextBootstrap = bootstrap.replace(
    mainJsPathPattern,
    `"mainJsPath":"main.dart.js?v=${versionTag}"`,
  );

  nextBootstrap = nextBootstrap.replace(
    /_flutter\.loader\.load\(\{[\s\S]*?serviceWorkerSettings:[\s\S]*?\}\s*\);/,
    "_flutter.loader.load();",
  );
  nextBootstrap = nextBootstrap.replace(
    /_flutter\.loader\.load\(\{\}\);/g,
    "_flutter.loader.load();",
  );

  fs.writeFileSync(flutterBootstrapPath, nextBootstrap);
}

function neutralizeFlutterServiceWorker() {
  if (!fs.existsSync(flutterServiceWorkerPath)) {
    return;
  }

  fs.writeFileSync(
    flutterServiceWorkerPath,
    `'use strict';

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});
`,
  );
}

const versionTag = getVersionTag();
updateFlutterBootstrap(versionTag);
neutralizeFlutterServiceWorker();

console.log(`Applied web cache busters for ${versionTag}`);
