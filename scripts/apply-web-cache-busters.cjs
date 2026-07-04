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
const buildWebIndexHtmlPath = path.join(rootDir, "build", "web", "index.html");
const buildWebSwPath = path.join(rootDir, "build", "web", "sw.js");
const buildWebVersionJsonPath = path.join(rootDir, "build", "web", "version.json");

function getVersionTag() {
  const pubspec = fs.readFileSync(pubspecPath, "utf8");
  const match = pubspec.match(/^version:\s*([^\s]+)\s*$/m);
  if (!match) {
    throw new Error("Could not find a valid `version:` entry in pubspec.yaml");
  }

  return match[1];
}

function parseVersionTag(versionTag) {
  const match = versionTag.match(/^(.+)\+(\d+)$/);
  if (!match) {
    throw new Error(`Invalid version tag \`${versionTag}\``);
  }

  return {
    version: match[1],
    buildNumber: match[2],
  };
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

function updateBuildWebIndexHtml(versionTag) {
  const indexHtml = fs.readFileSync(buildWebIndexHtmlPath, "utf8");
  const stylesheetHrefPattern = /href="style\/indexstyle\.css\?v[^"]*"/;
  const appVersionPattern = /APP_VERSION = "[^"]*";/;

  if (!stylesheetHrefPattern.test(indexHtml)) {
    throw new Error("Could not find the index stylesheet tag in build/web/index.html");
  }

  if (!appVersionPattern.test(indexHtml)) {
    throw new Error("Could not find APP_VERSION in build/web/index.html");
  }

  const nextIndexHtml = indexHtml
    .replace(stylesheetHrefPattern, `href="style/indexstyle.css?v=${versionTag}"`)
    .replace(appVersionPattern, `APP_VERSION = "${versionTag}";`);

  fs.writeFileSync(buildWebIndexHtmlPath, nextIndexHtml);
}

function updateBuildWebSw(versionTag) {
  if (!fs.existsSync(buildWebSwPath)) {
    return;
  }

  const serviceWorker = fs.readFileSync(buildWebSwPath, "utf8");
  const appVersionPattern = /APP_VERSION = "[^"]*";/;

  if (!appVersionPattern.test(serviceWorker)) {
    throw new Error("Could not find APP_VERSION in build/web/sw.js");
  }

  fs.writeFileSync(
    buildWebSwPath,
    serviceWorker.replace(appVersionPattern, `APP_VERSION = "${versionTag}";`),
  );
}

function updateBuildWebVersionJson(versionTag) {
  const { version, buildNumber } = parseVersionTag(versionTag);
  const nextVersionJson = {
    app_name: "pwa",
    version,
    build_number: buildNumber,
    package_name: "pwa",
  };

  fs.writeFileSync(
    buildWebVersionJsonPath,
    `${JSON.stringify(nextVersionJson)}`,
  );
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

function verifyBuildWebVersion(versionTag) {
  const checks = [
    {
      path: flutterBootstrapPath,
      pattern: `main.dart.js?v=${versionTag}`,
    },
    {
      path: buildWebIndexHtmlPath,
      pattern: `style/indexstyle.css?v=${versionTag}`,
    },
    {
      path: buildWebIndexHtmlPath,
      pattern: `APP_VERSION = "${versionTag}";`,
    },
    {
      path: buildWebSwPath,
      pattern: `APP_VERSION = "${versionTag}";`,
    },
    {
      path: buildWebVersionJsonPath,
      pattern: `"version":"${parseVersionTag(versionTag).version}"`,
    },
    {
      path: buildWebVersionJsonPath,
      pattern: `"build_number":"${parseVersionTag(versionTag).buildNumber}"`,
    },
  ];

  for (const check of checks) {
    if (!fs.existsSync(check.path)) {
      throw new Error(`Expected file missing after web build: ${check.path}`);
    }

    const content = fs.readFileSync(check.path, "utf8");
    if (!content.includes(check.pattern)) {
      throw new Error(
        `Version verification failed for ${path.relative(rootDir, check.path)}. Missing pattern: ${check.pattern}`,
      );
    }
  }
}

const versionTag = getVersionTag();
updateFlutterBootstrap(versionTag);
updateBuildWebIndexHtml(versionTag);
updateBuildWebSw(versionTag);
updateBuildWebVersionJson(versionTag);
neutralizeFlutterServiceWorker();
verifyBuildWebVersion(versionTag);

console.log(`Applied and verified web cache busters for ${versionTag}`);
