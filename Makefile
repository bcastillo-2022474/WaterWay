services-up:
	@echo "Building and running services..."
	docker compose --env-file .env.local up -d

services-clear:
	@echo "Removing services..."
	docker compose --env-file .env.local down -v --rmi all

