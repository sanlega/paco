/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   exec.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

static void	exec_cmd(t_px *px, int i)
{
	char	**args;
	char	*path;
	int		status;

	args = parse_args(px->cmds[i]);
	if (!args)
		exit(1);
	status = 127;
	path = find_command(args[0], px->envp, &status);
	if (path)
	{
		execve(path, args, px->envp);
		px_error(args[0], strerror(errno));
		status = 126;
		free(path);
	}
	free_tab(args);
	exit(status);
}

static int	open_out(t_px *px)
{
	int	fd;

	if (px->limiter)
		fd = open(px->outfile, O_WRONLY | O_CREAT | O_APPEND, 0644);
	else
		fd = open(px->outfile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (fd < 0)
		px_error(px->outfile, strerror(errno));
	return (fd);
}

static void	child(t_px *px, int i, int in_fd, int *pipefd)
{
	int	out_fd;

	if (i == px->n_cmds - 1)
	{
		close(pipefd[0]);
		close(pipefd[1]);
		out_fd = open_out(px);
	}
	else
	{
		close(pipefd[0]);
		out_fd = pipefd[1];
	}
	if (in_fd < 0 || out_fd < 0)
		exit(1);
	dup2(in_fd, 0);
	dup2(out_fd, 1);
	close(in_fd);
	close(out_fd);
	exec_cmd(px, i);
}

void	run_pipeline(t_px *px, int in_fd)
{
	int		i;
	int		pipefd[2];
	pid_t	pid;

	i = 0;
	while (i < px->n_cmds)
	{
		if (pipe(pipefd) < 0)
			exit(1);
		pid = fork();
		if (pid < 0)
			exit(1);
		if (pid == 0)
			child(px, i, in_fd, pipefd);
		if (in_fd >= 0)
			close(in_fd);
		close(pipefd[1]);
		in_fd = pipefd[0];
		px->last_pid = pid;
		i++;
	}
	close(in_fd);
}
