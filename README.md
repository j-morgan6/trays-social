# Trays Social

A food focused social platform for home cooks to share what they make, build a personal recipe collection, and connect with other cooking enthusiasts.

## About

Trays Social combines visual content sharing with structured recipe documentation. Users can post photos of their food along with detailed ingredients, tools, cooking methods, and cooking times. The platform helps home cooks document their culinary experiences and inspire others.

## Tech Stack

- Phoenix 1.8.3 with LiveView
- Elixir 1.19.2
- PostgreSQL
- Tailwind CSS

## Features

### Current (MVP)
- User authentication with username and password
- User profiles with bio and photo
- Post creation with photos, ingredients, tools, and cooking instructions
- Chronological feed of all posts
- Individual post detail pages

### Planned
- Following system
- Likes and comments
- Ingredient based search
- Recipe collections
- Mobile applications

## First-time setup

After cloning the repo:

```bash
brew bundle              # installs SwiftFormat, SwiftLint, xcodegen
./scripts/setup-hooks.sh # activates pre-commit and pre-push hooks
```

Hooks run automatically on `git commit` and `git push`. To reproduce manually:

- `./scripts/lint-ios.sh` — strict-mode lint of the iOS tree
- `./scripts/lint-ios.sh --fix` — same, with auto-fix applied
- `./scripts/build-ios-release.sh` — Release build (matches pre-push)

Bypass with `git commit --no-verify` or `git push --no-verify` only in emergencies; run the corresponding manual script before your next non-bypassed commit.
