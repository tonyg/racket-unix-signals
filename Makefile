PACKAGENAME=unix-signals
COLLECTS=unix-signals

all: setup

clean:
	find . -name compiled -type d | xargs rm -rf
	rm -rf unix-signals/doc
	rm -rf htmldocs

setup:
	raco setup $(COLLECTS)

link:
	raco pkg install --link -n $(PACKAGENAME) $$(pwd)

unlink:
	raco pkg remove $(PACKAGENAME)

htmldocs:
	raco scribble \
		--html \
		--dest htmldocs \
		--dest-name index \
		++main-xref-in \
		--redirect-main http://docs.racket-lang.org/ \
		\
		unix-signals/unix-signals.scrbl

pages:
	@(git branch -v | grep -q gh-pages || (echo local gh-pages branch missing; false))
	@echo
	@git branch -av | grep gh-pages
	@echo
	@(echo 'Is the branch up to date? Press enter to continue.'; read dummy)
	git clone -b gh-pages . pages

publish: htmldocs pages
	rm -rf pages/*
	cp -r htmldocs/. pages/.
	(cd pages; git add -A)
	-(cd pages; git commit -m "Update $$(date +%Y%m%d%H%M%S)")
	(cd pages; git push)
	rm -rf pages
