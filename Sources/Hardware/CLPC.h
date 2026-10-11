#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <stdint.h>
bool ms_clpc_report_ids(int os_major, const char *bundle, uint64_t ids[3]);
// Firmware-derived M5 Pro/Max channel IDs; see THIRD_PARTY_NOTICES.md.
// Deliberately bounded to macOS 27 and known drivers. Unknown layouts return NULL.
CFMutableDictionaryRef ms_clpc_channels(int os_major);
