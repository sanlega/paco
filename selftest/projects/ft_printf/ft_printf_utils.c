/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   ft_printf_utils.c                                  :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "ft_printf.h"

int	pf_putchar(char c)
{
	return (write(1, &c, 1));
}

int	pf_putstr(const char *s)
{
	int	len;

	if (!s)
		s = "(null)";
	len = 0;
	while (s[len])
		len++;
	return (write(1, s, len));
}

int	pf_putnbr_base(unsigned long n, const char *base)
{
	char			buf[32];
	int				i;
	unsigned long	b;

	b = 0;
	while (base[b])
		b++;
	i = 32;
	buf[--i] = base[n % b];
	n /= b;
	while (n)
	{
		buf[--i] = base[n % b];
		n /= b;
	}
	return (write(1, buf + i, 32 - i));
}

int	pf_putptr(void *p)
{
	int	a;
	int	b;

	if (!p)
		return (pf_putstr("(nil)"));
	a = pf_putstr("0x");
	if (a < 0)
		return (-1);
	b = pf_putnbr_base((unsigned long)p, "0123456789abcdef");
	if (b < 0)
		return (-1);
	return (a + b);
}
