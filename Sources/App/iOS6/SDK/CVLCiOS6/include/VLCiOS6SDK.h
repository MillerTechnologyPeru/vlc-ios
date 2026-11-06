/*****************************************************************************
 * VLCiOS6SDK.h
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#ifndef VLC_IOS6_SDK_H
#define VLC_IOS6_SDK_H

#include <stdint.h>
#include "ObjCRuntime.h"

/* iOS functions the Embedded Swift overlays call (VLCiOS6SDK.c). Calls back
 * into Swift go through objcrt_call_aligned, as the Swift code is built for
 * bare-metal armv7 and expects an 8-byte aligned stack. */

/// mach_absolute_time in nanoseconds
uint64_t vlc6_uptime_nanoseconds(void);

/// dispatch_async on the global queue of `priority` (DISPATCH_QUEUE_PRIORITY_…)
void vlc6_dispatch_global_async(long priority, ObjCRTFunction function, void *context);

/// dispatch_after on the global queue of `priority`
void vlc6_dispatch_global_after(long priority, unsigned long milliseconds,
                                ObjCRTFunction function, void *context);

#endif
