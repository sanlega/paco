/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   main.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

static int	usage(void)
{
	write(2, "usage: ./pipex infile cmd1 ... cmdn outfile\n", 44);
	write(2, "       ./pipex here_doc LIMITER cmd1 ... cmdn outfile\n", 53);
	return (1);
}

static int	wait_all(pid_t last)
{
	int		status;
	int		res;
	pid_t	pid;

	res = 0;
	pid = wait(&status);
	while (pid > 0)
	{
		if (pid == last)
		{
			if (WIFEXITED(status))
				res = WEXITSTATUS(status);
			else if (WIFSIGNALED(status))
				res = 128 + WTERMSIG(status);
		}
		pid = wait(&status);
	}
	return (res);
}

static int	open_in(t_px *px)
{
	int	fd;

	if (px->limiter)
		return (read_heredoc(px->limiter));
	fd = open(px->infile, O_RDONLY);
	if (fd < 0)
		px_error(px->infile, strerror(errno));
	return (fd);
}

int	main(int argc, char **argv, char **envp)
{
	t_px	px;
	int		first;

	first = 2;
	px.limiter = NULL;
	if (argc > 1 && !strcmp(argv[1], "here_doc"))
	{
		px.limiter = argv[2];
		first = 3;
	}
	if (argc < first + 3)
		return (usage());
	px.envp = envp;
	px.infile = argv[1];
	px.outfile = argv[argc - 1];
	px.cmds = argv + first;
	px.n_cmds = argc - first - 1;
	px.last_pid = -1;
	run_pipeline(&px, open_in(&px));
	return (wait_all(px.last_pid));
}
