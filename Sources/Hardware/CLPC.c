#include "CLPC.h"
#include <IOKit/IOKitLib.h>
#include <stdint.h>
#include <string.h>

static CFNumberRef number(uint64_t value) { return CFNumberCreate(NULL, kCFNumberSInt64Type, &value); }
static CFMutableDictionaryRef dictionary(void) {
    return CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}
bool ms_clpc_report_ids(int os_major, const char *bundle, uint64_t ids[3]) {
    if (os_major != 27 || !bundle || !ids) return false;
    uint32_t keys[3];
    if (!strcmp(bundle, "com.apple.driver.AppleT6050CLPC")) {
        keys[0] = 0xd3ab60bb; keys[1] = 0x27cd4ce5; keys[2] = 0x8c0f1c59;
    } else if (!strcmp(bundle, "com.apple.driver.AppleT6050dCLPC")) {
        keys[0] = 0x18b3010e; keys[1] = 0xedeca11a; keys[2] = 0x188bd883;
    } else return false;
    const uint32_t indices[] = {16, 25, 24};
    for (int i = 0; i < 3; i++) ids[i] = ((uint64_t)indices[i] << 32) | keys[i];
    return true;
}
CFMutableDictionaryRef ms_clpc_channels(int os_major) {
    if (os_major != 27) return NULL;
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleCLPC"));
    if (!service) return NULL;
    uint64_t driver = 0;
    kern_return_t status = IORegistryEntryGetRegistryEntryID(service, &driver);
    CFTypeRef bundle = IORegistryEntryCreateCFProperty(service, CFSTR("CFBundleIdentifier"), NULL, 0);
    IOObjectRelease(service);
    char name[128] = {0};
    bool valid = status == KERN_SUCCESS && bundle && CFGetTypeID(bundle) == CFStringGetTypeID() && CFStringGetCString(bundle, name, sizeof(name), kCFStringEncodingUTF8);
    if (bundle) CFRelease(bundle);
    if (!valid) return NULL;
    uint64_t ids[3];
    if (!ms_clpc_report_ids(os_major, name, ids)) return NULL;
    const CFStringRef names[] = {CFSTR("CPU Energy"), CFSTR("GPU Energy"), CFSTR("ANE Energy")};
    CFMutableArrayRef channels = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    for (int i = 0; i < 3; i++) {
        CFNumberRef id = number(ids[i]);
        CFNumberRef format = number(1ULL | (2ULL << 16) | (1ULL << 32));
        CFNumberRef unit = number((3ULL << 56) | (118ULL << 32));
        CFNumberRef owner = number(driver);
        const void *values[] = {id, format, names[i]};
        CFArrayRef legend = CFArrayCreate(NULL, values, 3, &kCFTypeArrayCallBacks);
        CFMutableDictionaryRef info = dictionary(), channel = dictionary();
        CFDictionarySetValue(info, CFSTR("IOReportChannelUnit"), unit);
        CFDictionarySetValue(channel, CFSTR("DriverID"), owner);
        CFDictionarySetValue(channel, CFSTR("DriverName"), CFSTR("AppleCLPC"));
        CFDictionarySetValue(channel, CFSTR("IOReportGroupName"), CFSTR("CLPC"));
        CFDictionarySetValue(channel, CFSTR("IOReportSubGroupName"), CFSTR("Energy Counters"));
        CFDictionarySetValue(channel, CFSTR("IOReportChannelInfo"), info);
        CFDictionarySetValue(channel, CFSTR("LegendChannel"), legend);
        CFArrayAppendValue(channels, channel);
        CFRelease(channel); CFRelease(info); CFRelease(legend); CFRelease(id); CFRelease(format); CFRelease(unit); CFRelease(owner);
    }
    CFMutableDictionaryRef result = dictionary();
    CFDictionarySetValue(result, CFSTR("IOReportChannels"), channels);
    CFRelease(channels);
    return result;
}
