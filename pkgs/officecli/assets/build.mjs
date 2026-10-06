import { cp, mkdir, readFile, readdir, rm, stat, writeFile } from "node:fs/promises";
import { readFileSync } from "node:fs";
import { dirname, extname, join, resolve } from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)));
const output = join(root, "dist");
const nodeModules = join(root, "node_modules");

async function runEsbuild(args) {
  await new Promise((resolveRun, rejectRun) => {
    const child = spawn("esbuild", args, { cwd: root, stdio: "inherit" });
    child.once("error", rejectRun);
    child.once("exit", (code, signal) => {
      if (code === 0) resolveRun();
      else rejectRun(new Error(`esbuild failed with ${signal ?? `exit code ${code}`}`));
    });
  });
}

async function buildJavaScript(entry, fileName) {
  const path = join(output, fileName);
  await runEsbuild([
    join(root, "src", entry),
    "--bundle",
    "--format=iife",
    "--platform=browser",
    "--target=es2020",
    "--minify",
    "--legal-comments=eof",
    "--charset=utf8",
    `--outfile=${path}`,
  ]);
}

async function inlineKatexCss() {
  const sourcePath = join(nodeModules, "katex", "dist", "katex.min.css");
  const source = await readFile(sourcePath, "utf8");
  const css = source.replace(/url\((['"]?)(fonts\/[^)'"\s]+)\1\)/g, (_, quote, asset) => {
    const fontPath = join(nodeModules, "katex", "dist", asset);
    const mime = {
      ".otf": "font/otf",
      ".ttf": "font/ttf",
      ".woff": "font/woff",
      ".woff2": "font/woff2",
    }[extname(fontPath).toLowerCase()];
    if (!mime) throw new Error("unsupported KaTeX font extension: " + fontPath);
    return "url(data:" + mime + ";base64," + readFileSync(fontPath).toString("base64") + ")";
  });
  if (/url\((['"]?)fonts\//.test(css)) throw new Error("KaTeX CSS contains an un-inlined font URL");
  await writeFile(join(output, "katex.css"), css);
}

async function packageLicense(packageDir, packageKey, licensesDir) {
  const packageJsonPath = join(packageDir, "package.json");
  let packageJson;
  try {
    packageJson = JSON.parse(await readFile(packageJsonPath, "utf8"));
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
    throw new Error("locked npm package is missing from node_modules: " + packageDir, { cause: error });
  }
  const name = packageJson.name ?? packageKey;
  const version = packageJson.version ?? "unknown";
  const safeName = `${name.replace(/^@/, "").replaceAll("/", "__")}@${version}`;
  const copied = [];
  const entries = (await readdir(packageDir, { withFileTypes: true }))
    .filter((entry) => entry.isFile() && /^(?:licen[cs]e|notice|copying)(?:[._-].*)?$/i.test(entry.name))
    .sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
  for (const entry of entries) {
    const fileName = entry.name;
    const sourcePath = join(packageDir, fileName);
    try {
      if (!(await stat(sourcePath)).isFile()) continue;
      const destination = join(licensesDir, `${safeName}.${fileName}`);
      await cp(sourcePath, destination);
      copied.push(`${safeName}.${fileName}`);
    } catch (error) {
      if (error?.code !== "ENOENT") throw error;
      // Packages commonly publish only one spelling of their license file. / パッケージはライセンス表記を一種類だけ公開することが多い。
    }
  }
  if (copied.length === 0) {
    const readmes = (await readdir(packageDir, { withFileTypes: true }))
      .filter((entry) => entry.isFile() && /^readme(?:[._-].*)?$/i.test(entry.name))
      .sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
    for (const entry of readmes) {
      const text = await readFile(join(packageDir, entry.name), "utf8");
      if (!/(?:license|copyright|permission is hereby)/i.test(text)) continue;
      const fileName = entry.name;
      const destination = join(licensesDir, safeName + "." + fileName);
      await cp(join(packageDir, fileName), destination);
      copied.push(safeName + "." + fileName);
      break;
    }
  }
  return { name, version, license: packageJson.license ?? null, files: copied };
}

async function collectLicenses() {
  const lock = JSON.parse(await readFile(join(root, "package-lock.json"), "utf8"));
  const licensesDir = join(output, "LICENSES");
  await mkdir(licensesDir, { recursive: true });
  const manifest = [];
  for (const packageKey of Object.keys(lock.packages ?? {}).sort()) {
    if (!packageKey.startsWith("node_modules/")) continue;
    const packageName = packageKey.slice("node_modules/".length);
    const packageDir = join(nodeModules, packageName);
    const record = await packageLicense(packageDir, packageName, licensesDir);
    if (record) manifest.push(record);
  }
  await writeFile(join(licensesDir, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
}

await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
await buildJavaScript("mermaid.js", "mermaid.js");
await buildJavaScript("three.js", "three.js");
await buildJavaScript("katex.js", "katex.js");
await inlineKatexCss();
await collectLicenses();
