#include "memory.h"
#include "simpledir.h"
#include "cartridge.h"
#include "log.h"

struct CartDef {
	unsigned char carttype;	// type from CAR header
	unsigned char mode;		// mode used in cartridge emulation
	unsigned short size;		// size in k
};

// 8k modes (0xA000-$BFFF)
#define TC_MODE_OFF             0x00           // cart disabled
#define TC_MODE_8K              0x01           // 8k banks at $A000
#define TC_MODE_ATARIMAX1       0x02           // 8k using Atarimax 1MBit compatible banking
#define TC_MODE_ATARIMAX8       0x03           // 8k using Atarimax 8MBit compatible banking
#define TC_MODE_OSS             0x04           // 16k OSS cart, M091 banking

#define TC_MODE_SDX64           0x08           // SDX 64k cart, $D5Ex banking
#define TC_MODE_DIAMOND64       0x09           // Diamond GOS 64k cart, $D5Dx banking
#define TC_MODE_EXPRESS64       0x0A           // Express 64k cart, $D57x banking

#define TC_MODE_ATRAX128        0x0C           // Atrax 128k cart
#define TC_MODE_WILLIAMS64      0x0D           // Williams 64k cart

// 16k modes (0x8000-$BFFF)
//#define TC_MODE_FLEXI           0x20           // flexi mode
#define TC_MODE_16K             0x21           // 16k banks at $8000-$BFFF
#define TC_MODE_MEGAMAX16       0x22           // MegaMax 16k mode (up to 2MB)
#define TC_MODE_BLIZZARD        0x23           // Blizzard 16k
#define TC_MODE_SIC             0x24           // Sic!Cart 512k

#define TC_MODE_MEGA_16         0x28           // switchable MegaCarts
#define TC_MODE_MEGA_32         0x29
#define TC_MODE_MEGA_64         0x2A
#define TC_MODE_MEGA_128        0x2B
#define TC_MODE_MEGA_256        0x2C
#define TC_MODE_MEGA_512        0x2D
#define TC_MODE_MEGA_1024       0x2E
#define TC_MODE_MEGA_2048       0x2F

#define TC_MODE_XEGS_32         0x30           // non-switchable XEGS carts
#define TC_MODE_XEGS_64         0x31
#define TC_MODE_XEGS_128        0x32
#define TC_MODE_XEGS_256        0x33
#define TC_MODE_XEGS_512        0x34
#define TC_MODE_XEGS_1024       0x35

#define TC_MODE_SXEGS_32        0x38           // switchable XEGS carts
#define TC_MODE_SXEGS_64        0x39
#define TC_MODE_SXEGS_128       0x3A
#define TC_MODE_SXEGS_256       0x3B
#define TC_MODE_SXEGS_512       0x3C
#define TC_MODE_SXEGS_1024      0x3D

static struct CartDef cartdef[] = {
        { 1, TC_MODE_8K, 8 },
        { 2, TC_MODE_16K, 16 },
        { 8, TC_MODE_WILLIAMS64, 64 },
        { 9, TC_MODE_EXPRESS64, 64 },
        { 10, TC_MODE_DIAMOND64, 64 },
        { 11, TC_MODE_SDX64, 64 },
        { 12, TC_MODE_XEGS_32, 32 },
        { 13, TC_MODE_XEGS_64, 64 },
        { 14, TC_MODE_XEGS_128, 128 },
        { 15, TC_MODE_OSS, 16 },
        { 17, TC_MODE_ATRAX128, 128 },
        { 23, TC_MODE_XEGS_256, 256 },
        { 24, TC_MODE_XEGS_512, 512 },
        { 26, TC_MODE_MEGA_16, 16 },
        { 27, TC_MODE_MEGA_32, 32 },
        { 28, TC_MODE_MEGA_64, 64 },
        { 29, TC_MODE_MEGA_128, 128 },
        { 30, TC_MODE_MEGA_256, 256 },
        { 31, TC_MODE_MEGA_512, 512 },
        { 33, TC_MODE_SXEGS_32, 32 },
        { 34, TC_MODE_SXEGS_64, 64 },
        { 35, TC_MODE_SXEGS_128, 128 },
        { 36, TC_MODE_SXEGS_256, 256 },
        { 37, TC_MODE_SXEGS_512, 512 },
        { 40, TC_MODE_BLIZZARD, 16 },
        { 41, TC_MODE_ATARIMAX1, 128 },
        { 42, TC_MODE_ATARIMAX8, 1024 },
        { 56, TC_MODE_SIC, 512 },
	{ 0, 0, 0 }
};

int load_car(struct SimpleFile* file)
{
	if (CARTRIDGE_MEM == 0) {
		LOG("no cartridge memory\n");
		return 0;
	}
	int len;
	enum SimpleFileStatus ok;
	unsigned char header[16];
	ok = file_read(file, header, 16, &len);
	if (ok != SimpleFile_OK || len != 16) {
		LOG("cannot read cart header\n");
		return 0;
	}
	unsigned char carttype = header[7];

	// search for cartridge definition
	struct CartDef* def = cartdef;
	while (def->carttype && def->carttype != carttype) {
		def++;
	}
	if (def->carttype == 0) {
		LOG("illegal cart type %d\n", carttype);
		return 0;
	}
	unsigned int byte_len = (unsigned int) def->size << 10;
	ok = file_read(file, CARTRIDGE_MEM, byte_len, &len);
	if (ok != SimpleFile_OK || len != byte_len) {
		LOG("cannot read cart data\n");
		return 0;
	}
	LOG("cart type: %d size: %dk\n",
		 def->mode, def->size);
	return def->mode;
}
