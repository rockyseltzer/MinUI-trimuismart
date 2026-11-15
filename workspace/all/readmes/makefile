readmes:
ifneq ($(wildcard ../readmes/README-in.txt),)
	# formatting readme for the 320px screen's text viewer
	cd ../readmes && fmt -w 40 -s ./README-in.txt > ./README-out.txt
	cd ../readmes && rm ./README-in.txt
else
	# skipped readme
endif
