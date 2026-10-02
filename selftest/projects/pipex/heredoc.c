/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   heredoc.c                                          :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

static char	*read_line(void)
{
	char	buf[4096];
	size_t	n;
	ssize_t	r;

	n = 0;
	while (n < sizeof(buf) - 1)
	{
		r = read(0, buf + n, 1);
		if (r <= 0)
		{
			if (n == 0)
				return (NULL);
			break ;
		}
		if (buf[n++] == '\n')
			break ;
	}
	return (px_strndup(buf, n));
}

static int	is_limiter(const char *line, const char *limiter)
{
	size_t	len;

	len = px_strlen(limiter);
	if (strncmp(line, limiter, len) != 0)
		return (0);
	return (line[len] == '\n' || line[len] == '\0');
}

int	read_heredoc(const char *limiter)
{
	int		fds[2];
	char	*line;

	if (pipe(fds) < 0)
		return (-1);
	while (1)
	{
		line = read_line();
		if (!line || is_limiter(line, limiter))
			break ;
		write(fds[1], line, px_strlen(line));
		free(line);
	}
	free(line);
	close(fds[1]);
	return (fds[0]);
}
