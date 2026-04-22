const fs = require("fs");
const path = require("path");

const rootDir = process.cwd();
const pubspecPath = path.join(rootDir, "pubspec.yaml");
const flutterBootstrapPath = path.join(rootDir, "build", "web", "flutter_bootstrap.js");

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
  const flutterServiceWorkerPattern = /_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{[\s\S]*?\}\s*\}\);/;

  if (!mainJsPathPattern.test(bootstrap)) {
    throw new Error("Could not find mainJsPath in build/web/flutter_bootstrap.js");
  }

  let nextBootstrap = bootstrap.replace(
    mainJsPathPattern,
    `"mainJsPath":"main.dart.js?v=${versionTag}"`,
  );

  if (flutterServiceWorkerPattern.test(nextBootstrap)) {
    nextBootstrap = nextBootstrap.replace(
      flutterServiceWorkerPattern,
      "_flutter.loader.load({});",
    );
  }

  fs.writeFileSync(flutterBootstrapPath, nextBootstrap);
}

const versionTag = getVersionTag();
updateFlutterBootstrap(versionTag);

console.log(`Applied web cache busters for ${versionTag}`);
