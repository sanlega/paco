/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   get_next_line.c                                    :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "get_next_line.h"

static char	*free_null(char **p)
{
	free(*p);
	*p = NULL;
	return (NULL);
}

static char	*read_until_nl(int fd, char *stash)
{
	char	*buf;
	ssize_t	n;

	buf = malloc((size_t)BUFFER_SIZE + 1);
	if (!buf)
		return (free_null(&stash));
	n = 1;
	while (!gnl_strchr(stash, '\n') && n > 0)
	{
		n = read(fd, buf, BUFFER_SIZE);
		if (n < 0)
		{
			free(buf);
			return (free_null(&stash));
		}
		if (n > 0)
			stash = gnl_join(stash, buf, n);
		if (!stash)
			break ;
	}
	free(buf);
	return (stash);
}

static char	*extract_line(char **stash)
{
	char	*line;
	char	*rest;
	size_t	len;

	len = 0;
	while ((*stash)[len] && (*stash)[len] != '\n')
		len++;
	if ((*stash)[len] == '\n')
		len++;
	line = gnl_substr(*stash, 0, len);
	rest = NULL;
	if (line && (*stash)[len])
	{
		rest = gnl_substr(*stash, len, gnl_strlen(*stash + len));
		if (!rest)
			free_null(&line);
	}
	free(*stash);
	*stash = rest;
	return (line);
}

char	*get_next_line(int fd)
{
	static char	*stash[MAX_FD];

	if (fd < 0 || fd >= MAX_FD || BUFFER_SIZE <= 0)
		return (NULL);
	stash[fd] = read_until_nl(fd, stash[fd]);
	if (!stash[fd] || !stash[fd][0])
		return (free_null(&stash[fd]));
	return (extract_line(&stash[fd]));
}
