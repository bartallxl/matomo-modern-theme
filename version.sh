#!/bin/bash

set -e

DRY_RUN=false
CHANGELOG_MESSAGE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -m|--message)
            CHANGELOG_MESSAGE="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option $1"
            echo "Usage: $0 <new_version> -m|--message \"changelog message\" [--dry-run]"
            echo "Example: $0 5.0.7 -m \"Fix bug with dark mode\""
            echo "         $0 5.0.7 --message \"Add new feature\" --dry-run"
            exit 1
            ;;
        *)
            if [ -z "$NEW_VERSION" ]; then
                NEW_VERSION="$1"
            else
                echo "Error: Multiple version numbers provided"
                echo "Usage: $0 <new_version> -m|--message \"changelog message\" [--dry-run]"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$NEW_VERSION" ]; then
    echo "Usage: $0 <new_version> -m|--message \"changelog message\" [--dry-run]"
    echo "Example: $0 5.0.7 -m \"Fix bug with dark mode\""
    echo "         $0 5.0.7 --message \"Add new feature\" --dry-run"
    exit 1
fi

if [ -z "$CHANGELOG_MESSAGE" ]; then
    echo "Error: Changelog message is required"
    echo "Usage: $0 <new_version> -m|--message \"changelog message\" [--dry-run]"
    echo "Example: $0 5.0.7 -m \"Fix bug with dark mode\""
    exit 1
fi

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN MODE - No changes will be made"
    echo "======================================"
fi

if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format X.Y.Z (e.g., 5.0.7)"
    exit 1
fi

echo "Updating version to $NEW_VERSION..."

# Get current version from plugin.json
CURRENT_VERSION=$(grep '"version"' plugin.json | sed 's/.*"version": "\(.*\)",/\1/')
echo "Current version: $CURRENT_VERSION"

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "Warning: You have uncommitted changes. Please commit or stash them first."
    if [ "$DRY_RUN" = false ]; then
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "(In dry-run mode, would prompt to continue)"
    fi
fi

# Update plugin.json
if [ "$DRY_RUN" = false ]; then
    echo "Updating plugin.json..."
    sed -i.bak "s/\"version\": \"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" plugin.json
    rm plugin.json.bak
else
    echo "Would update plugin.json:"
    echo "  Change version from '$CURRENT_VERSION' to '$NEW_VERSION'"
fi

# Update CHANGELOG.md
if [ "$DRY_RUN" = false ]; then
    echo "Updating CHANGELOG.md..."
    # Create a temporary file with the new entry
    cat > temp_changelog.md << EOF
# Changelog

## v$NEW_VERSION

- $CHANGELOG_MESSAGE

EOF
    
    # Append the rest of the changelog (skip the first two lines)
    tail -n +3 CHANGELOG.md >> temp_changelog.md
    mv temp_changelog.md CHANGELOG.md
    
    echo "Added new version entry to CHANGELOG.md"
else
    echo "Would update CHANGELOG.md:"
    echo "  Add new entry '## v$NEW_VERSION' at the top"
    echo "  Add changelog entry: '$CHANGELOG_MESSAGE'"
fi

# Commit changes
if [ "$DRY_RUN" = false ]; then
    echo "Committing changes..."
    git add plugin.json CHANGELOG.md
    git commit -m "Version $NEW_VERSION"
else
    echo "Would commit changes:"
    echo "  git add plugin.json CHANGELOG.md"
    echo "  git commit -m 'Version $NEW_VERSION'"
fi

# Create git tag
if [ "$DRY_RUN" = false ]; then
    echo "Creating git tag $NEW_VERSION..."
    git tag "$NEW_VERSION"
else
    echo "Would create git tag:"
    echo "  git tag '$NEW_VERSION'"
fi

if [ "$DRY_RUN" = false ]; then
    echo "Successfully updated to version $NEW_VERSION"
    echo "Next steps:"
    echo "1. Push the changes: git push origin main"
    echo "2. Push the tag: git push origin $NEW_VERSION"
else
    echo ""
    echo "DRY RUN COMPLETE"
    echo "================"
    echo "To actually perform these changes, run:"
    echo "  $0 $NEW_VERSION -m \"$CHANGELOG_MESSAGE\""
    echo ""
    echo "After running, you would need to:"
    echo "1. Push the changes: git push origin main"
    echo "2. Push the tag: git push origin $NEW_VERSION"
fi