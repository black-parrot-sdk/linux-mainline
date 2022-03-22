OUTPUT_ARCH(riscv)
ENTRY(_start)

PHDRS
{
	code PT_LOAD AT(0x80000000);
	flash PT_LOAD AT(0x84000000);
}

SECTIONS
{
	. = 0x80000000;
	.code :
	{
		_start = .;
		work/fw_payload.o(*)
	} : code

	. = 0x84000000;
	.flash :
	{
		_flash_start = .;
		work/flash.o(*)

		/* This makes sure Dromajo backs the entire flash region, and also protects us against accidentally using too large of a flash image. */
		. = _flash_start + 0x08000000;
	} : flash
}
