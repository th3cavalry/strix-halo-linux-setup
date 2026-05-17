---
name: Bug Report
about: Report a problem with the GZ302 Linux Setup scripts
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description
<!-- A clear and concise description of what the bug is -->

## System Information
**Distribution:** <!-- e.g., Arch Linux, Ubuntu 24.04, Fedora 40 -->
**Kernel Version:** <!-- Output of: uname -r -->
**Script Version:** <!-- Check header of strix-halo-setup.sh or run: grep 'Version:' strix-halo-setup.sh -->

**Hardware:**
```
<!-- Paste output of: lscpu | grep "Model name" -->
<!-- Paste output of: lspci | grep VGA -->
```

**DMI identity:**
```text
<!-- Paste output of:
for field in sys_vendor product_name product_family board_name; do
	printf "%s: " "$field"
	cat "/sys/class/dmi/id/$field" 2>/dev/null || echo "unavailable"
done
-->
```

**Detected device profile:**
```text
<!-- If you cloned the repo locally, paste output of:
sudo bash -lc 'source strix-halo-lib/device-manager.sh && device_detect && device_print_profile'
-->
```

## Steps to Reproduce
1. 
2. 
3. 

## Expected Behavior
<!-- What you expected to happen -->

## Actual Behavior
<!-- What actually happened -->

## Error Messages
```
<!-- Paste any error messages here -->
```

## Logs
<!-- If applicable, attach or paste relevant log output -->

## Additional Context
<!-- Add any other context about the problem here -->

## Checklist
- [ ] I have searched existing issues for duplicates
- [ ] I am using one of the supported distributions (Arch, Debian/Ubuntu, Fedora, OpenSUSE)
- [ ] I ran the script with sudo privileges
- [ ] I have an active internet connection
- [ ] I included DMI identity fields and the detected device profile above when this issue is hardware-specific
