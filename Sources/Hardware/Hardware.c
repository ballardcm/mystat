#include "Hardware.h"
#include "CLPC.h"
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <dlfcn.h>

// AppleSMC user-client ABI. Only read-key-info, read-index and read-bytes are used.
typedef struct {
    uint32_t key;
    struct { uint8_t major, minor, build, reserved; uint16_t release; } version;
    struct { uint16_t version, length; uint32_t cpu, gpu, memory; } limits;
    struct { uint32_t size, type; uint8_t attributes; } info;
    uint8_t result, status, command;
    uint32_t index;
    uint8_t bytes[32];
} SMCPacket;
_Static_assert(sizeof(SMCPacket) == 80, "AppleSMC ABI size");
typedef struct { uint32_t key, size, type; uint8_t attributes; } SMCKeyInfo;
struct MSCSensor { io_connect_t connection; SMCKeyInfo cache[512]; size_t cached; };
static uint32_t fourcc(const char *s) {
    return ((uint32_t)(uint8_t)s[0] << 24) | ((uint32_t)(uint8_t)s[1] << 16) |
           ((uint32_t)(uint8_t)s[2] << 8) | (uint8_t)s[3];
}
static bool call(MSCSensor *s, SMCPacket *in, SMCPacket *out) {
    if (!s) return false;
    size_t size = sizeof(*out);
    return IOConnectCallStructMethod(s->connection, 2, in, sizeof(*in), out, &size) == KERN_SUCCESS && out->result == 0;
}
MSCSensor *msc_open(void) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return NULL;
    io_connect_t connection = 0;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    if (result != KERN_SUCCESS) return NULL;
    MSCSensor *s = calloc(1, sizeof(*s));
    if (!s) { IOServiceClose(connection); return NULL; }
    s->connection = connection;
    return s;
}
void msc_close(MSCSensor *s) { if (s) { IOServiceClose(s->connection); free(s); } }
bool msc_key_at(MSCSensor *s, uint32_t index, char key[5]) {
    SMCPacket in = {0}, out = {0}; in.command = 8; in.index = index;
    if (!call(s, &in, &out)) return false;
    for (int i = 0; i < 4; i++) key[i] = (out.key >> (24 - i * 8)) & 255;
    key[4] = 0; return true;
}
bool msc_read(MSCSensor *s, const char *key, double *value) {
    if (!key || strlen(key) != 4 || !value) return false;
    if (!s) return false;
    SMCPacket in = {0}, out = {0}; in.key = fourcc(key);
    SMCKeyInfo *cached = NULL;
    for (size_t i = 0; i < s->cached; i++) { if (s->cache[i].key == in.key) { cached = &s->cache[i]; break; } }
    if (cached) {
        in.info.size = cached->size; in.info.type = cached->type; in.info.attributes = cached->attributes;
    } else {
        in.command = 9;
        if (!call(s, &in, &out) || out.info.size == 0 || out.info.size > 32) return false;
        in.info = out.info;
        if (s->cached < 512) s->cache[s->cached++] = (SMCKeyInfo){in.key, in.info.size, in.info.type, in.info.attributes};
    }
    uint32_t type = in.info.type, size = in.info.size;
    in.command = 5;
    memset(&out, 0, sizeof(out));
    if (!call(s, &in, &out)) return false;
    if (type == fourcc("flt ") && size == 4) { float f; memcpy(&f, out.bytes, 4); *value = f; }
    else if (type == fourcc("sp78") && size == 2) *value = (int16_t)((out.bytes[0] << 8) | out.bytes[1]) / 256.0;
    else if (type == fourcc("fpe2") && size == 2) *value = ((out.bytes[0] << 8) | out.bytes[1]) / 4.0;
    else if ((type == fourcc("ui8 ") && size == 1) || (type == fourcc("ui16") && size == 2) || (type == fourcc("ui32") && size == 4)) {
        uint32_t n = 0; for (uint32_t i = 0; i < size; i++) n = (n << 8) | out.bytes[i]; *value = n;
    } else return false;
    return isfinite(*value);
}

