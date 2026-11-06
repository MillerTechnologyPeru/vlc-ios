/*****************************************************************************
 * VLCiOS6SDK.c
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#include "VLCiOS6SDK.h"

#include <dispatch/dispatch.h>
#include <mach/mach_time.h>
#include <stdlib.h>

uint64_t vlc6_uptime_nanoseconds(void)
{
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0)
        mach_timebase_info(&timebase);
    return mach_absolute_time() * timebase.numer / timebase.denom;
}

struct work {
    ObjCRTFunction function;
    void *context;
};

static void run(void *data)
{
    struct work *work = data;
    objcrt_call_aligned((const void *)work->function, (unsigned long)work->context, 0, 0, 0, 0);
    free(work);
}

static struct work *make_work(ObjCRTFunction function, void *context)
{
    struct work *work = malloc(sizeof *work);
    if (work == NULL)
        abort();
    work->function = function;
    work->context = context;
    return work;
}

void vlc6_dispatch_global_async(long priority, ObjCRTFunction function, void *context)
{
    dispatch_async_f(dispatch_get_global_queue(priority, 0), make_work(function, context), run);
}

void vlc6_dispatch_global_after(long priority, unsigned long milliseconds,
                                ObjCRTFunction function, void *context)
{
    dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, (int64_t)milliseconds * NSEC_PER_MSEC),
                     dispatch_get_global_queue(priority, 0), make_work(function, context), run);
}
