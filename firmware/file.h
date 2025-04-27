#pragma once

struct SimpleFile
{
	int num;
	int offset;
	int is_readonly;
	int size;
	int type;
};

enum SimpleFileStatus {SimpleFile_OK, SimpleFile_FAIL};

void file_init(struct SimpleFile * file, int i);
enum SimpleFileStatus file_read(struct SimpleFile * file, unsigned char* buffer, int bytes, int * bytesread);
enum SimpleFileStatus file_seek(struct SimpleFile * file, int offsetFromStart);
enum SimpleFileStatus file_write(struct SimpleFile * file, unsigned char* buffer, int bytes, int * byteswritten);
// enum SimpleFileStatus file_write_flush(); 

void file_reset();
