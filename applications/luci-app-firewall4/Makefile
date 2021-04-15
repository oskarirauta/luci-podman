#
# Copyright (C) 2008-2014 The LuCI Team <luci@lists.subsignal.org>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-firewall4
LUCI_TITLE:=Firewall and Portforwarding application
LUCI_DEPENDS:=+firewall4

PKG_LICENSE:=Apache-2.0

include ../../../luci/luci.mk

define Package/$(PKG_NAME)
  SECTION:=$(LUCI_SECTION)
  CATEGORY:=$(LUCI_CATEGORY)
  SUBMENU:=$(if $(LUCI_MENU.$(LUCI_TYPE)),$(LUCI_MENU.$(LUCI_TYPE)),$(LUCI_MENU.app))
  TITLE:=$(if $(LUCI_TITLE),$(LUCI_TITLE),LuCI $(LUCI_NAME) $(LUCI_TYPE))
  DEPENDS:=$(LUCI_DEPENDS)
  VERSION:=$(if $(PKG_VERSION),$(PKG_VERSION),$(PKG_SRC_VERSION))
  $(if $(LUCI_EXTRA_DEPENDS),EXTRA_DEPENDS:=$(LUCI_EXTRA_DEPENDS))
  $(if $(LUCI_PKGARCH),PKGARCH:=$(LUCI_PKGARCH))
  VARIANT:=fw4
  CONFLICTS:=luci-app-firewall
endef

# call BuildPackage - OpenWrt buildroot signature
