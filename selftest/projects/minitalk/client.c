/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   client.c                                           :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "minitalk.h"

static volatile sig_atomic_t	g_ack;

static void	on_ack(int sig)
{
	if (sig == SIGUSR2)
		g_ack = 2;
	else
		g_ack = 1;
}

static int	parse_pid(const char *s, pid_t *pid)
{
	long	n;

	n = 0;
	if (!*s)
		return (0);
	while (*s >= '0' && *s <= '9' && n < 4194304)
		n = n * 10 + (*s++ - '0');
	if (*s || n <= 0 || n >= 4194304)
		return (0);
	*pid = (pid_t)n;
	return (1);
}

static int	send_byte(pid_t pid, unsigned char c)
{
	int		bit;
	long	waited;

	bit = 8;
	while (bit--)
	{
		g_ack = 0;
		if (kill(pid, SIGUSR1 + (SIGUSR2 - SIGUSR1) * ((c >> bit) & 1)))
			return (0);
		waited = 0;
		while (!g_ack)
		{
			usleep(20);
			waited += 20;
			if (waited > 5000000)
				return (0);
		}
	}
	return (1);
}

int	main(int argc, char **argv)
{
	pid_t	pid;
	char	*s;

	if (argc != 3 || !parse_pid(argv[1], &pid))
	{
		write(2, "usage: ./client <server pid> <message>\n", 39);
		return (1);
	}
	signal(SIGUSR1, on_ack);
	signal(SIGUSR2, on_ack);
	s = argv[2];
	while (1)
	{
		if (!send_byte(pid, (unsigned char)*s))
		{
			write(2, "client: the server is not answering\n", 36);
			return (1);
		}
		if (!*s++)
			break ;
	}
	if (g_ack == 2)
		write(1, "Message received by the server\n", 31);
	return (0);
}
