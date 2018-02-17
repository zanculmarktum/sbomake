# Copyright 2018 Azure Zanculmarktum <zanculmarktum@gmail.com>

# $(cwd) = ../..  means this script is inside slackbuilds/category/package/
# $(cwd) = ..     means this script is inside slackbuilds/category/
# $(cwd) = .      means this script is inside slackbuilds/
cwd = $(subst /Makefile,,$(shell readlink Makefile))
ifeq ($(cwd), )
cwd = .
endif

ifeq ($(cwd), .)
path =
else
path = $(cwd)/
endif

cmds = search isearch esearch unpack
ifeq ($(cwd), .)
cmds += link delink
endif
ifeq ($(cwd), ../..)
cmds += install deinstall clean list-depends list-depends-reverse
endif

ifeq ($(cwd), ../..)
package = $(notdir $(CURDIR))
category = $(notdir $(subst /$(package),,$(CURDIR)))

DISTDIR = $(cwd)/distfiles/$(package)
WORKDIR = work
PKGSDIR = $(cwd)/packages
endif

ifneq ($(cwd), ../..)
all:
	@echo "Usage: $(MAKE) command [command ...]" >&2; \
	echo "       $(MAKE) help" >&2
else
all:
	@. ./$(package).info; \
	eval $$(grep '^\(BUILD\|TAG\)=' $(package).SlackBuild); \
	case "$$( uname -m )" in \
		i?86) ARCH="i?86" ;; \
		arm*) ARCH="arm*" ;; \
		   *) ARCH=$$( uname -m ) ;; \
	esac; \
	\
	found=false; \
	for i in \
	$(PKGSDIR)/$$PRGNAM-$$VERSION-$$ARCH-$$BUILD$$TAG.txz \
	$(PKGSDIR)/$$PRGNAM-$$VERSION-fw-$$BUILD$$TAG.txz \
	$(PKGSDIR)/$$PRGNAM-$$VERSION-noarch-$$BUILD$$TAG.txz \
	$(PKGSDIR)/$$PRGNAM-$$VERSION-x86-$$BUILD$$TAG.txz; \
	do \
		[ -f "$$i" ] || continue; \
		found=true; \
		break; \
	done; \
	if $$found && [ ! "$(force)" = "true" ]; then \
		echo "==> Already built: $$i"; \
	else \
		MODS=$$(git status -s . | grep '^.[MADRCU]'); \
		if [ -n "$$MODS" ]; then \
			echo "==> Restoring upstream files..."; \
			for i in $$(echo "$$MODS" | sed 's/^.. //'); do \
				echo " => $$i"; \
			done; \
			git checkout .; \
		fi; \
		\
		if [ ! -d "$(DISTDIR)" ]; then \
			if [ -t 1 ]; then \
				echo -e "\e[0;31m--> No sources were found in $(DISTDIR)\e[0m" >&2; \
			else \
				echo "--> No sources were found in $(DISTDIR)" >&2; \
			fi; \
			false; \
		fi; \
		if rmdir $(DISTDIR)/ >/dev/null 2>&1; then \
			if [ -t 1 ]; then \
				echo -e "\e[0;31m--> No sources were found in $(DISTDIR)\e[0m" >&2; \
			else \
				echo "--> No sources were found in $(DISTDIR)" >&2; \
			fi; \
			false; \
		fi; \
		\
		echo "==> Preparing..."; \
		for i in $(WORKDIR) $(PKGSDIR); do \
			if [ ! -d "$$i" ]; then \
				mkdir -p $$i; \
				if [ "$$?" = "0" ]; then \
					echo " => $$i/ created"; \
				else \
					if [ -t 1 ]; then \
						echo -e "\e[0;31m -> $$i/ can't be created\e[0m" >&2; \
					else \
						echo " -> $$i/ can't be created" >&2; \
					fi; \
				fi; \
			fi; \
		done; \
		for i in $(DISTDIR)/* $(DISTDIR)/.*; do \
			if [ "$${i##*/}" = "." -o "$${i##*/}" = ".." ]; then \
				continue; \
			fi; \
			if [ ! -L "$${i##*/}" ]; then \
				ln -srf "$$i" "$${i##*/}"; \
				if [ "$$?" = "0" ]; then \
					echo " => $${i##*/}@ linked"; \
				else \
					if [ -t 1 ]; then \
						echo -e "\e[0;31m -> $${i##*/}@ can't be linked\e[0m" >&2; \
					else \
						echo " -> $${i##*/}@ can't be linked" >&2; \
					fi; \
				fi; \
			fi; \
		done; \
		\
		echo "==> Building..."; \
		[ -x "$(package).SlackBuild" ] || chmod +x $(package).SlackBuild; \
		TMP="$(abspath $(WORKDIR))" OUTPUT="$(abspath $(PKGSDIR))" PKGTYPE="txz" ./$(package).SlackBuild; \
	fi

install: all
	@. ./$(package).info; \
	eval $$(grep '^\(BUILD\|TAG\)=' $(package).SlackBuild); \
	case "$$( uname -m )" in \
		i?86) ARCH="i?86" ;; \
		arm*) ARCH="arm*" ;; \
		   *) ARCH=$$( uname -m ) ;; \
	esac; \
	\
	found=false; \
	for i in /var/log/packages/$$PRGNAM-$$VERSION-*; do \
		[ -f "$$i" ] || continue; \
		found=true; \
		break; \
	done; \
	if ! $$found; then \
		pkgs=""; \
		i=1; \
		for j in \
		$(PKGSDIR)/$$PRGNAM-$$VERSION-$$ARCH-$$BUILD$$TAG.txz \
		$(PKGSDIR)/$$PRGNAM-$$VERSION-fw-$$BUILD$$TAG.txz \
		$(PKGSDIR)/$$PRGNAM-$$VERSION-noarch-$$BUILD$$TAG.txz \
		$(PKGSDIR)/$$PRGNAM-$$VERSION-x86-$$BUILD$$TAG.txz; \
		do \
			[ -f "$$j" ] || continue; \
			pkgs="$$pkgs $$i|$${j##*/}"; \
			i=$$(($$i+1)); \
		done; \
		\
		npkg=$$(echo $$pkgs | awk '{ print NF }'); \
		if [ "$$npkg" -eq 0 ]; then \
			echo -e "\e[0;31m--> No $(package) package was found in $(PKGSDIR)\e[0m" >&2; \
		elif [ "$$npkg" -eq 1 ]; then \
			/sbin/upgradepkg --install-new "$(abspath $(PKGSDIR))/$${pkgs#*|}"; \
		else \
			echo "==> More than one $(package) package were found in $(PKGSDIR):"; \
			for i in $$pkgs; do \
				echo " => [$${i%|*}] $${i#*|}"; \
			done; \
			echo ""; \
			while :; do \
				echo -n "==> Select which one to $@: "; \
				read n; \
				j=""; \
				for i in $$pkgs; do \
					if [ "$${i%|*}" = "$$n" ]; then \
						j="$${i#*|}"; \
						break; \
					fi; \
				done; \
				if [ -n "$$j" ]; then \
					/sbin/upgradepkg --install-new "$(abspath $(PKGSDIR))/$$j"; \
					break; \
				fi; \
				echo -e "\e[0;31m -> incorrect input\e[0m" >&2; \
			done; \
		fi; \
	fi

