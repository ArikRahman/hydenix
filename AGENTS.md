# Hydenix Project Context for AI Agents

## Project Overview
Hydenix is a NixOS configuration template using Flakes. It allows users to customize their NixOS setup, add packages, and configure themes. Based off https://github.com/richen604/hydenix

## Key Files and Directories

- **flake.nix**: The entry point for the Nix Flake. Defines inputs and outputs.
- **configuration.nix**: The main NixOS system configuration file.
- **hardware-configuration.nix**: Hardware-specific settings, usually auto-generated.
- **modules/**: Contains custom modules.
  - **hm/**: Home Manager modules.
  - **system/**: System-level NixOS modules.
- **docs/**: Documentation files.

## Development Guidelines

- When modifying configuration, prefer editing for home manager, or files in `modules/`.
- Ensure `flake.nix` is updated if new inputs are required.
- Follow Nix language best practices.
- Comment thoroughly on why you're adding something
- everytime you make a mistake, comment what you got wrong and how you corrected it
- instead of debugging from terminal, dump output into log text file workflow
- stop deleting lines, and rather, comment them out and make note of why you are getting rid of them
----------
According to manus:
Why This Skill?

On December 29, 2025, Meta acquired Manus for $2 billion. In just 8 months, Manus went from launch to $100M+ revenue. Their secret? Context engineering.

This skill implements Manus's core workflow pattern:

    "Markdown is my 'working memory' on disk. Since I process information iteratively and my active context has limits, Markdown files serve as scratch pads for notes, checkpoints for progress, building blocks for final deliverables." — Manus AI

The Problem

Claude Code (and most AI agents) suffer from:

    Volatile memory — TodoWrite tool disappears on context reset
    Goal drift — After 50+ tool calls, original goals get forgotten
    Hidden errors — Failures aren't tracked, so the same mistakes repeat
    Context stuffing — Everything crammed into context instead of stored

The Solution: 3-File Pattern

For every complex task, create THREE files:

task_plan.md      → Track phases and progress
notes.md          → Store research and findings
[deliverable].md  → Final output

The Loop

1. Create task_plan.md with goal and phases
2. Research → save to notes.md → update task_plan.md
3. Read notes.md → create deliverable → update task_plan.md
4. Deliver final output
------------
Key insight: By reading task_plan.md before each decision, goals stay in the attention window. This is how Manus handles ~50 tool calls without losing track.


- > z hydenix; sudo nixos-rebuild switch --flake .#hydenix 
- ^ command to update nixos
