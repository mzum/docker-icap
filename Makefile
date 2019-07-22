all: build

build:
	@docker build --tag=mzum/docker-icap .
