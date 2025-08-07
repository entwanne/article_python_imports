PDF = article_mecanique_imports.pdf
ZIP = article_mecanique_imports.zip
SRC = $(shell find src -name "*.md" | sort -V)
IMG_ZIP = images.zip
IMG_SRC = img/full_import_workflow.png img/simple_import_workflow.png

FLAGS = --top-level-division=part --toc --pdf-engine=xelatex

GEN = $(PDF) $(ZIP) $(IMG_ZIP)

$(PDF):	$(SRC)
	pandoc -V lang=fr -V geometry:margin=1in -V colorlinks=true $^ -o $@ $(FLAGS)

$(ZIP): $(SRC)
	./gen_archive.py $@ $^

img/%.png: img/%.svg
	inkscape $< -d 150 -o $@

$(IMG_ZIP): $(IMG_SRC)
	zip $@ $^

all: $(GEN)

clean:
	rm -f $(GEN)

re:	clean $(GEN)

.PHONY:	all clean re
