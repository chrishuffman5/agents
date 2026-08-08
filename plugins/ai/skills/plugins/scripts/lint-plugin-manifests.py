#!/usr/bin/env python3
"""Read-only lint for Claude Code plugin and marketplace manifests.

Usage:
    python3 lint-plugin-manifests.py <path> [<path> ...]

Each <path> may be:
  * a plugin directory        (contains .claude-plugin/plugin.json, or is checked bare)
  * a marketplace directory   (contains .claude-plugin/marketplace.json)
  * a direct path to plugin.json or marketplace.json

Checks only rules stated explicitly in the Claude Code plugin docs (see the
skill's references/): required fields, component-directory placement, path-field
shapes, dual-version pinning, duplicate and reserved names, renames-chain
termination, and cross-marketplace dependency allowlisting.

This COMPLEMENTS `claude plugin validate` -- it does not replace it. Run both.

Never writes, never edits, never network. Exit code 1 if any ERROR was
reported, else 0.
"""

import json
import os
import re
import sys

# --- Constants taken verbatim from the docs --------------------------------

# plugin-marketplaces: names reserved for Anthropic, re-checked on every load.
RESERVED_MARKETPLACE_NAMES = {
    "claude-code-marketplace", "claude-code-plugins", "claude-plugins-official",
    "claude-plugins-community", "claude-community", "anthropic-marketplace",
    "anthropic-plugins", "agent-skills", "anthropic-agent-skills",
    "knowledge-work-plugins", "life-sciences", "claude-for-legal",
    "claude-for-financial-services", "financial-services-plugins",
    "first-party-plugins", "healthcare",
}
# plugin-marketplaces: rejected by Claude Desktop's managed sync, any casing.
DESKTOP_RESERVED = {"org", "org-provisioned", "unknown"}
# plugin-marketplaces: Desktop accepts <=128 chars, letters/digits/./_/-,
# starting with a letter or digit.
DESKTOP_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
KEBAB_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

# plugins-reference: recognized plugin.json keys. Unknown keys are ignored by
# Claude Code and reported by the validator as warnings, not errors.
PLUGIN_FIELDS = {
    "$schema", "name", "displayName", "version", "description", "author",
    "homepage", "repository", "license", "keywords", "metadata",
    "defaultEnabled", "skills", "commands", "agents", "workflows", "hooks",
    "mcpServers", "outputStyles", "lspServers", "experimental", "userConfig",
    "channels", "dependencies", "settings",
}
# plugin-marketplaces: entries accept any plugin field plus these.
MARKETPLACE_ONLY_ENTRY_FIELDS = {"source", "category", "tags", "strict", "relevance"}

# plugins-reference: fields whose values are plugin-root-relative paths.
PATH_FIELDS = ("skills", "commands", "agents", "workflows", "outputStyles")
EXPERIMENTAL_PATH_FIELDS = ("themes", "monitors")
# These accept an inline object as well as a path string.
PATH_OR_INLINE_FIELDS = ("hooks", "mcpServers", "lspServers")

# plugins / plugins-reference: only plugin.json belongs in .claude-plugin/.
MISPLACED_COMPONENT_DIRS = ("skills", "commands", "agents", "hooks", "monitors",
                            "output-styles", "themes", "workflows", "bin")

VALID_SOURCE_TYPES = {"github", "url", "git-subdir", "npm"}
SOURCE_REQUIRED_FIELDS = {
    "github": ("repo",),
    "url": ("url",),
    "git-subdir": ("url", "path"),
    "npm": ("package",),
}


class Report:
    def __init__(self, label):
        self.label = label
        self.errors = []
        self.warnings = []
        self.notes = []

    def error(self, msg):
        self.errors.append(msg)

    def warn(self, msg):
        self.warnings.append(msg)

    def note(self, msg):
        self.notes.append(msg)

    def emit(self):
        print("\n== %s" % self.label)
        for m in self.errors:
            print("  ERROR   %s" % m)
        for m in self.warnings:
            print("  WARN    %s" % m)
        for m in self.notes:
            print("  NOTE    %s" % m)
        if not (self.errors or self.warnings or self.notes):
            print("  ok")


def load_json(path, rep):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        rep.error("File not found: %s" % path)
    except json.JSONDecodeError as exc:
        rep.error("Invalid JSON syntax in %s: %s" % (path, exc))
    except OSError as exc:
        rep.error("Cannot read %s: %s" % (path, exc))
    return None


