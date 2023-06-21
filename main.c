#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <signal.h>

void process(uint8_t state)
{
    if (state & 0x80)
    {
        raise(SIGABRT);
    }
}

int main(int argc, char *argv[])
{
    if (argc < 2)
    {
        printf("%x\n", main);
        return 1;
    }
    
    char *filename = argv[1];
    FILE *f = fopen(filename, "r");
    if (!f)
    {
        return 1;
    }

    uint8_t state = 0;
    uint32_t bytes_read = fread(&state, 1, sizeof(state), f);
    if (bytes_read < sizeof(state))
    {
        return 1;
    }

    process(state);

    return 0;
}