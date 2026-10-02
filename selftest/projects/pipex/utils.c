/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   utils.c                                            :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

size_t	px_strlen(const char *s)
{
	size_t	i;

	i = 0;
	while (s && s[i])
		i++;
	return (i);
}

char	*px_strndup(const char *s, size_t n)
{
	char	*d;
	size_t	i;

	d = malloc(n + 1);
	if (!d)
		return (NULL);
	i = 0;
	while (i < n)
	{
		d[i] = s[i];
		i++;
	}
	d[n] = '\0';
	return (d);
}

char	*px_join3(const char *a, const char *b, const char *c)
{
	size_t	la;
	size_t	lb;
	size_t	lc;
	char	*res;

	la = px_strlen(a);
	lb = px_strlen(b);
	lc = px_strlen(c);
	res = malloc(la + lb + lc + 1);
	if (!res)
		return (NULL);
	memcpy(res, a, la);
	memcpy(res + la, b, lb);
	memcpy(res + la + lb, c, lc);
	res[la + lb + lc] = '\0';
	return (res);
}

void	px_error(const char *name, const char *msg)
{
	char	*line;
	char	*tmp;

	tmp = px_join3("pipex: ", name, ": ");
	line = px_join3(tmp, msg, "\n");
	if (line)
		write(2, line, px_strlen(line));
	free(tmp);
	free(line);
}

void	free_tab(char **tab)
{
	size_t	i;

	if (!tab)
		return ;
	i = 0;
	while (tab[i])
		free(tab[i++]);
	free(tab);
}
