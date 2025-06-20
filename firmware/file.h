#pragma once

#define get_sd_done() (*zpu_in2 & 0x00000100)
#define set_sd_data_mode_on() *zpu_out2 |= 0x00000001
#define set_sd_data_mode_off() *zpu_out2 &= 0xFFFFFFFE
#define set_sd_read_on() *zpu_out2 |= 0x00000002
#define set_sd_read_off() *zpu_out2 &= 0xFFFFFFFD
#define set_sd_write_on() *zpu_out2 |= 0x00000004
#define set_sd_write_off() *zpu_out2 &= 0xFFFFFFFB
#define set_sd_num(n) *zpu_out2 = (*zpu_out2 & 0xFFFFFFC7) | (n << 3)

struct SimpleFile
{
	int num;
	unsigned int offset;
	int is_readonly;
	unsigned int size;
	int type;
};

enum SimpleFileStatus {SimpleFile_OK, SimpleFile_FAIL};

void file_init(struct SimpleFile * file, int i);
enum SimpleFileStatus file_read(struct SimpleFile * file, unsigned char* buffer, int bytes, int * bytesread);
enum SimpleFileStatus file_seek(struct SimpleFile * file, unsigned int offsetFromStart);
enum SimpleFileStatus file_write(struct SimpleFile * file, unsigned char* buffer, int bytes, int * byteswritten);
// enum SimpleFileStatus file_write_flush(); 

void file_reset();
