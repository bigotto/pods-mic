# PodsMic — build, instalação e .dmg.
#   make            monta build/PodsMic.app (universal: Apple Silicon + Intel)
#   make install    copia o app para ~/Applications e abre
#   make dmg        gera build/PodsMic-<versão>.dmg
#   make icon       regenera Resources/AppIcon.icns
#   make clean      apaga .build e build
#
# A versão vem da última tag do git (v1.2.0 -> 1.2.0); dá para forçar com `make dmg VERSION=1.2.0`.

NAME    := PodsMic
BUILD   := build
APP     := $(BUILD)/$(NAME).app
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)
VERSION := $(or $(VERSION),0.0.0)
DMG     := $(BUILD)/$(NAME)-$(VERSION).dmg
ARCHS   := --arch arm64 --arch x86_64
PLIST   := /usr/libexec/PlistBuddy

.PHONY: all app install dmg icon clean

all: app

app:
	swift build -c release $(ARCHS)
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$$(swift build -c release $(ARCHS) --show-bin-path)/$(NAME)" "$(APP)/Contents/MacOS/"
	cp Resources/Info.plist "$(APP)/Contents/"
	cp Resources/AppIcon.icns "$(APP)/Contents/Resources/"
	$(PLIST) -c "Set :CFBundleShortVersionString $(VERSION)" "$(APP)/Contents/Info.plist"
	codesign --force --sign - "$(APP)"
	@echo "Pronto: $(APP) ($(VERSION))"

install: app
	pkill -x $(NAME) || true
	mkdir -p ~/Applications
	rm -rf ~/Applications/$(NAME).app
	cp -R "$(APP)" ~/Applications/
	open ~/Applications/$(NAME).app
	@echo "Instalado em ~/Applications/$(NAME).app"

# Imagem com o app e um atalho para /Applications, para arrastar e instalar.
dmg: app
	rm -rf "$(BUILD)/dmg" "$(DMG)"
	mkdir -p "$(BUILD)/dmg"
	cp -R "$(APP)" "$(BUILD)/dmg/"
	ln -s /Applications "$(BUILD)/dmg/Applications"
	hdiutil create -volname "$(NAME)" -srcfolder "$(BUILD)/dmg" -fs HFS+ -format UDZO -ov "$(DMG)"
	rm -rf "$(BUILD)/dmg"
	@echo "Pronto: $(DMG)"

icon:
	swift Resources/make-icon.swift

clean:
	rm -rf .build "$(BUILD)"
