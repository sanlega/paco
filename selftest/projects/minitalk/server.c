/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   server.c                                           :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "minitalk.h"

static void	put_pid(pid_t pid)
{
	char	buf[16];
	int		i;

	i = 15;
	buf[i] = '\n';
	while (pid >= 10)
	{
		buf[--i] = '0' + pid % 10;
		pid /= 10;
	}
	buf[--i] = '0' + pid;
	write(1, buf + i, 16 - i);
}

static void	reset(unsigned char *c, int *bits)
{
	*c = 0;
	*bits = 0;
}

static void	handler(int sig, siginfo_t *info, void *ctx)
{
	static unsigned char	c;
	static int				bits;
	static pid_t			client;

	(void)ctx;
	if (info->si_pid && info->si_pid != client)
	{
		client = info->si_pid;
		reset(&c, &bits);
	}
	c = (c << 1) | (sig == SIGUSR2);
	if (++bits == 8)
	{
		if (!c && client)
			kill(client, SIGUSR2);
		if (!c)
			return (reset(&c, &bits));
		write(1, &c, 1);
		reset(&c, &bits);
	}
	if (client)
		kill(client, SIGUSR1);
}

int	main(void)
{
	struct sigaction	sa;

	sa.sa_sigaction = handler;
	sa.sa_flags = SA_SIGINFO | SA_RESTART;
	sigemptyset(&sa.sa_mask);
	sigaddset(&sa.sa_mask, SIGUSR1);
	sigaddset(&sa.sa_mask, SIGUSR2);
	sigaction(SIGUSR1, &sa, NULL);
	sigaction(SIGUSR2, &sa, NULL);
	put_pid(getpid());
	while (1)
		pause();
	return (0);
}
