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
int file_size(struct SimpleFile * file);
int file_readonly(struct SimpleFile * file);

enum SimpleFileStatus file_write(struct SimpleFile * file, unsigned char* buffer, int bytes, int * byteswritten);
enum SimpleFileStatus file_write_flush(); 

int file_type(struct SimpleFile * file);

void file_reset();
