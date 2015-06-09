PARTS=$(sort $(dir $(wildcard */)))

all:
	-@for s in $(PARTS); do make -C $$s; done

clean:
	-@for s in $(PARTS); do make -C $$s clean; done

.PHONY: clean
