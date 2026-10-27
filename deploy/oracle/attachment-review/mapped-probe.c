#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
int main(void) {
    char b[64] = {0};
    int f = open("/opt/oracle-data/probe.txt", O_RDONLY);
    if (f < 0 || read(f,b,sizeof(b)) != 15 || memcmp(b,"public fixture\n",15)) return 21;
    close(f);
    if (open("/opt/oracle-data/probe.txt", O_WRONLY) >= 0 || (errno != EACCES && errno != EROFS)) return 22;
    if (fcntl(7,F_GETFD) != -1 || errno != EBADF) return 23;
    f = open("/var/probe", O_WRONLY|O_CREAT|O_EXCL,0600);
    if (f < 0) return 24;
    close(f);
    puts("mapped-public-data-held");
    return 0;
}
