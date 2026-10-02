/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   get_next_line_utils.c                              :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "get_next_line.h"

size_t	gnl_strlen(const char *s)
{
	size_t	i;

	i = 0;
	if (!s)
		return (0);
	while (s[i])
		i++;
	return (i);
}

char	*gnl_strchr(const char *s, int c)
{
	if (!s)
		return (NULL);
	while (*s)
	{
		if (*s == (char)c)
			return ((char *)s);
		s++;
	}
	return (NULL);
}

char	*gnl_join(char *s1, const char *s2, size_t n2)
{
	char	*res;
	size_t	n1;
	size_t	i;

	n1 = gnl_strlen(s1);
	res = malloc(n1 + n2 + 1);
	if (res)
	{
		i = 0;
		while (i < n1 + n2)
		{
			if (i < n1)
				res[i] = s1[i];
			else
				res[i] = s2[i - n1];
			i++;
		}
		res[i] = '\0';
	}
	free(s1);
	return (res);
}

char	*gnl_substr(const char *s, size_t start, size_t len)
{
	char	*res;
	size_t	i;

	res = malloc(len + 1);
	if (!res)
		return (NULL);
	i = 0;
	while (i < len)
	{
		res[i] = s[start + i];
		i++;
	}
	res[len] = '\0';
	return (res);
}
