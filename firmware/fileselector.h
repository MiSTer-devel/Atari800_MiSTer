#pragma once

int file_selector(struct SimpleFile * file);

int filter_disks_and_carts(struct SimpleDirEntry * entry);
int filter_disks(struct SimpleDirEntry * entry);
extern char const * fil_type;
extern char const * fil_type_rom;
extern char const * fil_type_bin;
extern char const * fil_type_car;
extern char const * fil_type_mem;
int filter_specified(struct SimpleDirEntry * entry);

extern int (* filter)(struct SimpleDirEntry * entry);

