
#ifndef __BUSY_BARRIER__
#define __BUSY_BARRIER__

#include <atomic>
#include <unistd.h>
#include <algorithm>

// a busy waiting progress based barrier
class progress_barrier
{
    std::atomic_int64_t progress;

public:
    progress_barrier() : progress(0) {}
    void wait(int64_t next, int max_backoff)
    {
        progress.fetch_add(1);
        auto temp = progress.load();
        int backoff = 1;
        while (temp < next)
        {
            temp = progress.load();
            if (max_backoff)
            {
                usleep(backoff++);
                backoff = std::min(max_backoff, backoff);
            }
        }
    }
};

#endif