deinstall:
	@. ./$(package).info; \
	eval $$(grep '^\(BUILD\|TAG\)=' $(package).SlackBuild); \
	case "$$( uname -m )" in \
		i?86) ARCH="i?86" ;; \
		arm*) ARCH="arm*" ;; \
		   *) ARCH=$$( uname -m ) ;; \
	esac; \
	\
	found=false; \
	for i in /var/log/packages/$$PRGNAM-$$VERSION-*; do \
		[ -f "$$i" ] || continue; \
		found=true; \
		break; \
	done; \
	if $$found; then \
		/sbin/removepkg "$$i"; \
	fi

clean:
	@echo "==> Cleaning up..."; \
	if [ -d "$(WORKDIR)" ]; then \
		rm -Rf $(WORKDIR); \
		if [ "$$?" = "0" ]; then \
			echo " => $(WORKDIR)/ deleted"; \
		else \
			if [ -t 1 ]; then \
				echo -e "\e[0;31m -> $(WORKDIR)/ can't be deleted\e[0m" >&2; \
			else \
				echo " -> $(WORKDIR)/ can't be deleted" >&2; \
			fi; \
		fi; \
	fi; \
	\
	for i in * .*; do \
		if [ "$$i" = "." -o "$$i" = ".." ]; then \
			continue; \
		fi; \
		refer="$$(readlink $$i)"; \
		if [ "$${refer#$(DISTDIR)}" != "$$refer" ]; then \
			rm -Rf "$$i"; \
			if [ "$$?" = "0" ]; then \
				echo " => $$i@ unlinked"; \
			else \
				if [ -t 1 ]; then \
					echo -e "\e[0;31m -> $$i@ can't be unlinked\e[0m" >&2; \
				else \
					echo " -> $$i@ can't be unlinked" >&2; \
				fi; \
			fi; \
		fi; \
	done

