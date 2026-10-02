NAME	= libft.a
CC		= cc
CFLAGS	= -Wall -Wextra -Werror
SRCS	= $(filter-out %_bonus.c, $(wildcard ft_*.c))
BSRCS	= $(wildcard ft_*_bonus.c)
OBJS	= $(SRCS:.c=.o) $(BSRCS:.c=.o)

all: $(NAME)

$(NAME): $(OBJS)
	ar rcs $(NAME) $(OBJS)

%.o: %.c libft.h Makefile
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS)

fclean: clean
	rm -f $(NAME)

re: fclean all

.PHONY: all clean fclean re