def check_name(name, rep, what):
    if not isinstance(name, str) or not name:
        rep.error("%s: `name` is required and must be a non-empty string" % what)
        return
    if not KEBAB_RE.match(name):
        rep.warn('%s: name "%s" is not kebab-case '
                 "(validator warns; claude.ai marketplace sync rejects it)" % (what, name))
    if name.lower() in DESKTOP_RESERVED:
        rep.warn('%s: name "%s" is reserved in Claude Desktop '
                 "(Desktop managed sync rejects the whole marketplace)" % (what, name))
    if not DESKTOP_NAME_RE.match(name):
        rep.warn('%s: name "%s" is not accepted by Claude Desktop '
                 "(<=128 chars, letters/digits/./_/-, starting with a letter or digit)"
                 % (what, name))


def check_path_value(value, field, rep, allow_dot=False):
    if not isinstance(value, str):
        rep.error("%s: path entries must be strings, got %s" % (field, type(value).__name__))
        return
    if allow_dot and value in (".", "./"):
        return
    if os.path.isabs(value) or re.match(r"^[A-Za-z]:[\\/]", value):
        rep.error('%s: absolute path "%s" -- paths must be relative to the plugin root'
                  % (field, value))
        return
    if ".." in value.replace("\\", "/").split("/"):
        rep.error('%s: path "%s" contains ".." -- not allowed' % (field, value))
        return
    if not value.startswith("./"):
        rep.error('%s: path "%s" must start with "./"%s'
                  % (field, value, ' (the `skills` field also accepts ".")' if allow_dot else ""))
    if "\\" in value:
        rep.warn('%s: path "%s" uses backslashes -- use forward slashes' % (field, value))


def check_path_field(obj, field, rep, allow_dot=False, allow_inline=False):
    if field not in obj:
        return
    value = obj[field]
    if isinstance(value, str):
        check_path_value(value, field, rep, allow_dot)
    elif isinstance(value, list):
        for item in value:
            check_path_value(item, field, rep, allow_dot)
    elif isinstance(value, dict):
        if not allow_inline:
            rep.error("%s: expected a path string or array of path strings" % field)
    else:
        rep.error("%s: expected a path string or array, got %s" % (field, type(value).__name__))


def check_dependencies(manifest, rep, allowed_marketplaces=None, marketplace_name=None):
    deps = manifest.get("dependencies")
    if deps is None:
        return []
    if not isinstance(deps, list):
        rep.error("dependencies: must be an array")
        return []
    cross = []
    for i, dep in enumerate(deps):
        if isinstance(dep, str):
            if not dep:
                rep.error("dependencies[%d]: empty plugin name" % i)
            continue
        if not isinstance(dep, dict):
            rep.error("dependencies[%d]: must be a string or an object" % i)
            continue
        if not isinstance(dep.get("name"), str) or not dep.get("name"):
            rep.error("dependencies[%d]: object form requires a `name` string" % i)
        other = dep.get("marketplace")
        if isinstance(other, str) and other and other != marketplace_name:
            cross.append((dep.get("name"), other))
            if allowed_marketplaces is not None and other not in allowed_marketplaces:
                rep.error('dependencies[%d]: cross-marketplace dependency on "%s" requires the '
                          "root marketplace to list it in allowCrossMarketplaceDependenciesOn"
                          % (i, other))
    return cross