_depends:
	@. ./$(package).info; \
	for i in $$REQUIRES; do \
		path=$$($(MAKE) -s esearch name=$$i); \
		( cd $$path && $(MAKE) -s $@ ); \
		echo $$path; \
	done | awk '{ if (!dups[$$0]++) print }'

list-depends: _depends
	@echo $(cwd)/$(category)/$(package)

list-depends-reverse:
	@for i in /var/log/packages/*_SBo; do \
		[ -f "$$i" ] || continue; \
		j="$${i##*/}"; \
		j="$${j%-*}"; \
		j="$${j%-*}"; \
		j="$${j%-*}"; \
		echo $$j; \
	done
endif # ifneq ($(cwd), ../..)

usage-msg:
ifneq ($(cwd), ../..)
	@echo "Usage: $(MAKE) command [command ...]"
else
	@echo "Usage: $(MAKE) [command ...]"
endif

help: usage-msg
	@echo "Commands:"; \
	for i in $(cmds); do \
		echo " $$i"; \
	done | sort

unpack:
	@echo "==> Unpacking..."; \
	cd $(cwd); \
	git checkout -f master

ifeq ($(cwd), .)
link:
	@echo "==> Linking */Makefile and */*/Makefile to Makefile..."; \
	cd $(cwd); \
	for i in $$(git ls-tree -d --name-only HEAD); do \
		if [ ! -L "$$i/Makefile" ]; then \
			ln -sr Makefile $$i 2>/dev/null; \
			echo " => $(path)$$i/Makefile@ linked"; \
		fi; \
		\
		found=false; \
		error=false; \
		for j in $$i/*; do \
			[ -d "$$j" ] || continue; \
			if [ ! -L "$$j/Makefile" ]; then \
				found=true; \
				ln -sr Makefile $$j 2>/dev/null; \
			fi; \
			if [ "$$?" != "0" ]; then \
				error=true; \
				if [ -t 1 ]; then \
					echo -e "\e[0;31m -> $$j/Makefile already exists\e[0m" >&2; \
				else \
					echo " -> $$j/Makefile already exists" >&2; \
				fi; \
			fi; \
		done; \
		if $$found && ! $$error; then \
			echo " => $(path)$$i/*/Makefile@ linked"; \
		fi; \
	done

delink:
	@echo "==> Unlinking */Makefile and */*/Makefile..."; \
	cd $(cwd); \
	for i in $$(git ls-tree -d --name-only HEAD); do \
		MAKEFILES="$$i/Makefile $$(for j in $$i/*; do \
			if [ -L "$$j/Makefile" ]; then \
				echo $$j/Makefile; \
			fi; \
		done)"; \
		if [ -n "$$MAKEFILES" ]; then \
			rm -Rf $$MAKEFILES; \
			if [ "$$?" = "0" ]; then \
				echo " => $(path)$$i/Makefile@ unlinked"; \
				echo " => $(path)$$i/*/Makefile@ unlinked"; \
			fi; \
		fi; \
	done
endif

search:
ifdef name
	@cd $(cwd); \
	for i in $$(git ls-tree -d --name-only HEAD); do \
		for j in $$i/*; do \
			echo "$${j#*/}"; \
		done | awk '{ if (index($$0, "$(name)")) print "$(path)'$$i'/" $$0 }'; \
	done || true
else
	@echo "Usage: $(MAKE) $@ name=package" >&2
endif

isearch:
ifdef name
	@cd $(cwd); \
	for i in $$(git ls-tree -d --name-only HEAD); do \
		for j in $$i/*; do \
			echo "$${j#*/}"; \
		done | awk '{ if (index(tolower($$0), "$(name)")) print "$(path)'$$i'/" $$0 }'; \
	done || true
else
	@echo "Usage: $(MAKE) $@ name=package" >&2
endif

esearch:
ifdef name
	@cd $(cwd); \
	for i in $$(git ls-tree -d --name-only HEAD); do \
		[ -d "$$i/$(name)" ] && echo $(path)$$i/$(name); \
	done || true
else
	@echo "Usage: $(MAKE) $@ name=package" >&2
endif

.PHONY: all usage-msg _depends $(cmds)
