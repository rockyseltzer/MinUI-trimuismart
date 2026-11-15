# MinUI-trimuismart: custom MinUI firmware for the TrimUI Smart.
# Builds natively on Linux (no Docker).
#
#   make            build everything and package releases/MinUI-trimuismart-*.zip
#   make build      compile only
#   make shell      shell with the cross-compile environment set
#   make toolchain  one-time toolchain setup

override PLATFORM := trimuismart

###########################################################

BUILD_HASH:=$(shell git rev-parse --short HEAD)
RELEASE_TIME:=$(shell TZ=GMT date +%Y%m%d)
RELEASE_BETA=
RELEASE_BASE=MinUI-trimuismart-$(RELEASE_TIME)$(RELEASE_BETA)
RELEASE_DOT:=$(shell find ./releases/. -regextype posix-extended -regex ".*/${RELEASE_BASE}-[0-9]+\.zip" 2>/dev/null | wc -l | sed 's/ //g')
RELEASE_NAME=$(RELEASE_BASE)-$(RELEASE_DOT)

###########################################################

.PHONY: build

export MAKEFLAGS=--no-print-directory

all: setup build system cores strip special package done
	
shell:
	make -f makefile.toolchain PLATFORM=$(PLATFORM)

toolchain:
	make toolchain -f makefile.toolchain PLATFORM=$(PLATFORM)

name: 
	@echo $(RELEASE_NAME)

build:
	# ----------------------------------------------------
	make build -f makefile.toolchain PLATFORM=$(PLATFORM)
	# ----------------------------------------------------

system:
	make -f ./workspace/$(PLATFORM)/platform/makefile.copy PLATFORM=$(PLATFORM)
	
	# populate system
	cp ./workspace/$(PLATFORM)/keymon/keymon.elf ./build/SYSTEM/$(PLATFORM)/bin/
	cp ./workspace/$(PLATFORM)/libmsettings/libmsettings.so ./build/SYSTEM/$(PLATFORM)/lib
	cp ./workspace/all/minui/build/$(PLATFORM)/minui.elf ./build/SYSTEM/$(PLATFORM)/bin/
	cp ./workspace/all/minarch/build/$(PLATFORM)/minarch.elf ./build/SYSTEM/$(PLATFORM)/bin/
	cp ./workspace/all/syncsettings/build/$(PLATFORM)/syncsettings.elf ./build/SYSTEM/$(PLATFORM)/bin/
	cp ./workspace/all/say/build/$(PLATFORM)/say.elf ./build/SYSTEM/$(PLATFORM)/bin/
	cp ./workspace/all/clock/build/$(PLATFORM)/clock.elf ./build/EXTRAS/Tools/$(PLATFORM)/Clock.pak/
	cp ./workspace/all/minput/build/$(PLATFORM)/minput.elf ./build/EXTRAS/Tools/$(PLATFORM)/Input.pak/
	cp ./workspace/all/battery/build/$(PLATFORM)/battery.elf ./build/EXTRAS/Tools/$(PLATFORM)/Battery.pak/

cores:
	# stock cores
	cp ./workspace/$(PLATFORM)/cores/output/fceumm_libretro.so ./build/SYSTEM/$(PLATFORM)/cores
	cp ./workspace/$(PLATFORM)/cores/output/gambatte_libretro.so ./build/SYSTEM/$(PLATFORM)/cores
	cp ./workspace/$(PLATFORM)/cores/output/gpsp_libretro.so ./build/SYSTEM/$(PLATFORM)/cores
	cp ./workspace/$(PLATFORM)/cores/output/picodrive_libretro.so ./build/SYSTEM/$(PLATFORM)/cores
	cp ./workspace/$(PLATFORM)/cores/output/snes9x2005_plus_libretro.so ./build/SYSTEM/$(PLATFORM)/cores
	cp ./workspace/$(PLATFORM)/cores/output/pcsx_rearmed_libretro.so ./build/SYSTEM/$(PLATFORM)/cores
	
	# cores that live in their own pak
	cp ./workspace/$(PLATFORM)/cores/output/pokemini_libretro.so ./build/EXTRAS/Emus/$(PLATFORM)/PKM.pak
	cp ./workspace/$(PLATFORM)/cores/output/fbalpha2012_neogeo_libretro.so ./build/EXTRAS/Emus/$(PLATFORM)/NEOGEO.pak
	cp ./workspace/$(PLATFORM)/cores/output/fbalpha2012_cps1_libretro.so ./build/EXTRAS/Emus/$(PLATFORM)/CPS1.pak
	cp ./workspace/$(PLATFORM)/cores/output/fbalpha2012_cps2_libretro.so ./build/EXTRAS/Emus/$(PLATFORM)/CPS2.pak
	cp ./workspace/$(PLATFORM)/cores/output/mgba_libretro.so ./build/EXTRAS/Emus/$(PLATFORM)/MGBA.pak
	cp ./workspace/$(PLATFORM)/cores/output/mgba_libretro.so ./build/EXTRAS/Emus/$(PLATFORM)/SGB.pak
	cp ./workspace/$(PLATFORM)/cores/output/mednafen_pce_fast_libretro.so ./build/EXTRAS/Emus/$(PLATFORM)/PCE.pak
	cp ./workspace/$(PLATFORM)/cores/output/race_libretro.so ./build/EXTRAS/Emus/$(PLATFORM)/NGP.pak
	cp ./workspace/$(PLATFORM)/cores/output/race_libretro.so ./build/EXTRAS/Emus/$(PLATFORM)/NGPC.pak
	cp ./workspace/$(PLATFORM)/cores/output/mednafen_supafaust_libretro.so ./build/EXTRAS/Emus/$(PLATFORM)/SUPA.pak
	cp ./workspace/$(PLATFORM)/cores/output/mednafen_vb_libretro.so ./build/EXTRAS/Emus/$(PLATFORM)/VB.pak
	
