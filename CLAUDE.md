# Project Instructions for Claude

## 🔴 CRITICAL PRIORITY: Elixir Plugin Documentation

**This is your PRIMARY responsibility when working on this project.**

### The Rule
Whenever you discover a new pattern, encounter a pitfall, or learn something about Elixir/Phoenix development, you MUST:

1. **STOP what you're doing immediately**
2. **Document it in `ELIXIR_PLUGIN_IMPROVEMENTS.md`**
3. **Then continue with your work**

### Why This Matters
This project is being used to improve the Elixir Claude optimization plugin. Your documentation will help create better skills and hooks for future Elixir/Phoenix development.

### What to Document
- New skill ideas (e.g., "phoenix-auth-customization")
- Common patterns you discover
- Pitfalls and how to avoid them
- Hooks that could be automated
- Testing patterns
- Migration patterns
- Any "aha!" moments

### Where to Document
File: `ELIXIR_PLUGIN_IMPROVEMENTS.md`

Structure:
- **Potential New Skills** - What skills should exist
- **Pattern Templates** - Reusable code patterns
- **Hooks to Consider** - Automation opportunities
- **Session Notes** - Key learnings from each task

## Project Context

### Technology
- Phoenix 1.8.3 + LiveView
- Elixir 1.19.2-otp-28
- PostgreSQL
- Password-based authentication

### Current State
- W1 ✅ Complete: Phoenix initialization with auth
- W2-W10: Posts, feed, profiles, etc. (see Stride tasks)

### Key Decisions
- Password authentication (not magic link)
- Username required (3-30 chars, alphanumeric + underscores)
- Email confirmation skipped for MVP

### Testing Requirements
- All tests must pass before completing tasks
- Skip tests for unused features (e.g., magic link tests)
- Update fixtures when adding required fields

## Workflow
1. Use Stride task system (W1, W2, W3...)
2. Execute hooks: before_doing → after_doing → before_review
3. Document plugin improvements AS YOU GO
4. Run tests before completing tasks

## Important Files
- `ELIXIR_PLUGIN_IMPROVEMENTS.md` - **TOP PRIORITY**
- `.stride.md` - Stride hooks
- `2026-02-04-food-social-app-design.md` - Full MVP design
- `MEMORY.md` - Auto memory (in ~/.claude/projects/.../memory/)
