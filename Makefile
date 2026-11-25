# quill — build, test, lint.
#
# `make plugin`   builds the vendored qml-niri plugin into ./build/qml/Niri so
#                 Quickshell can load it via QML_IMPORT_PATH (set by quill-launch.sh).
#                 qml-niri's CMake has no install() rules: qt_add_qml_module(...
#                 OUTPUT_DIRECTORY <build>/Niri) emits qmldir + libNiri.so directly;
#                 we copy that module dir into build/qml/Niri.
# `make test`     runs every tests/tst_*.qml suite; fails if ANY suite fails.
# `make lint`     qmllint over all tracked .qml files (syntax errors fail; the
#                 [unqualified] baseline from qs.* singleton imports does not).
# `make lint-file FILE=x.qml`  lints one file — used by the Claude Code hook.
#
# Qt6 tools (qmltestrunner, qmllint) are often not on $PATH. QT_BIN is
# auto-detected below; override with `make test QT_BIN=/path/to/qt6/bin`.

PLUGIN_SRC := vendor/qml-niri
BUILD_DIR  := build/plugin
QML_OUT    := build/qml

QT_BIN ?= $(shell qtpaths6 --query QT_INSTALL_BINS 2>/dev/null)
ifeq ($(strip $(QT_BIN)),)
QT_BIN := $(firstword $(wildcard /usr/lib64/qt6/bin /usr/lib/qt6/bin /usr/lib/x86_64-linux-gnu/qt6/bin))
endif

TESTS := $(wildcard tests/tst_*.qml)
SH_TESTS := $(wildcard tests/sh/test_*.sh)
QMLS  := $(shell git ls-files '*.qml')

.PHONY: all plugin test lint lint-file qt-bin clean

all: plugin

plugin:
	cmake -S $(PLUGIN_SRC) -B $(BUILD_DIR) -DCMAKE_BUILD_TYPE=Release
	cmake --build $(BUILD_DIR) --parallel
	@mkdir -p $(QML_OUT)
	@rm -rf $(QML_OUT)/Niri
	@cp -r $(BUILD_DIR)/Niri $(QML_OUT)/Niri
	@echo "Plugin built into $(QML_OUT)/Niri"

qt-bin:
	@test -n "$(QT_BIN)" || { echo "error: Qt6 tools not found — set QT_BIN=/path/to/qt6/bin" >&2; exit 1; }

test: qt-bin
	@fail=0; \
	for t in $(TESTS); do \
		echo "== $$t"; \
		"$(QT_BIN)/qmltestrunner" -input "$$t" || fail=1; \
	done; \
	for t in $(SH_TESTS); do \
		echo "== $$t"; \
		sh "$$t" || fail=1; \
	done; \
	if [ $$fail -ne 0 ]; then echo "FAILED: at least one suite failed" >&2; fi; \
	exit $$fail

lint: qt-bin
	@fail=0; \
	for f in $(QMLS); do \
		"$(QT_BIN)/qmllint" -I . "$$f" || { echo "lint FAILED: $$f" >&2; fail=1; }; \
	done; \
	exit $$fail

lint-file: qt-bin
	@test -n "$(FILE)" || { echo "usage: make lint-file FILE=path/to/file.qml" >&2; exit 2; }
	@"$(QT_BIN)/qmllint" -I . "$(FILE)"

clean:
	rm -rf build
