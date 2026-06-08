const { spawnSync } = require("child_process");

const appId = "com.ppctoda.customer";
const dryRun = process.argv.includes("--dry-run");

const processPatterns = [
  {
    label: "Flutter runs/builds",
    pattern:
      "flutter_tools\\.snapshot|flutter run|flutter build|dart.*frontend_server|frontend_server\\.dart\\.snapshot",
  },
  {
    label: "Flutter web Chrome sessions",
    pattern:
      "Google Chrome.*pwa-chrome-profile|Google Chrome.*remote-debugging-port|chromedriver.*flutter",
  },
  {
    label: "Android Gradle builds",
    pattern: "GradleDaemon|gradle.*assemble|gradle.*compile|KotlinCompileDaemon",
  },
  {
    label: "iOS/Xcode builds and debug sessions",
    pattern: "xcodebuild|XCBBuildService|ios-deploy|debugserver|lldb|Runner.app/Runner",
  },
];

function run(command, args, options = {}) {
  const printable = [command, ...args].join(" ");
  if (dryRun) {
    console.log(`[dry-run] ${printable}`);
    return { status: 0 };
  }

  return spawnSync(command, args, {
    stdio: options.stdio ?? "pipe",
    encoding: "utf8",
  });
}

function killProcesses({ label, pattern }) {
  console.log(`Stopping ${label}...`);
  const result = run("pkill", ["-f", pattern]);
  if (result.status === 0) {
    console.log(`Stopped ${label}.`);
    return;
  }

  // pkill exits with 1 when no matching process exists.
  if (result.status === 1) {
    console.log(`No ${label} found.`);
    return;
  }

  const error = (result.stderr || result.stdout || "").trim();
  console.log(`Could not stop ${label}${error ? `: ${error}` : "."}`);
}

function connectedAndroidDevices() {
  const result = run("adb", ["devices"]);
  if (result.status !== 0 || !result.stdout) {
    return [];
  }

  return result.stdout
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.endsWith("\tdevice"))
    .map((line) => line.split(/\s+/)[0])
    .filter(Boolean);
}

function forceStopAndroidApp() {
  const devices = connectedAndroidDevices();
  if (devices.length === 0) {
    console.log("No connected Android devices found.");
    return;
  }

  for (const device of devices) {
    console.log(`Force-stopping Android app on ${device}...`);
    const result = run("adb", [
      "-s",
      device,
      "shell",
      "am",
      "force-stop",
      appId,
    ]);
    if (result.status === 0) {
      console.log(`Android app stopped on ${device}.`);
      continue;
    }

    const error = (result.stderr || result.stdout || "").trim();
    console.log(
      `Could not force-stop Android app on ${device}${error ? `: ${error}` : "."}`,
    );
  }
}

console.log("Killing PPC TODA web, Android, and iOS dev runs...");
for (const entry of processPatterns) {
  killProcesses(entry);
}
forceStopAndroidApp();
console.log("Kill-all finished.");
