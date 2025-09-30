#!/usr/bin/env bash
set -euo pipefail

#######################################
# Gem Migration & Seeding
#######################################

# This script migrates legacy gems (~/.gems) to the canonical GEM_HOME under
# ~/.gem/ruby/<version> and seeds gems from /coder/gems when present.

echo "Starting gem migration & seeding for user: $(whoami)"

CANONICAL_BASE="$HOME/.gem"
LEGACY_DIR="$HOME/.gems"

if command -v ruby >/dev/null 2>&1; then
  RUBY_RUNTIME_VERSION="${RUBY_VERSION:-$(ruby -e 'print RUBY_VERSION' 2>/dev/null || echo 3.4.6)}"
  GEM_HOME_DIR="$CANONICAL_BASE/ruby/$RUBY_RUNTIME_VERSION"

  echo "INFO: checking for gem migration from legacy .gems to canonical .gem for ruby $RUBY_RUNTIME_VERSION"

  version="$RUBY_RUNTIME_VERSION"
  legacy_version_dir="$LEGACY_DIR/$version"
  migration_marker="${LEGACY_DIR}.migrated.${version}.marker"

  if [ -d "$legacy_version_dir" ] && [ ! -f "$migration_marker" ]; then
    echo "INFO: Migrating legacy gems from $legacy_version_dir to $GEM_HOME_DIR"
    mkdir -p "$GEM_HOME_DIR"
    rsync -a "$legacy_version_dir/" "$GEM_HOME_DIR/" || true
    chown -R embold:embold "$CANONICAL_BASE" 2>/dev/null || true
    touch "$migration_marker" 2>/dev/null || true
    echo "INFO: Legacy gem migration complete"

  elif [ -d "$LEGACY_DIR" ] && [ ! -f "$migration_marker" ] && [ ! -d "$GEM_HOME_DIR" ]; then
    candidate=$(ls -1 "$LEGACY_DIR" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)
    if [ -n "$candidate" ] && [ -d "$LEGACY_DIR/$candidate" ]; then
      echo "WARN: Using legacy gems for Ruby $candidate (may be incompatible with $version)"
      mkdir -p "$GEM_HOME_DIR"
      rsync -a "$LEGACY_DIR/$candidate/" "$GEM_HOME_DIR/" || true
      chown -R embold:embold "$CANONICAL_BASE" 2>/dev/null || true
      touch "$migration_marker" 2>/dev/null || true
      echo "INFO: Fallback migration complete"
    fi
  else
    echo "INFO: No legacy gem migration needed"
  fi

  # Seed gems from image to mounted home directory (persistent coder area)
  if [ -d "/coder/gems/ruby/${RUBY_RUNTIME_VERSION}" ]; then
    if [ ! -d "$GEM_HOME_DIR" ] || [ -z "$(ls -A "$GEM_HOME_DIR" 2>/dev/null)" ]; then
      echo "INFO: Seeding gems from /coder/gems to $GEM_HOME_DIR"
      mkdir -p "$(dirname "$GEM_HOME_DIR")"

      if mv "/coder/gems/ruby/${RUBY_RUNTIME_VERSION}" "$GEM_HOME_DIR" 2>/dev/null; then
        echo "INFO: Successfully moved gems (no duplicates left behind)"
      else
        mkdir -p "$GEM_HOME_DIR"
        rsync -a "/coder/gems/ruby/${RUBY_RUNTIME_VERSION}/" "$GEM_HOME_DIR/" || true
        echo "INFO: Copied gems (source remains in image)"
      fi

      echo "INFO: Gem seeding complete"
    else
      echo "INFO: Gems already present in $GEM_HOME_DIR, skipping seed"
    fi
  else
    echo "INFO: No image gems found for Ruby ${RUBY_RUNTIME_VERSION}"
  fi
fi

echo "Gem migration & seeding finished"
