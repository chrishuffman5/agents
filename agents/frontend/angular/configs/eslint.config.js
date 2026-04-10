// Annotated ESLint Flat Config for Angular
// File: eslint.config.js (root of workspace)
//
// Angular 17+ uses ESLint flat config format.
// Install: ng add @angular-eslint/schematics
// Run: ng lint
//
// Packages required:
//   @angular-eslint/eslint-plugin
//   @angular-eslint/eslint-plugin-template
//   @angular-eslint/template-parser
//   @typescript-eslint/eslint-plugin
//   @typescript-eslint/parser

// @ts-check
const eslint = require("@eslint/js");
const tseslint = require("typescript-eslint");
const angular = require("angular-eslint");

module.exports = tseslint.config(
  // ─── GLOBAL IGNORES ──────────────────────────────────────────────────────
  {
    ignores: ["dist/", "node_modules/", ".angular/"],
  },

  // ─── TYPESCRIPT FILES ────────────────────────────────────────────────────
  {
    files: ["**/*.ts"],
    extends: [
      eslint.configs.recommended,
      ...tseslint.configs.recommended,
      ...tseslint.configs.stylistic,
      ...angular.configs.tsRecommended,
    ],
    processor: angular.processInlineTemplates,
    rules: {
      // ── Angular-specific rules ──────────────────────────────────────────

      // Enforce consistent component selector style
      "@angular-eslint/component-selector": [
        "error",
        {
          type: "element",
          prefix: "app", // change to your project prefix
          style: "kebab-case",
        },
      ],

      // Enforce consistent directive selector style
      "@angular-eslint/directive-selector": [
        "error",
        {
          type: "attribute",
          prefix: "app", // change to your project prefix
          style: "camelCase",
        },
      ],

      // Prefer standalone components (v17+)
      "@angular-eslint/prefer-standalone": "warn",

      // Prefer OnPush change detection strategy
      "@angular-eslint/prefer-on-push-component-change-detection": "warn",

      // Ensure components have proper lifecycle interface implementation
      "@angular-eslint/use-lifecycle-interface": "error",

      // Disallow empty lifecycle methods
      "@angular-eslint/no-empty-lifecycle-method": "error",

      // Prefer output() over @Output() decorator
      "@angular-eslint/prefer-output-readonly": "warn",

      // ── TypeScript rules ────────────────────────────────────────────────

      // Allow empty functions (lifecycle hooks may be empty initially)
      "@typescript-eslint/no-empty-function": "off",

      // Warn on unused variables (prefix with _ to ignore intentionally)
      "@typescript-eslint/no-unused-vars": [
        "warn",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],

      // Allow explicit any in specific cases (prefer unknown)
      "@typescript-eslint/no-explicit-any": "warn",
    },
  },

  // ─── HTML TEMPLATES ──────────────────────────────────────────────────────
  {
    files: ["**/*.html"],
    extends: [
      ...angular.configs.templateRecommended,
      ...angular.configs.templateAccessibility,
    ],
    rules: {
      // Accessibility: require alt text on images
      "@angular-eslint/template/alt-text": "error",

      // Accessibility: interactive elements must be focusable
      "@angular-eslint/template/interactive-supports-focus": "error",

      // Accessibility: click events need keyboard counterparts
      "@angular-eslint/template/click-events-have-key-events": "warn",

      // Accessibility: require valid ARIA attributes
      "@angular-eslint/template/valid-aria": "error",

      // Performance: prefer @for track expression over trackBy
      "@angular-eslint/template/prefer-control-flow": "warn",
    },
  }
);