def lint_plugin_manifest(manifest, rep, plugin_dir=None, context="plugin.json",
                         known_fields=None, allowed_marketplaces=None,
                         marketplace_name=None):
    known = known_fields or PLUGIN_FIELDS
    if not isinstance(manifest, dict):
        rep.error("%s: top level must be a JSON object" % context)
        return

    check_name(manifest.get("name"), rep, context)

    for field in ("displayName", "version", "description", "homepage", "repository", "license"):
        if field in manifest and not isinstance(manifest[field], str):
            rep.error("%s: `%s` must be a string (wrong type fails the load)" % (context, field))
    if "keywords" in manifest and not isinstance(manifest["keywords"], list):
        rep.error("%s: `keywords` must be an array (wrong type fails the load)" % context)
    if "author" in manifest and not isinstance(manifest["author"], dict):
        rep.error("%s: `author` must be an object {name, email?, url?}" % context)
    if "defaultEnabled" in manifest and not isinstance(manifest["defaultEnabled"], bool):
        rep.error("%s: `defaultEnabled` must be a boolean" % context)
    for field in ("metadata", "experimental"):
        if field in manifest and not isinstance(manifest[field], dict):
            rep.warn("%s: `%s` is not an object -- ignored, reported as a warning" % (context, field))

    for field in PATH_FIELDS:
        check_path_field(manifest, field, rep, allow_dot=(field == "skills"))
    for field in PATH_OR_INLINE_FIELDS:
        check_path_field(manifest, field, rep, allow_inline=True)
    experimental = manifest.get("experimental")
    if isinstance(experimental, dict):
        for field in EXPERIMENTAL_PATH_FIELDS:
            check_path_field(experimental, field, rep)
    for field in EXPERIMENTAL_PATH_FIELDS:
        if field in manifest:
            rep.warn('%s: `%s` at the top level still works today but the validator warns; '
                     "a future release will require `experimental.%s`" % (context, field, field))

    for key in manifest:
        if key in EXPERIMENTAL_PATH_FIELDS:
            continue  # already reported above as a should-move-to-experimental warning
        if key not in known:
            rep.note('%s: unrecognized field "%s" -- ignored by Claude Code, '
                     "reported by the validator as a warning" % (context, key))

    check_dependencies(manifest, rep, allowed_marketplaces, marketplace_name)

    if plugin_dir:
        lint_plugin_dir(plugin_dir, manifest, rep)


def lint_plugin_dir(plugin_dir, manifest, rep):
    meta_dir = os.path.join(plugin_dir, ".claude-plugin")
    if os.path.isdir(meta_dir):
        for entry in sorted(os.listdir(meta_dir)):
            if entry in MISPLACED_COMPONENT_DIRS and os.path.isdir(os.path.join(meta_dir, entry)):
                rep.error('component directory ".claude-plugin/%s/" is misplaced -- only '
                          "plugin.json belongs in .claude-plugin/; move it to the plugin root"
                          % entry)
    if os.path.isfile(os.path.join(plugin_dir, "CLAUDE.md")):
        rep.note("a plugin-root CLAUDE.md is NOT loaded as project context -- "
                 "ship instructions as a skill instead")
    has_skills_dir = os.path.isdir(os.path.join(plugin_dir, "skills"))
    root_skill = os.path.isfile(os.path.join(plugin_dir, "SKILL.md"))
    if root_skill and not has_skills_dir and "skills" not in (manifest or {}):
        rep.note("root SKILL.md with no skills/ dir loads as a single-skill plugin (v2.1.142+); "
                 "set frontmatter `name` -- the fallback is the install directory name")
    for field, default_dir in (("commands", "commands"), ("agents", "agents"),
                               ("workflows", "workflows"), ("outputStyles", "output-styles")):
        if field in (manifest or {}) and os.path.isdir(os.path.join(plugin_dir, default_dir)):
            values = manifest[field]
            values = values if isinstance(values, list) else [values]
            if not any(isinstance(v, str) and v.strip("./").startswith(default_dir) for v in values):
                rep.warn("`%s` replaces the default %s/ directory, which exists and will be "
                         "ignored -- list it explicitly to keep it" % (field, default_dir))
    for path_field, subdir in (("hooks", os.path.join("hooks", "hooks.json")),):
        candidate = os.path.join(plugin_dir, subdir)
        if os.path.isfile(candidate):
            try:
                with open(candidate, "r", encoding="utf-8") as fh:
                    json.load(fh)
            except json.JSONDecodeError as exc:
                rep.error("%s is malformed JSON (%s) -- a malformed hooks.json blocks the "
                          "ENTIRE plugin from loading" % (subdir, exc))
            except OSError:
                pass


def resolve_entry_dir(marketplace_root, source, plugin_root_prefix):
    candidates = []
    cleaned = source[2:] if source.startswith("./") else source
    if plugin_root_prefix:
        prefix = plugin_root_prefix[2:] if plugin_root_prefix.startswith("./") else plugin_root_prefix
        candidates.append(os.path.join(marketplace_root, prefix, cleaned))
    candidates.append(os.path.join(marketplace_root, cleaned))
    for cand in candidates:
        if os.path.isdir(cand):
            return cand
    return None


