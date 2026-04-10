# Node.js CLI Tools & Shell Integration Reference

Dense reference for building CLI tools, output formatting, shell integration, and npm/npx workflow.

---

## Building CLI Tools

### package.json bin Field

```json
{
  "name": "my-cli-tool",
  "version": "1.0.0",
  "type": "module",
  "bin": {
    "mytool": "./bin/index.mjs"
  },
  "engines": { "node": ">=20" }
}
```

### Shebang Line

```js
#!/usr/bin/env node
// bin/index.mjs
import { parseArgs } from 'node:util';
// ... rest of CLI
```

Make executable on Unix: `chmod +x bin/index.mjs`

### Local Development

```bash
npm link             # link package globally for testing
mytool --help        # now available as command
npm unlink -g my-cli-tool   # unlink when done
```

### ESM vs CJS

```js
// ESM (recommended for new projects)
// package.json: "type": "module"
import fs from 'node:fs/promises';
export function helper() {}

// CJS (legacy)
// package.json: no "type" or "type": "commonjs"
const fs = require('fs').promises;
module.exports = { helper };

// Dual package — exports map
// "exports": {
//   ".": { "import": "./dist/index.mjs", "require": "./dist/index.cjs" }
// }
```

---

## Argument Parsing

### Built-in parseArgs (node:util — stable since Node 18.11)

```js
import { parseArgs } from 'node:util';

const { values, positionals } = parseArgs({
  args: process.argv.slice(2),
  options: {
    output:  { type: 'string',  short: 'o' },
    verbose: { type: 'boolean', short: 'v', default: false },
    count:   { type: 'string',  short: 'n', default: '10' },
  },
  allowPositionals: true,
});

console.log(values.output);      // string | undefined
console.log(values.verbose);     // boolean
console.log(Number(values.count));
console.log(positionals);        // string[]
```

### commander (most popular, stable)

```js
import { Command } from 'commander';

const program = new Command();
program.name('mytool').description('My CLI tool').version('1.0.0');

program
  .command('convert <input> [output]')
  .description('Convert a file')
  .option('-f, --format <fmt>', 'output format', 'json')
  .option('-v, --verbose', 'verbose output', false)
  .action(async (input, output, opts) => {
    console.log(`Converting ${input} -> ${output ?? 'stdout'} as ${opts.format}`);
  });

program.parse();
```

### yargs (rich help, middleware, async commands)

```js
import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';

yargs(hideBin(process.argv))
  .command('download <url>', 'Download a URL', (y) => {
    y.positional('url', { describe: 'URL to download', type: 'string' });
  }, async (argv) => {
    await download(argv.url);
  })
  .option('output', { alias: 'o', type: 'string', description: 'Output path' })
  .demandCommand(1)
  .help()
  .parse();
```

### meow (minimal, ESM-first)

```js
import meow from 'meow';

const cli = meow(`
  Usage: mytool [options] <file>
  Options:
    --output, -o  Output file
    --verbose, -v Verbose
`, {
  importMeta: import.meta,
  flags: {
    output:  { type: 'string',  shortFlag: 'o' },
    verbose: { type: 'boolean', shortFlag: 'v' },
  },
});
console.log(cli.flags.output, cli.input[0]);
```

### Manual Parsing (Zero Deps)

```js
const args = process.argv.slice(2);
const flags = {};
const positionals = [];

for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith('--')) {
    const [key, val] = args[i].slice(2).split('=');
    flags[key] = val ?? (args[i + 1]?.startsWith('-') ? true : args[++i]);
  } else if (args[i].startsWith('-')) {
    flags[args[i].slice(1)] = true;
  } else {
    positionals.push(args[i]);
  }
}
```

---

## Output Formatting

### Colors — chalk / picocolors

```js
// chalk (feature-rich, ESM-first from v5)
import chalk from 'chalk';
console.log(chalk.green('Success!'));
console.log(chalk.red.bold('Error:'), chalk.white(message));
console.log(chalk.bgBlue.white(' INFO '), 'details here');

// picocolors (tiny, no deps, faster)
import pc from 'picocolors';
console.log(pc.green('Done'));
console.log(`${pc.red('X')} ${pc.bold('Failed')}: ${message}`);

// Both respect NO_COLOR env var automatically
```

### Spinners — ora

```js
import ora from 'ora';

const spinner = ora('Fetching data...').start();
try {
  const data = await fetchData();
  spinner.succeed('Data fetched!');
} catch (err) {
  spinner.fail(`Failed: ${err.message}`);
}

const s = ora({ text: 'Processing', spinner: 'dots' }).start();
s.text = 'Still processing...';
s.stop();
```

### Tables — cli-table3

```js
import Table from 'cli-table3';

const table = new Table({
  head: ['Name', 'Size', 'Modified'],
  colWidths: [30, 10, 25],
});
files.forEach(f => table.push([f.name, f.size, f.mtime.toISOString()]));
console.log(table.toString());
```

### Boxes — boxen

```js
import boxen from 'boxen';
console.log(boxen('Operation complete!\nFiles: 42', {
  padding: 1,
  margin: 1,
  borderStyle: 'round',
  borderColor: 'green',
  title: 'Summary',
}));
```

