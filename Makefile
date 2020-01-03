TAG=latest
PORT=8080
NAME=dpd

all:

requirements:
	## combine the zope and plone requirements 
	cd requirements && pip-compile --no-annotate --no-header --allow-unsafe --generate-hashes main.in

build: Dockerfile
	## create the build and runtime images
	docker build -t dietplonedocker:$(TAG) .

run: build
	docker run -p $(PORT):8080 --name $(NAME) dietplonedocker:$(TAG)

shell:
	## shell in to the running instance
	docker exec -it $(NAME) /bin/bash

clean:
	## remove the latest build
	docker rmi -f dietplonedocker:$(TAG)

squeaky_clean:  clean  ## aggressively remove unused images
	@docker rmi python:3.7-slim-buster
	@docker system prune -a
	@for image in `docker images -f "dangling=true" -q`; do \
		echo removing $$image && docker rmi $$image ; done


help: ## This help.
	@awk 'BEGIN 	{ FS = ":.*##"; target="";printf "\nUsage:\n  make \033[36m<target>\033[33m\n\nTargets:\033[0m\n" } \
		/^[a-zA-Z_-]+:.*?##/ { if(target=="")print ""; target=$$1; printf " \033[36m%-10s\033[0m %s\n\n", $$1, $$2 } \
		/^([a-zA-Z_-]+):/ {if(target=="")print "";match($$0, "(.*):"); target=substr($$0,RSTART,RLENGTH) } \
		/^\t## (.*)/ { match($$0, "[^\t#:\\\\]+"); txt=substr($$0,RSTART,RLENGTH);printf " \033[36m%-10s\033[0m", target; printf " %s\n", txt ; target=""} \
		/^## .*/ {match($$0, "## (.+)$$"); txt=substr($$0,4,RLENGTH);printf "\n\033[33m%s\033[0m\n", txt ; target=""} \
	' $(MAKEFILE_LIST)
.PHONY: help requirements clean squeaky_clean