def lint_marketplace(path, rep):
    data = load_json(path, rep)
    if data is None:
        return
    if not isinstance(data, dict):
        rep.error("marketplace.json: top level must be a JSON object")
        return

    marketplace_root = os.path.dirname(os.path.dirname(os.path.abspath(path))) \
        if os.path.basename(os.path.dirname(os.path.abspath(path))) == ".claude-plugin" \
        else os.path.dirname(os.path.abspath(path))

    name = data.get("name")
    check_name(name, rep, "marketplace.json")
    if isinstance(name, str) and name.lower() in RESERVED_MARKETPLACE_NAMES:
        rep.error('marketplace name "%s" is reserved for Anthropic -- it will stop loading and '
                  'report "registered from an untrusted source"' % name)

    owner = data.get("owner")
    if not isinstance(owner, dict):
        rep.error("marketplace.json: `owner` object is required")
    elif not isinstance(owner.get("name"), str) or not owner.get("name"):
        rep.error("marketplace.json: `owner.name` is required")

    if not isinstance(data.get("description"), str) or not data.get("description"):
        rep.warn("no marketplace description provided")

    plugins = data.get("plugins")
    if not isinstance(plugins, list):
        rep.error("marketplace.json: `plugins` array is required")
        plugins = []
    elif not plugins:
        rep.warn("marketplace has no plugins defined")

    allowed = data.get("allowCrossMarketplaceDependenciesOn")
    allowed_set = set(allowed) if isinstance(allowed, list) else set()

    plugin_root_prefix = None
    metadata = data.get("metadata")
    if isinstance(metadata, dict) and isinstance(metadata.get("pluginRoot"), str):
        plugin_root_prefix = metadata["pluginRoot"]

    seen = {}
    entry_names = set()
    for i, entry in enumerate(plugins):
        ctx = "plugins[%d]" % i
        if not isinstance(entry, dict):
            rep.error("%s: each plugin entry must be an object" % ctx)
            continue
        ename = entry.get("name")
        if isinstance(ename, str):
            entry_names.add(ename)
            if ename in seen:
                rep.error('Duplicate plugin name "%s" found in marketplace (entries %d and %d)'
                          % (ename, seen[ename], i))
            else:
                seen[ename] = i

        source = entry.get("source")
        entry_dir = None
        if source is None:
            rep.error("%s: `source` is required" % ctx)
        elif isinstance(source, str):
            if ".." in source.replace("\\", "/").split("/"):
                rep.error('%s.source: Path contains ".."' % ctx)
            elif os.path.isabs(source):
                rep.error("%s.source: absolute path -- use a path relative to the marketplace root"
                          % ctx)
            else:
                if not source.startswith("./") and not plugin_root_prefix and source != ".":
                    rep.warn('%s.source: relative path "%s" should start with "./"' % (ctx, source))
                entry_dir = resolve_entry_dir(marketplace_root, source, plugin_root_prefix)
                if entry_dir is None:
                    rep.error("%s: plugin directory not found for source \"%s\" -- check the "
                              "marketplace entry path" % (ctx, source))
        elif isinstance(source, dict):
            stype = source.get("source")
            if stype not in VALID_SOURCE_TYPES:
                rep.error("%s.source: unknown source type %r (expected one of %s)"
                          % (ctx, stype, ", ".join(sorted(VALID_SOURCE_TYPES))))
            else:
                for req in SOURCE_REQUIRED_FIELDS[stype]:
                    if not isinstance(source.get(req), str) or not source.get(req):
                        rep.error("%s.source: `%s` source requires `%s`" % (ctx, stype, req))
                sha = source.get("sha")
                if sha is not None and (not isinstance(sha, str) or len(sha) != 40):
                    rep.warn("%s.source.sha: expected a full 40-character commit SHA" % ctx)
                if source.get("ref") and source.get("sha"):
                    rep.note("%s.source: both `ref` and `sha` set -- `sha` is the effective pin"
                             % ctx)
        else:
            rep.error("%s.source: must be a string path or a source object" % ctx)

        if "strict" in entry and not isinstance(entry["strict"], bool):
            rep.error("%s.strict: must be a boolean" % ctx)

        entry_rep = Report("%s (%s)" % (ctx, ename or "<unnamed>"))
        lint_plugin_manifest(
            entry, entry_rep, plugin_dir=None, context=ctx,
            known_fields=PLUGIN_FIELDS | MARKETPLACE_ONLY_ENTRY_FIELDS,
            allowed_marketplaces=allowed_set, marketplace_name=name,
        )
        rep.errors.extend(entry_rep.errors)
        rep.warnings.extend(entry_rep.warnings)
        rep.notes.extend(entry_rep.notes)

        # Per-entry pass over a local plugin's own manifest.
        if entry_dir:
            manifest_path = os.path.join(entry_dir, ".claude-plugin", "plugin.json")
            if os.path.isfile(manifest_path):
                sub = Report("%s plugin.json -> %s" % (ctx, manifest_path))
                manifest = load_json(manifest_path, sub)
                if manifest is not None:
                    lint_plugin_manifest(manifest, sub, plugin_dir=entry_dir,
                                         context="%s plugin.json" % ctx,
                                         allowed_marketplaces=allowed_set,
                                         marketplace_name=name)
                    mver = manifest.get("version")
                    ever = entry.get("version")
                    if isinstance(mver, str) and isinstance(ever, str):
                        if mver != ever:
                            sub.error("version mismatch: plugin.json %s vs marketplace entry %s "
                                      "-- plugin.json wins silently" % (mver, ever))
                        else:
                            sub.warn("version set in BOTH plugin.json and the marketplace entry; "
                                     "plugin.json always wins silently -- keep one source of truth")
                    if not isinstance(mver, str) and not isinstance(ever, str):
                        sub.note("no explicit version -- the plugin resolves to its git commit "
                                 "SHA, so every commit is a new version")
                    if entry.get("strict") is False and any(
                            k in manifest for k in ("skills", "commands", "agents", "hooks",
                                                    "mcpServers", "lspServers")):
                        sub.error("strict:false in the marketplace entry while plugin.json also "
                                  "declares components -- conflicting manifests, plugin fails to load")
                sub.emit()
                if sub.errors:
                    rep.errors.append("see %s above" % sub.label)
            else:
                rep.note("%s: no plugin.json at %s -- components will be auto-discovered from "
                         "default directories" % (ctx, manifest_path))

    renames = data.get("renames")
    if renames is not None:
        if not isinstance(renames, dict):
            rep.error("renames: must be an object mapping old name -> new name or null")
        else:
            for old, _ in renames.items():
                if old in entry_names:
                    rep.warn('renames: "%s" is also a live entry in `plugins`' % old)
                seen_chain = [old]
                cur = renames[old]
                while isinstance(cur, str):
                    if cur in seen_chain:
                        rep.error('renames: chain starting at "%s" cycles at "%s"' % (old, cur))
                        break
                    if cur in entry_names:
                        break
                    if cur not in renames:
                        rep.error('renames: chain "%s" -> "%s" does not terminate at null or a '
                                  "name listed in `plugins`" % (old, cur))
                        break
                    seen_chain.append(cur)
                    cur = renames[cur]