// Resolve the private, read-only IOReport API at runtime; missing API is N/A.
struct MSPower {
    void *library;
    CFTypeRef subscription;
    CFMutableDictionaryRef channels;
    CFDictionaryRef previous;
    double timestamp;
    CFDictionaryRef (*samples)(CFTypeRef, CFMutableDictionaryRef, CFTypeRef);
    CFDictionaryRef (*delta)(CFDictionaryRef, CFDictionaryRef, CFTypeRef);
    int64_t (*integer)(CFDictionaryRef, int);
    CFStringRef (*name)(CFDictionaryRef);
    CFStringRef (*unit)(CFDictionaryRef);
};
static double monotime(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
MSPower *msp_open(int os_major) {
    MSPower *p = calloc(1, sizeof(*p)); if (!p) return NULL;
    p->library = dlopen("/usr/lib/libIOReport.dylib", RTLD_LAZY | RTLD_LOCAL);
    if (!p->library) { free(p); return NULL; }
    CFMutableDictionaryRef (*copy)(CFStringRef, CFStringRef, uint64_t, uint64_t, uint64_t) = dlsym(p->library, "IOReportCopyChannelsInGroup");
    CFTypeRef (*subscribe)(void *, CFMutableDictionaryRef, CFMutableDictionaryRef *, uint64_t, CFTypeRef) = dlsym(p->library, "IOReportCreateSubscription");
    p->samples = dlsym(p->library, "IOReportCreateSamples");
    p->delta = dlsym(p->library, "IOReportCreateSamplesDelta");
    p->integer = dlsym(p->library, "IOReportSimpleGetIntegerValue");
    p->name = dlsym(p->library, "IOReportChannelGetChannelName");
    p->unit = dlsym(p->library, "IOReportChannelGetUnitLabel");
    if (!copy || !subscribe || !p->samples || !p->delta || !p->integer || !p->name || !p->unit) { msp_close(p); return NULL; }
    CFMutableDictionaryRef available = os_major >= 27 ? ms_clpc_channels(os_major) : copy(CFSTR("Energy Model"), NULL, 0, 0, 0);
    if (!available) { msp_close(p); return NULL; }
    p->subscription = subscribe(NULL, available, &p->channels, 0, NULL);
    CFRelease(available);
    if (!p->subscription || !p->channels) { msp_close(p); return NULL; }
    return p;
}
double ms_energy_watts(int64_t energy, const char *unit, double elapsed) {
    if (!unit || energy < 0 || !isfinite(elapsed) || elapsed <= 0.05 || elapsed >= 30) return NAN;
    double divisor = !strcmp(unit, "mJ") ? 1e3 : !strcmp(unit, "uJ") ? 1e6 : !strcmp(unit, "nJ") ? 1e9 : !strcmp(unit, "J") ? 1 : 0;
    return divisor ? energy / divisor / elapsed : NAN;
}
MSPowerSample msp_sample(MSPower *p) {
    MSPowerSample result = {NAN, NAN, NAN, NAN}; if (!p) return result;
    CFDictionaryRef sample = p->samples(p->subscription, p->channels, NULL);
    double now = monotime(); if (!sample) return result;
    CFDictionaryRef delta = p->previous ? p->delta(p->previous, sample, NULL) : NULL;
    double elapsed = now - p->timestamp;
    if (p->previous) CFRelease(p->previous);
    p->previous = sample; p->timestamp = now;
    if (!delta) return result;
    // Discard wake-from-sleep gaps instead of reporting misleading averages.
    if (elapsed > 0.05 && elapsed < 30) {
        CFArrayRef channels = CFDictionaryGetValue(delta, CFSTR("IOReportChannels"));
        if (channels && CFGetTypeID(channels) == CFArrayGetTypeID()) {
            for (CFIndex i = 0; i < CFArrayGetCount(channels); i++) {
                CFDictionaryRef item = CFArrayGetValueAtIndex(channels, i);
                CFStringRef n = p->name(item), u = p->unit(item);
                char name[128] = {0}, unit[32] = {0};
                if (!n || !u || !CFStringGetCString(n, name, sizeof(name), kCFStringEncodingUTF8) || !CFStringGetCString(u, unit, sizeof(unit), kCFStringEncodingUTF8)) continue;
                double watts = ms_energy_watts(p->integer(item, 0), unit, elapsed);
                if (!isfinite(watts)) continue;
                double *target = NULL;
                if (!strcmp(name, "CPU Energy")) target = &result.cpu;
                else if (!strcmp(name, "GPU Energy")) target = &result.gpu;
                else if (!strncmp(name, "ANE", 3)) target = &result.ane;
                else if (!strcmp(name, "DRAM Energy")) target = &result.dram;
                if (target) *target = (isnan(*target) ? 0 : *target) + watts;
            }
        }
    }
    CFRelease(delta); return result;
}
void msp_close(MSPower *p) {
    if (!p) return;
    if (p->previous) CFRelease(p->previous);
    if (p->channels) CFRelease(p->channels);
    if (p->subscription) CFRelease(p->subscription);
    if (p->library) dlclose(p->library);
    free(p);
}
