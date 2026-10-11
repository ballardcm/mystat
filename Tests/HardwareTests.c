#include "Hardware.h"
#include "CLPC.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>

int main(void) {
    // Independent expected full IDs from macmon's macOS 27 firmware catalog.
    uint64_t ids[3] = {0};
    assert(ms_clpc_report_ids(27, "com.apple.driver.AppleT6050CLPC", ids));
    assert(ids[0] == 0x00000010d3ab60bbULL);
    assert(ids[1] == 0x0000001927cd4ce5ULL);
    assert(ids[2] == 0x000000188c0f1c59ULL);
    assert(ms_clpc_report_ids(27, "com.apple.driver.AppleT6050dCLPC", ids));
    assert(ids[0] == 0x0000001018b3010eULL);
    assert(ids[1] == 0x00000019edeca11aULL);
    assert(ids[2] == 0x00000018188bd883ULL);
    assert(!ms_clpc_report_ids(26, "com.apple.driver.AppleT6050CLPC", ids));
    assert(!ms_clpc_report_ids(28, "com.apple.driver.AppleT6050CLPC", ids));
    assert(!ms_clpc_report_ids(27, "com.apple.driver.UnknownCLPC", ids));
    assert(!ms_clpc_report_ids(27, NULL, ids));
    assert(fabs(ms_energy_watts(5000, "mJ", 2) - 2.5) < 1e-9);
    assert(fabs(ms_energy_watts(5000000, "uJ", 2) - 2.5) < 1e-9);
    assert(fabs(ms_energy_watts(5000000000LL, "nJ", 2) - 2.5) < 1e-9);
    assert(ms_energy_watts(0, "nJ", 2) == 0);
    assert(isnan(ms_energy_watts(-1, "nJ", 2)));
    assert(isnan(ms_energy_watts(1, "mW", 2)));
    assert(isnan(ms_energy_watts(1, "mJ", 0)));
    assert(isnan(ms_energy_watts(1, "mJ", 60)));
    assert(isnan(ms_energy_watts(1, "mJ", NAN)));
    puts("PASS: macOS 27 counter mappings, unknown-version/driver rejection, energy units, invalid deltas, and sleep-gap rejection.");
}