def lint_plugin_path(path, rep):
    if os.path.isdir(path):
        manifest_path = os.path.join(path, ".claude-plugin", "plugin.json")
        plugin_dir = path
    else:
        manifest_path = path
        plugin_dir = os.path.dirname(os.path.dirname(os.path.abspath(path)))
    if not os.path.isfile(manifest_path):
        rep.note("no .claude-plugin/plugin.json -- the manifest is optional; components are "
                 "auto-discovered and the plugin is named after its directory")
        lint_plugin_dir(plugin_dir, {}, rep)
        return
    manifest = load_json(manifest_path, rep)
    if manifest is None:
        return
    lint_plugin_manifest(manifest, rep, plugin_dir=plugin_dir)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    failed = False
    for target in argv[1:]:
        abs_target = os.path.abspath(target)
        if os.path.isfile(abs_target) and os.path.basename(abs_target) == "marketplace.json":
            rep = Report(abs_target)
            lint_marketplace(abs_target, rep)
        elif os.path.isdir(abs_target) and os.path.isfile(
                os.path.join(abs_target, ".claude-plugin", "marketplace.json")):
            mpath = os.path.join(abs_target, ".claude-plugin", "marketplace.json")
            rep = Report(mpath)
            lint_marketplace(mpath, rep)
        else:
            rep = Report(abs_target)
            lint_plugin_path(abs_target, rep)
        rep.emit()
        if rep.errors:
            failed = True
    print("")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

# Sources
# - https://code.claude.com/docs/en/plugins
# - https://code.claude.com/docs/en/plugins-reference
# - https://code.claude.com/docs/en/plugin-marketplaces
# - https://code.claude.com/docs/en/plugin-dependencies
# Fetched: 2026-08-05
