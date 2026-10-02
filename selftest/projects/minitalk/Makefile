CC		= cc
CFLAGS	= -Wall -Wextra -Werror

all: server client

server: server.c minitalk.h Makefile
	$(CC) $(CFLAGS) server.c -o server

client: client.c minitalk.h Makefile
	$(CC) $(CFLAGS) client.c -o client

bonus: all

clean:

fclean: clean
	rm -f server client

re: fclean all

.PHONY: all bonus clean fclean re
