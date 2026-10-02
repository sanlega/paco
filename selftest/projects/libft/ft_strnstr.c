/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   ft_strnstr.c                                       :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "libft.h"

char	*ft_strnstr(const char *haystack, const char *needle, size_t len)
{
	size_t	i;
	size_t	j;

	if (!*needle)
		return ((char *)haystack);
	i = 0;
	while (i < len && haystack[i])
	{
		j = 0;
		while (i + j < len && needle[j] && haystack[i + j] == needle[j])
			j++;
		if (!needle[j])
			return ((char *)haystack + i);
		i++;
	}
	return (NULL);
}
