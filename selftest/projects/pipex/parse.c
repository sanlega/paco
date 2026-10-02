/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   parse.c                                            :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

/*
** Shell-like word splitting: spaces separate words, '...' is literal,
** "..." keeps spaces and honours \" and \\, a bare backslash escapes the
** next character.
*/
static size_t	quoted(const char *s, char *out, size_t *o)
{
	size_t	i;
	char	q;

	q = s[0];
	i = 1;
	while (s[i] && s[i] != q)
	{
		if (q == '"' && s[i] == '\\' && (s[i + 1] == '"' || s[i + 1] == '\\'))
			i++;
		if (out)
			out[*o] = s[i];
		(*o)++;
		i++;
	}
	if (s[i] == q)
		i++;
	return (i);
}

static size_t	word(const char *s, char *out, size_t *len)
{
	size_t	i;

	i = 0;
	*len = 0;
	while (s[i] && s[i] != ' ' && s[i] != '\t')
	{
		if (s[i] == '\'' || s[i] == '"')
			i += quoted(s + i, out, len);
		else
		{
			if (s[i] == '\\' && s[i + 1])
				i++;
			if (out)
				out[*len] = s[i];
			(*len)++;
			i++;
		}
	}
	return (i);
}

static size_t	count_words(const char *s)
{
	size_t	n;
	size_t	len;

	n = 0;
	while (*s)
	{
		while (*s == ' ' || *s == '\t')
			s++;
		if (!*s)
			break ;
		s += word(s, NULL, &len);
		n++;
	}
	return (n);
}

static char	*next_word(const char **s)
{
	size_t	len;
	char	*w;

	while (**s == ' ' || **s == '\t')
		(*s)++;
	word(*s, NULL, &len);
	w = malloc(len + 1);
	if (!w)
		return (NULL);
	*s += word(*s, w, &len);
	w[len] = '\0';
	return (w);
}

char	**parse_args(const char *s)
{
	char	**res;
	size_t	n;
	size_t	i;

	n = count_words(s);
	res = malloc(sizeof(char *) * (n + 1));
	if (!res)
		return (NULL);
	i = 0;
	while (i < n)
	{
		res[i] = next_word(&s);
		if (!res[i])
		{
			free_tab(res);
			return (NULL);
		}
		res[++i] = NULL;
	}
	res[n] = NULL;
	return (res);
}
