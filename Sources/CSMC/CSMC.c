#include "CSMC.h"
#include <string.h>

static kern_return_t csmc_call(io_connect_t conn, SMCParamStruct *input, SMCParamStruct *output) {
    size_t outSize = sizeof(SMCParamStruct);
    kern_return_t result = IOConnectCallStructMethod(
        conn, kSMCHandleYPCEvent, input, sizeof(SMCParamStruct), output, &outSize);
    if (result != KERN_SUCCESS) return result;
    if (output->result != 0) return KERN_FAILURE;
    return KERN_SUCCESS;
}

kern_return_t csmc_open(io_connect_t *conn) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (service == IO_OBJECT_NULL) return KERN_FAILURE;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, conn);
    IOObjectRelease(service);
    return result;
}

void csmc_close(io_connect_t conn) {
    if (conn != IO_OBJECT_NULL) IOServiceClose(conn);
}

kern_return_t csmc_key_info(io_connect_t conn, uint32_t key, SMCKeyInfoData *out) {
    SMCParamStruct input, output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = key;
    input.data8 = kSMCGetKeyInfo;
    kern_return_t result = csmc_call(conn, &input, &output);
    if (result == KERN_SUCCESS) *out = output.keyInfo;
    return result;
}

kern_return_t csmc_read(io_connect_t conn, uint32_t key, SMCKeyInfoData info, uint8_t out[32]) {
    SMCParamStruct input, output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = key;
    input.keyInfo.dataSize = info.dataSize;
    input.data8 = kSMCReadKey;
    kern_return_t result = csmc_call(conn, &input, &output);
    if (result == KERN_SUCCESS) memcpy(out, output.bytes, 32);
    return result;
}

kern_return_t csmc_key_at_index(io_connect_t conn, uint32_t index, uint32_t *key) {
    SMCParamStruct input, output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.data8 = kSMCGetKeyFromIndex;
    input.data32 = index;
    kern_return_t result = csmc_call(conn, &input, &output);
    if (result == KERN_SUCCESS) *key = output.key;
    return result;
}
