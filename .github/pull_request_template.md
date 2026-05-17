# Pull Request

## Description
<!-- Provide a clear description of your changes -->

## Type of Change
<!-- Mark the relevant option with an 'x' -->
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Code quality improvement (refactoring, linting, etc.)

## Testing
<!-- Describe the tests you ran to verify your changes -->

**Device-profile changes:**
- [ ] Not applicable
- [ ] I ran `bash tests/device-manager-detection.sh`
- [ ] I ran `bash scripts/sync-device-matrix.sh` and committed the generated updates

**Tested on:**
- [ ] Arch Linux / EndeavourOS / Manjaro
- [ ] Ubuntu / Pop!_OS / Linux Mint
- [ ] Fedora / Nobara
- [ ] OpenSUSE Tumbleweed / Leap

**Test Results:**
```
<!-- Paste any relevant test output -->
```

## Code Quality Checklist
- [ ] My code passes `bash -n` syntax validation
- [ ] My code passes `shellcheck` with zero warnings
- [ ] I ran `bash tests/validate-version-sync.sh`
- [ ] I have followed the code style guidelines in CONTRIBUTING.md
- [ ] I have used proper quoting for all variables
- [ ] I have added `-r` flag to all `read` commands
- [ ] I have separated variable declarations from assignments

## Distribution Support
- [ ] Changes work on all 4 supported distribution families
- [ ] Arch-based implementation complete
- [ ] Debian/Ubuntu-based implementation complete
- [ ] Fedora-based implementation complete
- [ ] OpenSUSE implementation complete

## Documentation
- [ ] I have updated relevant documentation (README.md, CONTRIBUTING.md, etc.)
- [ ] I have synced generated device-matrix blocks if supported-device data changed
- [ ] I have added version numbers where applicable
- [ ] I have updated CHANGELOG.md for this version bump
- [ ] Code comments are clear and follow existing style

## Additional Notes
<!-- Any additional information that reviewers should know -->

## Related Issues
<!-- Link any related issues: Fixes #123, Related to #456 -->
