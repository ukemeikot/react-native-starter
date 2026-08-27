# Agent guide

Entry point for AI coding agents working in this repository. Claude Code also
loads the skills under `.claude/skills/`; other agents should read this file plus
the skill files it points to.

## Skills in this repo

| Skill                                                                              | Use for                                                                           |
| ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| [`vercel-react-native-skills`](.claude/skills/vercel-react-native-skills/SKILL.md) | React Native performance: lists, animations, rendering, state, navigation, images |
| [`expo`](.claude/skills/expo/SKILL.md)                                             | Expo SDK, expo-router, config plugins, development builds, EAS, SDK upgrades      |

`vercel-react-native-skills` is vendored from
[vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) (MIT). Its
38 rule files live in `rules/`, and `reference/AGENTS.md` is the full compiled
guide. Read the specific rule file rather than the whole compiled document when
you already know the topic.

Expo's official skills ([expo/skills](https://github.com/expo/skills), MIT) are
**installed rather than vendored**, since Expo revises them each SDK release. See
the `expo` skill for install commands.

## Project shape

Vertical slice architecture. A feature owns its own API layer, components, hooks,
schemas and store:

```
src/features/<feature>/{api,components,hooks,schemas,store}/
src/shared/{api,components,constants,hooks,storage,store,theme}/
src/app/                 expo-router routes; (auth) (main) (onboarding) groups
```

Put code in `src/shared/` only once a second feature needs it. Cross-feature
imports are a smell — lift the shared piece into `src/shared/` instead.

- Path alias `@/*` → `./src/*`, declared in both `tsconfig.json` and
  `babel.config.js`. Keep them in sync.
- State: Zustand, one store per feature slice. Server state: TanStack Query.
- Forms: React Hook Form + Zod. Tokens: expo-secure-store. Prefs: AsyncStorage.

## Before you commit

Every one of these runs in CI and must pass:

```sh
pnpm lint                                        # eslint, --max-warnings 0
pnpm typecheck                                   # app project
pnpm exec tsc --noEmit --project tsconfig.test.json   # test project
pnpm test                                        # jest
pnpm format:check                                # prettier
pnpm audit --audit-level high --prod
pnpm scan                                        # supply-chain implant scan
```

`tsconfig.json` (app) excludes `__tests__`; `tsconfig.test.json` covers it with
jest types. They are separate projects on purpose — do not merge them.

## Security constraints

This repository enforces a supply-chain scan because build-time config files are
a known implant target — they execute on every build but are rarely read closely.

- Never add `postinstall` / `preinstall` scripts.
- Keep `babel.config.js` and `metro.config.js` minimal. CI fails them at >4 KB,
  on lines >500 chars, on obfuscator signatures, and on `child_process`, `eval`,
  `Function(`, `zlib` or raw socket use.
- Never paste minified or generated code into a config file.
- Do not add a CI step that downloads and executes a script from the network.
- Add dependencies with `pnpm exec expo install` so versions match the SDK.
