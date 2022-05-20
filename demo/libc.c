/* demo kernel: verify basic functions of a multiboot compliant boot loader.
 * (c) 2022, gerd dauenhauer
 * SPDX 0BSD, see the enclosed LICENSE file
 *
 * this file provides a simple c library implementation.
 * the code is kept to the bare minimum, just to get the main() function run. */

#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define XSTR(s) STR(s)
#define STR(s) #s

#define ZERO_PAD_FLAG 1UL
#define LONG_TYPE_FLAG 2UL

static char *screen = (char *)0x000b8000;

extern void cursor_get_position(unsigned *row, unsigned *column);
extern void cursor_set_position(unsigned row, unsigned column);

static unsigned long long udivmoddi(
	unsigned long long dividend, unsigned long long divisor,
	unsigned long long *rest)
{
	size_t i;
	unsigned long long pwr2;

	// handle exact powers of two.
	for (i = 1; i < 63; ++i) {
		pwr2 = 1ULL << i;

		if (pwr2 >= divisor)
			break;
	}

	if (pwr2 == divisor) {
		if (rest)
			*rest = dividend & (pwr2 - 1);
		return dividend >> i;
	}

	// sorry, we are unable (unwilling) to compute...
	return 0ULL;
}

unsigned long long __udivdi3(
	unsigned long long dividend, unsigned long long divisor)
{
	if (dividend < divisor)
		return 0ULL;

	if (dividend <= UINT32_MAX &&
	    dividend <= UINT32_MAX)
		return (unsigned long)dividend / (unsigned long)divisor;

	return udivmoddi(dividend, divisor, NULL);
}

unsigned long long __umoddi3(
	unsigned long long dividend, unsigned long long divisor)
{
	unsigned long long rst = 0;

	if (dividend < divisor)
		return dividend;

	if (dividend <= UINT32_MAX &&
	    divisor <= UINT32_MAX)
		return (unsigned long)dividend % (unsigned long)divisor;

	(void)udivmoddi(dividend, divisor, &rst);
	return rst;
}

static char *strrev(char string[])
{
	size_t len;
	size_t i;

	len = strlen(string);
	for (i = 0; i < len / 2; ++i) {
		char c = string[i];

		string[i] = string[len - 1 - i];
		string[len - 1 - i] = c;
	}

	return string;
}

// inverse to the strtoull() function from libc.h
static char *ulltostr(unsigned long long number, char buffer[], unsigned radix)
{
	size_t i = 0;
	char *ret = NULL;

	if (radix < 2 ||
	    radix > 16)
		goto ERROR;

	for (;;) {
		unsigned long long c;

		c = number % radix;
		if (c < 10ULL)
			c = c + '0';
		else
			c = c - 10 + 'a';

		buffer[i] = (char)c;
		++i;

		number /= radix;
		if (number == 0ULL)
			break;
	}

	buffer[i] = '\0';
	strrev(buffer);

	ret = buffer;

ERROR:
	return ret;
}

// inverse to the strtoul() function from libc.h
static char *ultostr(unsigned long number, char buffer[], unsigned radix)
{
	return ulltostr((unsigned long long)number, buffer, radix);
}

size_t strlen(const char *string)
{
	size_t i;

	for (i = 0; string[i] != '\0'; ++i);

	return i;
}

void *memcpy(void *destination, const void *source, size_t count)
{
	size_t i;

	for (i = 0; i < count; ++i)
		((char *)destination)[i] = ((const char *)source)[i];

	return destination;
}

static void screen_scroll_up(unsigned *row)
{
	size_t i;

	memcpy(screen, screen + 80 * 2, 80 * 2 * 24);

	for (i = 0; i < 80; ++i) {
		screen[(24 * 80 + i) * 2 + 0] = ' ';
		screen[(24 * 80 + i) * 2 + 1] = 0x0e;
	}

	*row = 24;
}

static void screen_put_character(unsigned *row, unsigned *column, char character)
{
	unsigned row_ = *row;
	unsigned col = *column;

	if (character == '\n') {
		col = 0;
		++row_;
	} else if (character == '\t') {
		col += 4;
		if (col > 80) {
			col -= 80;
			++row_;
		}
	} else if (character >= ' ') {
		screen[(row_ * 80 + col) * 2 + 0] = character;
		screen[(row_ * 80 + col) * 2 + 1] = 0x0e;

		++col;
		if (col == 80) {
			col = 0;
			++row_;
		}
	}

	if (row_ > 24)
		screen_scroll_up(&row_);

	*row = row_;
	*column = col;
}

int putchar(int character)
{
	unsigned row = 0;
	unsigned col = 0;

	cursor_get_position(&row, &col);

	screen_put_character(&row, &col, (char)character);

	cursor_set_position(row, col);

	return 0;
}

int puts(const char *string)
{
	unsigned row = 0;
	unsigned col = 0;
	size_t len;
	size_t i;

	cursor_get_position(&row, &col);

	len = strlen(string);

	for (i = 0; i < len; ++i)
		screen_put_character(&row, &col, string[i]);

	cursor_set_position(row, col);

	return 0;
}

int printf(const char *format, ...)
{
	size_t i = 0;
	va_list va;

	va_start(va, format);

	for (;;) {
		char c;
		unsigned flgs = 0UL;
		size_t wdt = 0;
		char nbuf[sizeof XSTR(UINT64_MAX)];
		size_t nlen = 0;

		c = format[i];
		if (c == '\0')
			break;

		if (c != '%') {
			putchar(c);

			++i;
			continue;
		}

		++i;
		c = format[i];
		if (c == '\0')
			break;

		if (c == '%') {
			putchar(c);

			++i;
			continue;
		}

		// handle optional zero-padding modifier.
		if (c == '0') {
			flgs |= ZERO_PAD_FLAG;

			++i;
			c = format[i];
			if (c == '\0')
				break;
		}

		// handle optional (minimum) width specification.
		if (c >= '1' &&
		    c <= '9') {
			wdt = c - '0';

			++i;
			c = format[i];
			if (c == '\0')
				break;

			if (c >= '0' &&
			    c <= '9') {
				wdt *= 10;
				wdt += c - '0';

				++i;
				c = format[i];
				if (c == '\0')
					break;
			}
		}

		// handle optional long type modifier.
		if (c == 'l') {
			flgs |= LONG_TYPE_FLAG;

			++i;
			c = format[i];
			if (c == '\0')
				break;
		}

		++i;

		// consume the appropriate argument.
		switch(c) {
		case 's': {
			const char *s = va_arg(va, char *);

			puts(s);
		}
			break;
		case 'u': {
			if (flgs & LONG_TYPE_FLAG) {
				unsigned long long n =
					va_arg(va, unsigned long long);

				ulltostr(n, nbuf, 10);
			} else {
				unsigned long n = va_arg(va, unsigned long);

				ultostr(n, nbuf, 10);
			}
		}
			goto NUMBER;
		case 'x': {
			if (flgs & LONG_TYPE_FLAG) {
				unsigned long long n =
					va_arg(va, unsigned long long);

				ulltostr(n, nbuf, 16);
			} else {
				unsigned long n = va_arg(va, unsigned long);

				ultostr(n, nbuf, 16);
			}
		}
			goto NUMBER;
		default:
			break;
		}

		continue;

	NUMBER:
		nlen = strlen(nbuf);

		if (wdt > nlen) {
			size_t pdl = wdt - nlen;
			size_t j;

			for (j = 0; j < pdl; ++j)
				putchar((flgs & ZERO_PAD_FLAG) ? '0' : ' ');
		}

		puts(nbuf);
	}

	va_end(va);

	return 0;
}
