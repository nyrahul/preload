TGT=libhook.so

all:
	gcc -Wall -fPIC $(wildcard src/*.c) -shared -o ${TGT} -ldl

clean:
	rm -f ${TGT}
