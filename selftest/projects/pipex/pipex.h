/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   pipex.h                                            :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: paco <paco@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/10/02 12:00:00 by paco              #+#    #+#             */
/*   Updated: 2026/10/02 12:00:00 by paco             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#ifndef PIPEX_H
# define PIPEX_H

# include <errno.h>
# include <fcntl.h>
# include <stdlib.h>
# include <string.h>
# include <sys/wait.h>
# include <unistd.h>

# define DEFAULT_PATH "/usr/local/bin:/usr/bin:/bin"

typedef struct s_px
{
	char	**envp;
	char	*infile;
	char	*outfile;
	char	*limiter;
	int		n_cmds;
	char	**cmds;
	pid_t	last_pid;
}	t_px;

size_t	px_strlen(const char *s);
char	*px_strndup(const char *s, size_t n);
char	*px_join3(const char *a, const char *b, const char *c);
void	px_error(const char *name, const char *msg);
void	free_tab(char **tab);
char	**parse_args(const char *s);
char	*find_command(char *name, char **envp, int *status);
void	run_pipeline(t_px *px, int in_fd);
int		read_heredoc(const char *limiter);

#endif
