#include "integer.h"
#include "regs.h"
#include "file.h"

void file_init(struct SimpleFile * file, int i)
{
	file->num = i;
	file->size = 0;
	file->type = 0;
	file->is_readonly = 1;
	file->offset = -1;
}

DWORD cur_offset;
int cur_file;
BYTE sect_buffer[512];

BYTE cache_read(DWORD offset, int file)
{
	if(((offset & ~0x1FF) != (cur_offset & ~0x1FF)) || (cur_file != file))
	{
		int i;

		set_sd_data_mode_on();
		*zpu_out3 = offset >> 9;

		set_sd_num(file);
		set_sd_read_off();
		set_sd_read_on();
		while(!get_sd_done()) {};
		set_sd_read_off();

		set_sd_data_mode_off();
		for(i=0; i<512; i++) sect_buffer[i] = *zpu_in3;

		cur_offset = offset;
		cur_file = file;
	}
	return sect_buffer[offset & 0x1FF];
}

void cache_write()
{
	int i;

	set_sd_data_mode_off();
	for(i=0; i<512; i++) *zpu_out3 = sect_buffer[i];

	set_sd_data_mode_on();
	*zpu_out3 = cur_offset >> 9;

	set_sd_num(cur_file);
	set_sd_write_off();
	set_sd_write_on();
	while(!get_sd_done()) {};
	set_sd_write_off();
}

void file_reset()
{
	cur_file = -1;
	cur_offset = -1;
}

enum SimpleFileStatus file_read(struct SimpleFile *file, unsigned char *buffer, int bytes, int *bytesread)
{
	if((file->offset >= 0) && (file->size > file->offset) && (bytes > 0))
	{
		if((file->offset + bytes) > file->size) bytes = file->size - file->offset;
		*bytesread = bytes;

		while(bytes--) *buffer++ = cache_read(file->offset++, file->num); 
		return SimpleFile_OK;
	}

	*bytesread = 0;
	return SimpleFile_FAIL;
}

enum SimpleFileStatus file_seek(struct SimpleFile * file, unsigned int offsetFromStart)
{
	if((file->size > 0) && (file->size >= offsetFromStart))
	{
		file->offset = offsetFromStart;
		return SimpleFile_OK;
	}
	return SimpleFile_FAIL;
}

enum SimpleFileStatus file_write(struct SimpleFile *file, unsigned char *buffer, int bytes, int *byteswritten)
{
	if((file->offset >= 0) && (file->size > file->offset) && (bytes > 0))
	{
		if((file->offset + bytes) > file->size) bytes = file->size - file->offset;
		*byteswritten = bytes;

		while(bytes>0)
		{
			cache_read(file->offset, file->num);
			do
			{
				sect_buffer[file->offset & 0x1FF] = *buffer;
				bytes--;
				file->offset++;
				buffer++;
			}
			while((file->offset & 0x1FF) && (bytes>0));
			cache_write();
		}
		return SimpleFile_OK;
	}	
	
	return SimpleFile_FAIL;
}

//enum SimpleFileStatus file_write_flush()
//{
//	return SimpleFile_FAIL;
//}
