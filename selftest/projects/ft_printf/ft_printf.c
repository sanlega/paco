/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   ft_printf.c                                        :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "ft_printf.h"

static int	put_int(long n)
{
	int	sign;
	int	res;

	sign = 0;
	if (n < 0)
	{
		sign = pf_putchar('-');
		if (sign < 0)
			return (-1);
		n = -n;
	}
	res = pf_putnbr_base((unsigned long)n, "0123456789");
	if (res < 0)
		return (-1);
	return (sign + res);
}

static int	convert(char c, va_list *ap)
{
	if (c == 'c')
		return (pf_putchar((char)va_arg(*ap, int)));
	if (c == 's')
		return (pf_putstr(va_arg(*ap, char *)));
	if (c == 'p')
		return (pf_putptr(va_arg(*ap, void *)));
	if (c == 'd' || c == 'i')
		return (put_int(va_arg(*ap, int)));
	if (c == 'u')
		return (pf_putnbr_base(va_arg(*ap, unsigned int), "0123456789"));
	if (c == 'x')
		return (pf_putnbr_base(va_arg(*ap, unsigned int), "0123456789abcdef"));
	if (c == 'X')
		return (pf_putnbr_base(va_arg(*ap, unsigned int), "0123456789ABCDEF"));
	if (c == '%')
		return (pf_putchar('%'));
	return (0);
}

int	ft_printf(const char *format, ...)
{
	va_list	ap;
	int		total;
	int		n;

	if (!format)
		return (-1);
	va_start(ap, format);
	total = 0;
	n = 0;
	while (*format && n >= 0)
	{
		if (*format == '%' && format[1])
			n = convert(*(++format), &ap);
		else if (*format != '%')
			n = pf_putchar(*format);
		total += n;
		format++;
	}
	va_end(ap);
	if (n < 0)
		return (-1);
	return (total);
}
