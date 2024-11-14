# tool macros
CC := ${CC}
CC ?= clang-18
CFLAGS := -target aarch64-linux-gnu -fuse-ld=/usr/bin/ld.lld-18
COBJFLAGS := -target aarch64-linux-gnu -O3 -march=armv8.3-a+sha3 -c 

# path macros
BIN_PATH := .
OBJ_PATH := obj
SRC_PATH := src
DBG_PATH := debug

# compile macros
TARGET_NAME_DYNAMIC := sm4
TARGET_DYNAMIC := $(BIN_PATH)/$(TARGET_NAME_DYNAMIC)

# src files & obj files
SRC := $(foreach x, $(SRC_PATH), $(wildcard $(addprefix $(x)/*,.s*)))
OBJ := $(addprefix $(OBJ_PATH)/, $(addsuffix .o, $(notdir $(basename $(SRC)))))

# clean files list
DISTCLEAN_LIST := $(OBJ)
CLEAN_LIST := $(TARGET_DYNAMIC) \
			  $(DISTCLEAN_LIST)

# default rule
default: makedir all

# non-phony targets
$(TARGET_DYNAMIC): $(OBJ)
	$(info $(NULL)  ELF $(TARGET_DYNAMIC))
	@$(CC) $(CFLAGS) -o $@ $(OBJ)

$(OBJ_PATH)/%.o: $(SRC_PATH)/%.s*
	$(info $(NULL)  CC  $< $@)
	@$(CC) $(COBJFLAGS) -o $@ $<

# phony rules
.PHONY: envinfo
envinfo:

ifeq ($(OS),Windows_NT)
	$(info Platform: Windows $())
else
	$(info Platform: $(shell uname -a))
endif

	$(info CC: $(CC))
	$(info CFlags: $(CFLAGS))
	$(info CObjFlags: $(COBJFLAGS))

.PHONY: makedir
makedir:
	@mkdir -p $(BIN_PATH) $(OBJ_PATH)

.PHONY: all
all: envinfo $(TARGET_DYNAMIC)

.PHONY: clean
clean:
	@echo "  CLEAN $(CLEAN_LIST)"
	@rm -rf $(CLEAN_LIST)
