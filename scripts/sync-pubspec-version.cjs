const fs = require("fs");
const path = require("path");

const rootDir = process.cwd();
const pubspecPath = path.join(rootDir, "pubspec.yaml");
const packageJsonPath = path.join(rootDir, "package.json");
const splashViewModelPath = path.join(rootDir, "lib", "view_models", "splash.vm.dart");
const webIndexHtmlPath = path.join(rootDir, "web", "index.html");

function getArgValue(flagName) {
  const args = process.argv.slice(2);
  const directMatch = args.find((arg) => arg.startsWith(`${flagName}=`));
  if (directMatch) {
    return directMatch.slice(flagName.length + 1);
  }

  const flagIndex = args.indexOf(flagName);
  if (flagIndex >= 0) {
    return args[flagIndex + 1];
  }

  return undefined;
}

function getPositionalArgs() {
  return process.argv.slice(2).filter((arg) => !arg.startsWith("--"));
}

function parsePubspecVersion(pubspecContent) {
  const match = pubspecContent.match(/^version:\s*([^\s+]+)\+(\d+)\s*$/m);
  if (!match) {
    throw new Error("Could not find a valid `version:` entry in pubspec.yaml");
  }

  return {
    version: match[1],
    buildNumber: Number.parseInt(match[2], 10),
  };
}

function parseCompositeVersion(version) {
  const match = version.match(/^(\d+\.\d+\.\d+(?:-[0-9A-Za-z-.]+)?)(?:\+(\d+))?$/);
  if (!match) {
    throw new Error(
      `Invalid version \`${version}\`. Use semver like 1.0.31+51 or 1.0.31-beta.1+51.`,
    );
  }

  return {
    version: match[1],
    buildNumber:
      match[2] !== undefined ? Number.parseInt(match[2], 10) : undefined,
  };
}

function getTargetVersion() {
  const versionFromArg = getArgValue("--version");
  if (versionFromArg) {
    return versionFromArg;
  }

  const [positionalVersion] = getPositionalArgs();
  if (positionalVersion) {
    return positionalVersion;
  }

  if (process.env.npm_package_version) {
    return process.env.npm_package_version;
  }

  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
  return packageJson.version;
}

function getTargetBuildNumber(currentVersion, currentBuildNumber, targetVersion) {
  const buildFromArg = getArgValue("--build-number");
  const buildFromNpmConfig = process.env.npm_config_build_number;
  const rawBuildNumber = buildFromArg ?? buildFromNpmConfig;

  if (rawBuildNumber !== undefined) {
    const parsed = Number.parseInt(rawBuildNumber, 10);
    if (!Number.isInteger(parsed) || parsed < 0) {
      throw new Error(
        `Invalid build number \`${rawBuildNumber}\`. Use a non-negative integer.`,
      );
    }
    return parsed;
  }

  return currentBuildNumber + 1;
}

function updateSplashViewModel(targetVersion, targetBuildNumber) {
  const splashViewModel = fs.readFileSync(splashViewModelPath, "utf8");
  const nextSplashViewModel = splashViewModel
    .replace(/version = "[^"]*";/, `version = "${targetVersion}";`)
    .replace(/versionCode = "[^"]*";/, `versionCode = "${targetBuildNumber}";`);

  fs.writeFileSync(splashViewModelPath, nextSplashViewModel);
}

function updateWebIndexHtml(targetVersion, targetBuildNumber) {
  const indexHtml = fs.readFileSync(webIndexHtmlPath, "utf8");
  const stylesheetHrefPattern = /href="style\/indexstyle\.css\?v[^"]*"/;
  if (!stylesheetHrefPattern.test(indexHtml)) {
    throw new Error("Could not find the index stylesheet tag in web/index.html");
  }

  const nextIndexHtml = indexHtml.replace(
    stylesheetHrefPattern,
    `href="style/indexstyle.css?v=${targetVersion}+${targetBuildNumber}"`,
  );

  fs.writeFileSync(webIndexHtmlPath, nextIndexHtml);
}

function updatePackageJsonVersion(targetVersion) {
  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
  packageJson.version = targetVersion;
  fs.writeFileSync(packageJsonPath, `${JSON.stringify(packageJson, null, 2)}\n`);
}

const pubspecContent = fs.readFileSync(pubspecPath, "utf8");
const currentPubspec = parsePubspecVersion(pubspecContent);
const requestedVersion = getTargetVersion();
const parsedTargetVersion = parseCompositeVersion(requestedVersion);
const targetVersion = parsedTargetVersion.version;

const resolvedBuildNumber =
  parsedTargetVersion.buildNumber ??
  getTargetBuildNumber(
    currentPubspec.version,
    currentPubspec.buildNumber,
    targetVersion,
  );

const nextPubspecContent = pubspecContent.replace(
  /^version:\s*([^\s+]+)\+(\d+)\s*$/m,
  `version: ${targetVersion}+${resolvedBuildNumber}`,
);

if (nextPubspecContent !== pubspecContent) {
  fs.writeFileSync(pubspecPath, nextPubspecContent);
}

updatePackageJsonVersion(targetVersion);
updateSplashViewModel(targetVersion, resolvedBuildNumber);
updateWebIndexHtml(targetVersion, resolvedBuildNumber);

console.log(`Synced version files to ${targetVersion}+${resolvedBuildNumber}`);
