init:
	cd scripts; go build -o ../.bin/build build.go

build:
	.bin/build packages

validate:
	for pkg in $$(ls dist); do echo "checking $$pkg"; corral package validate dist/$$pkg; done
