.PHONY: default clean

VERSION ?= 1.0

default:
	./install

clean:
	rm -rf linux-vfio/
