CORES = fceumm gambatte gpsp pcsx_rearmed picodrive snes9x2005_plus
CORES+= mednafen_pce_fast mednafen_vb mednafen_supafaust mgba pokemini race
CORES+= fbalpha2012_neogeo fbalpha2012_cps1 fbalpha2012_cps2
# CORES+= fake-08

###############################

# optional core vars
# *_REPO=
# *_HASH=
# *_CORE=
# *_FLAGS=
# *_MAKEFILE=
# *_BUILD_PATH=

# pinned to the commits the patches were made against
# (checkouts on the old build server, Nov 2026)
fbalpha2012_cps1_HASH = ab1978f85d5b
fbalpha2012_cps2_HASH = 0c99e404152a
fbalpha2012_neogeo_HASH = 79ad770fe559
fceumm_HASH = 214c77052e82
gambatte_HASH = e99e1bd9b91d
gpsp_HASH = 2db57b11a437
mednafen_pce_fast_HASH = cad58cb0efed
mednafen_supafaust_HASH = 2b93c0d7dff5
mednafen_vb_HASH = 38e7a0ec9ac7
mgba_HASH = 6dce57eef127
pcsx_rearmed_HASH = d26eaee5c8fb
picodrive_HASH = b0be121b7d58
pokemini_HASH = 78656d461569
race_HASH = 9216c6dbbae7
snes9x2005_plus_HASH = b60356971fc9

mednafen_pce_fast_REPO = https://github.com/libretro/beetle-pce-fast-libretro
mednafen_vb_REPO = https://github.com/libretro/beetle-vb-libretro

fake-08_REPO = https://github.com/jtothebell/fake-08
fake-08_CORE = fake08_libretro.so
fake-08_BUILD_PATH = fake-08/platform/libretro

fceumm_REPO = https://github.com/libretro/libretro-fceumm

gambatte_REPO = https://github.com/libretro/gambatte-libretro

mednafen_supafaust_REPO = https://github.com/libretro/supafaust

pcsx_rearmed_MAKEFILE = Makefile.libretro

picodrive_REPO = https://github.com/irixxxx/picodrive
picodrive_MAKEFILE = Makefile.libretro

pokemini_REPO = https://github.com/libretro/PokeMini
pokemini_MAKEFILE = Makefile.libretro

snes9x2005_plus_REPO = https://github.com/libretro/snes9x2005
snes9x2005_plus_FLAGS = USE_BLARGG_APU=1

###############################

fbalpha2012_neogeo_REPO = https://github.com/libretro/fbalpha2012_neogeo
fbalpha2012_cps1_REPO = https://github.com/libretro/fbalpha2012_cps1
fbalpha2012_cps1_MAKEFILE = makefile.libretro
fbalpha2012_cps2_REPO = https://github.com/libretro/fbalpha2012_cps2
fbalpha2012_cps2_MAKEFILE = makefile.libretro
fbalpha2012_neogeo_FLAGS = platform=unix CC=$(CROSS_COMPILE)gcc CXX=$(CROSS_COMPILE)g++ AR=$(CROSS_COMPILE)ar
fbalpha2012_cps1_FLAGS = platform=unix CC=$(CROSS_COMPILE)gcc CXX=$(CROSS_COMPILE)g++ AR=$(CROSS_COMPILE)ar
fbalpha2012_cps2_FLAGS = platform=unix CC=$(CROSS_COMPILE)gcc CXX=$(CROSS_COMPILE)g++ AR=$(CROSS_COMPILE)ar

include ../../all/cores/makefile
