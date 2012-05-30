EXTRA_DIST = lib sbin

ME=cif-protocol
BUILD=@BUILD@
TARGETS=@TARGETS@
SNAPSHOT=$(ME)-$(BUILD)
PROTOFILES=build/*.proto
THRIFTFILES=build/*.thrift

SUBDIRS=src

all: prepare $(TARGETS)

prepare:	
	[ -d build ] || mkdir build
	cp src/*.thrift src/*.proto build/

prebuilts:
	cp prebuilt/*.thrift prebuilt/*.proto build/


install:
	@echo "Please read the README before beginning your installation."



pb_perl:
	$(PERL) sbin/generate_perl_bindings.pl
	-( cd perl/ && $(PERL) Makefile.PL && make test)

thrift_perl:




pb_cpp:
	[ -d pb-cpp ] || mkdir pb-cpp
	$(PROTOC) --cpp_out=pb-cpp $(PROTOFILES)

thrift_cpp:


pb_C:
	@echo "Protocol Buffers for C not available"

thrift_C:


pb_python:
	[ -d pb-python ] || mkdir pb-python
	$(PROTOC) --python_out=pb-python $(PROTOFILES) 

thrift_python:
	@echo "not implemented yet..."

clean:
	rm Makefile
	rm config.log
	rm config.status
	rm -fr build
	
realclean: clean
	rm Makefile.in
	rm configure
	rm aclocal.m4

reconf:
	autoreconf -vf

snapshot:
	git archive --format=tar --prefix=$(BUILD)/ $(BUILD) | gzip > $(SNAPSHOT).tar.gz