clean:
	rm -rf ./build

setup: name
	# ----------------------------------------------------
	# ready fresh build
	rm -rf ./build
	mkdir -p ./releases
	cp -R ./skeleton ./build
	
	# remove authoring detritus
	cd ./build && find . -type f -name '.keep' -delete
	cd ./build && find . -type f -name '*.meta' -delete
	echo $(BUILD_HASH) > ./workspace/hash.txt
	
	# copy the readme to workspace so the platform build can fmt it
	mkdir -p ./workspace/readmes
	cp ./skeleton/README.txt ./workspace/readmes/README-in.txt
	
done:
	say "done" 2>/dev/null || true

# Strip the binaries built here: drops symbol tables, which also carry this
# machine's build paths. Libretro cores keep their dynamic exports.
STRIP ?= $(CURDIR)/toolchains/$(PLATFORM)-toolchain/usr/bin/arm-buildroot-linux-gnueabihf-strip
strip:
	# ----------------------------------------------------
	find ./build/SYSTEM/$(PLATFORM) ./build/BOOT ./build/EXTRAS -type f \( -name '*.elf' -o -name '*_libretro.so' -o -name 'libmsettings.so' \) -exec "$(STRIP)" --strip-unneeded {} +

special:
	# ----------------------------------------------------
	# BOOT/common becomes .tmp_update (updater + trimuismart.sh + installer art)
	mv ./build/BOOT/common ./build/BOOT/.tmp_update
	# trimui/ is the first-install bootstrap the stock firmware launches; it
	# copies .tmp_update to the card root, then deletes itself
	mkdir -p ./build/PACKAGE
	cp -R ./build/BOOT/trimui ./build/PACKAGE/
	cp -R ./build/BOOT/.tmp_update ./build/PACKAGE/trimui/app/

package:
	# ----------------------------------------------------
	# one zip, laid out exactly as it goes on the card
	cp ./workspace/readmes/README-out.txt ./build/PACKAGE/README.txt
	rm -rf ./workspace/readmes

	# MinUI.zip: the system, unpacked by .tmp_update on the next boot
	printf '%s\n%s\n' "$(RELEASE_NAME)" "$(BUILD_HASH)" > ./build/SYSTEM/version.txt
	./commits.sh > ./build/SYSTEM/commits.txt
	mkdir -p ./build/PAYLOAD/.system
	cp -R ./build/SYSTEM/trimuismart ./build/SYSTEM/res ./build/SYSTEM/version.txt ./build/SYSTEM/commits.txt ./build/PAYLOAD/.system/
	cp -R ./build/BOOT/.tmp_update ./build/PAYLOAD/
	cd ./build/PAYLOAD && zip -qr ../PACKAGE/MinUI.zip .system .tmp_update

	# card folders: base and extras merged, trimuismart only
	cp -R ./build/BASE/Bios ./build/BASE/Roms ./build/BASE/Saves ./build/PACKAGE/
	cp -R ./build/EXTRAS/Bios ./build/EXTRAS/Roms ./build/EXTRAS/Saves ./build/PACKAGE/
	mkdir -p ./build/PACKAGE/Emus ./build/PACKAGE/Tools
	cp -R ./build/EXTRAS/Emus/trimuismart ./build/PACKAGE/Emus/
	cp -R ./build/EXTRAS/Tools/trimuismart ./build/PACKAGE/Tools/

	cd ./build && find . -type f -name '.DS_Store' -delete
	cd ./build/PACKAGE && zip -qr ../../releases/$(RELEASE_NAME).zip trimui MinUI.zip Bios Roms Saves Emus Tools README.txt
	echo "$(RELEASE_NAME)" > ./build/latest.txt
	@echo "packaged releases/$(RELEASE_NAME).zip"
