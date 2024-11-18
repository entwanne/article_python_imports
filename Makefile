PDF = article_mecanique_imports.pdf
ZIP = article_mecanique_imports.zip
SRC = $(shell find src -name "*.md" | sort -V)

FLAGS = --top-level-division=part --toc --pdf-engine=xelatex

GEN = $(PDF) $(ZIP)

$(PDF):	$(SRC)
	pandoc -V lang=fr -V geometry:margin=1in -V colorlinks=true $^ -o $@ $(FLAGS)

$(ZIP): $(SRC)
	./gen_archive.py $@ $^

all: $(GEN)

clean:
	rm -f $(GEN)

re:	clean $(GEN)

.PHONY:	all clean re
