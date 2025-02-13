#!/usr/bin/python3

f = open("xex_loader.o65", "rb")
loader_bin = f.read()
f.close()

loader = loader_bin[:-13]
header = loader_bin[-13:]

s = f"#define CAR_XEX_LOADER_SIZE {len(loader)}\n\n"
s += "unsigned char car_xex_loader[CAR_XEX_LOADER_SIZE] =\n{\n\t"

i = 0
for b in loader:
	s += f"0x{b:02X},"
	i += 1
	if i == len(loader):
		s = s[:-1]
	if i % 16 == 0:
		s += "\n\t"

if i % 16 != 0:
	s += "\n"
else:
	s = s[:-1]

s += f"}};\n\n#define CAR_XEX_HEADER_SIZE {len(header)}\n\n"
s += "unsigned char car_xex_header[CAR_XEX_HEADER_SIZE] =\n{\n\t"
i = 0
for b in header:
	s += f"0x{b:02X},"
	i += 1
	if i == len(header):
		s = s[:-1]
	if i % 16 == 0:
		s += "\n\t"

if i % 16 != 0:
	s += "\n"
else:
	s = s[:-1]

s += "};\n\n"

f = open("xex_loader.lab", "rt")
l = f.read().split("\n")
f.close()

r = []

for ll in l:
	if ll[:5] == "reloc":
		r.append(ll[13:15])
	elif ll[:11] == "read_status":
		rs = ll[17:19]
	elif ll[:5] == "magic":
		mg = ll[11:13]

s += f"#define XEX_RELOC_OFFSETS_SIZE {18}\n\n"
s += "unsigned char xex_reloc_offsets[XEX_RELOC_OFFSETS_SIZE] =\n{\n\t"

for re in r:
	s += "0x"+re+","

s = s[:-1]+"\n};\n\n"

s += f"#define XEX_READ_STATUS 0x{rs}\n#define XEX_MAGIC 0x{mg}\n\n"

f = open("xex_loader.h", "wt")
f.write(s)
f.close()