### Interactive Prompts — @inquirer/prompts

```js
import { input, confirm, select, checkbox, password } from '@inquirer/prompts';

const name    = await input({ message: 'Your name:' });
const proceed = await confirm({ message: 'Continue?', default: true });
const format  = await select({
  message: 'Output format:',
  choices: [
    { name: 'JSON', value: 'json' },
    { name: 'CSV',  value: 'csv'  },
    { name: 'YAML', value: 'yaml' },
  ],
});
const tags = await checkbox({ message: 'Select tags:', choices: ['a','b','c'] });
const pass = await password({ message: 'Password:', mask: '*' });
```

### Progress Bars — cli-progress

```js
import cliProgress from 'cli-progress';

const bar = new cliProgress.SingleBar({
  format: 'Progress |{bar}| {percentage}% | {value}/{total} files',
}, cliProgress.Presets.shades_classic);

bar.start(totalFiles, 0);
for (const file of files) {
  await processFile(file);
  bar.increment();
}
bar.stop();
```

---

## Shell Integration

### execa — Better child_process

```js
import { execa, execaCommand } from 'execa';

// Simple command
const { stdout } = await execa('git', ['log', '--oneline', '-5']);
console.log(stdout);

// Shell-style string
const { stdout: out } = await execaCommand('ls -la | grep .js');

// Pipe output to process
await execa('npm', ['install'], { stdio: 'inherit' });

// Error includes exit code, stdout, stderr
try {
  await execa('git', ['push']);
} catch (err) {
  console.error(err.exitCode, err.stderr);
}
```

### zx — Google's Shell Scripting in JS

```js
#!/usr/bin/env zx
// script.mjs — run with: npx zx script.mjs
import 'zx/globals';

// $ template tag runs shell commands
const count = await $`ls *.js | wc -l`;
console.log(`JS files: ${count.stdout.trim()}`);

// cd changes working directory
cd('/tmp');
await $`mkdir -p workspace`;

// fetch is available globally
const res = await fetch('https://api.github.com/repos/google/zx');

// question — interactive
const name = await question('Enter name: ');

// quiet mode
$.quiet = true;
const branches = await $`git branch -a`;

// Pipe
const result = await $`cat data.txt`.pipe($`grep pattern`);
```

### shelljs — Portable Shell Commands

```js
import shell from 'shelljs';

shell.mkdir('-p', '/path/to/dir');
shell.cp('-r', 'src/', 'dist/');
shell.rm('-rf', 'dist/');
shell.ls('-la', '.').forEach(f => console.log(f));
shell.grep('-r', 'TODO', 'src/');
shell.sed('-i', 'old', 'new', 'file.txt');
shell.which('git');
shell.exec('git status', { silent: true });
```

---

## npm / npx Workflow

### Common npm Commands

```bash
# Initialize project
npm init -y
npm init @scope/package        # scoped init template

# Install
npm install lodash                  # runtime dep
npm install -D typescript tsx       # dev dep
npm install -g npm@latest           # global
npm install --save-exact axios      # pin exact version
npm ci                              # clean install from lockfile (CI)

# Run scripts
npm run build
npm run test -- --watch             # pass args after --
npm exec -- tsc --version           # run local bin

# npx — run without installing
npx cowsay hello
npx -y create-turbo@latest my-app   # auto-yes

# Workspaces
npm init -w packages/core           # create workspace package
npm install -w packages/core lodash # install into workspace
npm run build --workspaces          # run in all workspaces

# Audit / update
npm audit
npm audit fix
npm outdated
npm update
```

### .npmrc — Configuration

```ini
# .npmrc (project-level or ~/.npmrc)
registry=https://registry.npmjs.org/
@myorg:registry=https://npm.pkg.github.com/
save-exact=true
engine-strict=true
```

### package.json Scripts Patterns

```json
{
  "scripts": {
    "start":      "node dist/index.mjs",
    "dev":        "node --watch src/index.mjs",
    "build":      "tsc",
    "lint":       "eslint src",
    "test":       "node --test",
    "test:watch": "node --test --watch",
    "prepublish": "npm run build"
  }
}
```

### npx One-Shot Execution

```bash
npx cowsay "hello"               # download + run
npx ts-node script.ts
npx --yes create-react-app my-app
npx commander@11 --help          # specific version
```

### Publishing to npm

```bash
npm login
npm publish --access public      # for scoped @org/package
npm version patch                # bump patch, creates git tag
npm publish
```

---

## Key Package Summary

| Purpose | Package | Notes |
|---|---|---|
| Arg parsing | `commander`, `yargs`, `meow` | `parseArgs` is built-in since 18.3 |
| Colors | `chalk`, `picocolors` | picocolors is smaller/faster |
| Spinners | `ora` | Elegant terminal spinners |
| Tables | `cli-table3` | Terminal tables |
| Boxes | `boxen` | Terminal boxes |
| Interactive | `@inquirer/prompts` | Successor to `inquirer` |
| Progress bars | `cli-progress` | Terminal progress bars |
| Shell scripting | `zx`, `execa` | zx for scripts, execa for programmatic |
| Portable shell | `shelljs` | Unix commands cross-platform |
