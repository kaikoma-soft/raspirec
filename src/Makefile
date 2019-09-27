
PROGRAM = /usr/bin/sass

OBJS = public/nav.css public/overlaid.css public/style.css
all:  $(OBJS)

public/nav.css: views/nav.sass
	$(PROGRAM) --no-cache --sourcemap=none $< $@

public/overlaid.css: views/overlaid.sass
	$(PROGRAM) --no-cache --sourcemap=none $< $@

public/style.css: views/style.sass
	$(PROGRAM) --no-cache --sourcemap=none $< $@


