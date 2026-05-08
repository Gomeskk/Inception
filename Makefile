NAME		= inception
COMPOSE_FILE	= srcs/docker-compose.yml
DATA_PATH	= /home/joafaust/data

all: setup
	@docker compose -f $(COMPOSE_FILE) up -d --build

setup:
	@mkdir -p $(DATA_PATH)/wordpress $(DATA_PATH)/mariadb

down:
	@docker compose -f $(COMPOSE_FILE) down

stop:
	@docker compose -f $(COMPOSE_FILE) stop

# Stops containers, removes volumes and images, and deletes data on host
clean: down
	@docker compose -f $(COMPOSE_FILE) down --volumes --rmi all 2>/dev/null || true
	@sudo rm -rf $(DATA_PATH)

fclean: clean

re: fclean all

logs:
	@docker compose -f $(COMPOSE_FILE) logs -f

ps:
	@docker compose -f $(COMPOSE_FILE) ps

.PHONY: all setup down stop clean fclean re logs ps
