SHELL:=/bin/bash

all:
	$(shell ./download_jquery.sh $<)

clean:
	rm -Rf dump-new.html dump-out.html
