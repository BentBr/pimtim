# Making sure we are having our variables from .env
include .env
include .env.local
export

USER_ID = $(shell id -u)
GROUP_ID = $(shell id -g)

# Other variables
PIMCORE_DIR = .
PIMCORE_SNAPSHOT_DIR = $(PIMCORE_DIR)/etc/snapshot


# The base command to start the docker setup.
DOCKER_COMPOSE = GROUP_ID=$(GROUP_ID) USER_ID=$(USER_ID) mutagen-compose

#############################################################################################
######################################### Utilities #########################################
#############################################################################################

.PHONY: start
start:
	# Starting mutagen daemon if not already up
	mutagen daemon start
	# Staring Docker Compose with mutagen
	$(DOCKER_COMPOSE) up -d

.PHONY: stop
stop:
	# Killing mutagen compose
	$(DOCKER_COMPOSE) stop

.PHONY: clear
clear:
	# Killing mutagen compose
	$(DOCKER_COMPOSE) down

.PHONY: init
init: initialize

.PHONY: initialize
initialize:
	$(MAKE) start
	$(MAKE) fix_permissions
	$(MAKE) pimcore_assets
	$(MAKE) pimcore_packages
	$(MAKE) pimcore_restore
	$(MAKE) pimcore_classes_rebuild
	$(MAKE) pimcore_clear_cache

# Mac users tend to have an issue without
.PHONY: fix_permissions
fix_permissions:
	$(DOCKER_COMPOSE) exec --user root pimcore chown -R $(USER_ID):$(GROUP_ID) /var/www/

.PHONY: pimcore_assets
pimcore_assets:
	# Build Symfony encore assets
	cd $(PIMCORE_DIR) && npm i && npm run build

.PHONY: pimcore_packages
pimcore_packages:
	# Run composer install inside the pimcore container
	$(DOCKER_COMPOSE) exec pimcore composer --no-ansi --no-interaction install

.PHONY: pimcore_update
pimcore_update:
	# Run composer install inside the pimcore container
	$(DOCKER_COMPOSE) exec pimcore composer --no-ansi --no-interaction update

.PHONY: pa
pa: pimcore_analyse

.PHONY: pimcore_analyse
pimcore_analyse:
	# Run phpstan inside the pimcore container
	$(DOCKER_COMPOSE) exec pimcore vendor/bin/phpstan

# Just a convenience alias
.PHONY: snapshot
snapshot: pimcore_snapshot

.PHONY: pimcore_snapshot
pimcore_snapshot: _create_pimcore_snapshot_folders
	# Clear assets from the snapshot so that missing ones aren't kept in the snapshot
	rm -f $(PIMCORE_SNAPSHOT_DIR)/public/var/assets/assets.zip
	# Save assets via simple copy
	cp -v -R $(PIMCORE_DIR)/public/var/assets/* $(PIMCORE_SNAPSHOT_DIR)/public/var/assets/

	# Save database
	$(MAKE) db_snapshot

# Just a convenience alias
.PHONY: db_snapshot
db_snapshot:
	# Save database
	# Removing all the definers - which would break on importing
	$(DOCKER_COMPOSE) exec db mysqldump --routines --add-drop-table -u root $(MYSQL_DATABASE) | grep -v 'SQL SECURITY DEFINER' | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e 's/DEFINER[ ]*=[ ]*[^*]*PROCEDURE/PROCEDURE/' | sed -e 's/DEFINER[ ]*=[ ]*[^*]*FUNCTION/FUNCTION/' > $(PIMCORE_SNAPSHOT_DIR)/dump.sql

# Just a convenience alias
.PHONY: restore
restore: pimcore_restore

.PHONY: pimcore_restore
pimcore_restore: _create_pimcore_snapshot_folders
	# Clear assets to make sure we do not add unused assets when we take a snapshot again
	rm -rf $(PIMCORE_DIR)/public/var/assets
	# Restore assets via simple cp
	mkdir $(PIMCORE_DIR)/public/var/assets
	cp -R $(PIMCORE_SNAPSHOT_DIR)/public/var/assets/* $(PIMCORE_DIR)/public/var/assets/


	# Restore the database
	$(DOCKER_COMPOSE) exec -T db mysql -u root $(MYSQL_DATABASE) < $(PIMCORE_SNAPSHOT_DIR)/dump.sql

.PHONY: _create_pimcore_snapshot_folders
_create_pimcore_snapshot_folders:
	mkdir -p $(PIMCORE_SNAPSHOT_DIR)/public/var/assets
	mkdir -p $(PIMCORE_DIR)/public/var/assets

.PHONY: pimcore_classes_rebuild
pimcore_classes_rebuild:
	# Rebuilding classes
	$(DOCKER_COMPOSE) exec pimcore bin/console pimcore:deployment:classes-rebuild --no-interaction --create-classes -v

.PHONY: pimcore_clear_cache
pimcore_clear_cache:
	# Killing cache
	docker-compose exec pimcore bin/console cache:clear --no-interaction -v
	docker-compose exec pimcore bin/console pimcore:cache:clear --no-interaction -v
