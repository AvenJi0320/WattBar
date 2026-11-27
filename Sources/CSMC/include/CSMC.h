#pragma once
#include <stdint.h>
#include <IOKit/IOKitLib.h>

typedef struct { uint8_t major, minor, build, reserved; uint16_t release; } SMCVersion;
typedef struct { uint16_t version, length; uint32_t cpuPLimit, gpuPLimit, memPLimit; } SMCPLimitData;
typedef struct { uint32_t dataSize; uint32_t dataType; uint8_t dataAttributes; } SMCKeyInfoData;
typedef struct {
    uint32_t key; SMCVersion vers; SMCPLimitData pLimitData; SMCKeyInfoData keyInfo;
    uint8_t result, status, data8; uint32_t data32; uint8_t bytes[32];
} SMCParamStruct;
_Static_assert(sizeof(SMCParamStruct) == 80, "SMCParamStruct must be 80 bytes");

enum { kSMCHandleYPCEvent = 2, kSMCReadKey = 5, kSMCGetKeyFromIndex = 8, kSMCGetKeyInfo = 9 };

kern_return_t csmc_open(io_connect_t *conn);
void          csmc_close(io_connect_t conn);
kern_return_t csmc_key_info(io_connect_t conn, uint32_t key, SMCKeyInfoData *out);
kern_return_t csmc_read(io_connect_t conn, uint32_t key, SMCKeyInfoData info, uint8_t out[32]);
kern_return_t csmc_key_at_index(io_connect_t conn, uint32_t index, uint32_t *key);
