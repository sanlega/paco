/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   path.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

static char	*get_path(char **envp)
{
	size_t	i;

	i = 0;
	while (envp && envp[i])
	{
		if (!strncmp(envp[i], "PATH=", 5))
			return (envp[i] + 5);
		i++;
	}
	return (DEFAULT_PATH);
}

static char	*direct(char *name, int *status)
{
	if (access(name, F_OK) != 0)
	{
		px_error(name, strerror(errno));
		*status = 127;
		return (NULL);
	}
	if (access(name, X_OK) != 0)
	{
		px_error(name, strerror(errno));
		*status = 126;
		return (NULL);
	}
	return (px_strndup(name, px_strlen(name)));
}

static char	*not_found(char *name, int *status, int denied, int empty)
{
	if (denied)
	{
		px_error(name, "Permission denied");
		*status = 126;
	}
	else
	{
		if (empty)
			px_error(name, "No such file or directory");
		else
			px_error(name, "command not found");
		*status = 127;
	}
	return (NULL);
}

static char	*try_dir(const char *dir, size_t len, char *name, int *denied)
{
	char	*d;
	char	*full;

	d = px_strndup(dir, len);
	if (!d)
		return (NULL);
	if (len == 0 || d[len - 1] == '/')
		full = px_join3(d, "", name);
	else
		full = px_join3(d, "/", name);
	free(d);
	if (full && access(full, F_OK) == 0)
	{
		if (access(full, X_OK) == 0)
			return (full);
		*denied = 1;
	}
	free(full);
	return (NULL);
}

char	*find_command(char *name, char **envp, int *status)
{
	char	*path;
	char	*end;
	char	*full;
	int		denied;

	if (!name || !*name)
		return (not_found("", status, 0, 0));
	if (strchr(name, '/'))
		return (direct(name, status));
	path = get_path(envp);
	denied = 0;
	while (*path)
	{
		end = strchr(path, ':');
		if (!end)
			end = path + px_strlen(path);
		full = try_dir(path, end - path, name, &denied);
		if (full)
			return (full);
		path = end + (*end == ':');
	}
	return (not_found(name, status, denied, *get_path(envp) == '\0'));
}
