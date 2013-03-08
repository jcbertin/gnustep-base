/** 
   Copyright (C) 2008-2009 Free Software Foundation, Inc.

   By: Richard Frith-Macdonald <richard@brainstorm.co.uk>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   $Date: 2009-02-23 20:42:32 +0000 (Mon, 23 Feb 2009) $ $Revision: 27962 $
*/

#import "common.h"

#import "GSRunLoopWatcher.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPort.h"

@implementation	GSRunLoopWatcher

- (void) dealloc
{
  [super dealloc];
}

- (id) initWithType: (RunLoopEventType)aType
	   receiver: (id)anObj
	       data: (void*)item
{
  _invalidated = NO;
  receiver = anObj;
  data = item;
  switch (aType)
    {
#if	defined(__MINGW__)
      case ET_HANDLE:   type = aType;   break;
      case ET_WINMSG:   type = aType;   break;
#else
      case ET_EDESC: 	type = aType;	break;
      case ET_RDESC: 	type = aType;	break;
      case ET_WDESC: 	type = aType;	break;
#endif
      case ET_RPORT: 	type = aType;	break;
      case ET_TRIGGER: 	type = aType;	break;
      default: 
	DESTROY(self);
	[NSException raise: NSInvalidArgumentException
		    format: @"NSRunLoop - unknown event type"];
    }

  if (![anObj respondsToSelector: @selector(receivedEvent:type:extra:forMode:)])
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"RunLoop listener has no event handling method"];
    }

  if ([anObj respondsToSelector: @selector(runLoopShouldBlock:)])
    {
      checkBlocking = YES;
    }
  return self;
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  if (checkBlocking == YES)
    {
      BOOL result = [(id)receiver runLoopShouldBlock: trigger];
      return result;
    }
  else if (type == ET_TRIGGER)
    {
      *trigger = YES;
      return NO;	// By default triggers may fire immediately
    }
  *trigger = YES;
  return YES;		// By default we must wait for input sources
}
@end

#if GS_HAVE_LIBDISPATCH_COMPAT
#import "GNUstepBase/NSThread+GNUstepBase.h"

#ifdef HAVE_POLL_F
#include <poll.h>
#endif

int _dispatch_get_main_queue_port_4GS(void);
void _dispatch_main_queue_callback_4GS(void);

static GSDispatchWatcher* _dispatchWatcherSharedInstance;

@implementation GSDispatchWatcher

+ (GSDispatchWatcher*)sharedInstance
{
  NSAssert1(GSIsMainThread(),
	    @"%@", NSInternalInconsistencyException);

  if (_dispatchWatcherSharedInstance == nil)
    {
      _dispatchWatcherSharedInstance = [[self alloc] init];
    }
  return _dispatchWatcherSharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone
{
  NSAssert1(GSIsMainThread(),
	    @"%@", NSInternalInconsistencyException);

  if (_dispatchWatcherSharedInstance == nil)
    {
      // assignment and return on first allocation
      _dispatchWatcherSharedInstance = [super allocWithZone:zone];
      return _dispatchWatcherSharedInstance;
    }
  return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *) __attribute__((unused)) zone
{
  return self;
}

- (id)retain
{
  return self;
}

- (NSUInteger)retainCount
{
  return UINT_MAX; // denotes an object that cannot be released
}

- (oneway void)release
{
  // do nothing
}

- (id)autorelease
{
  return self;
}

- (id)init
{
  NSAssert1(GSIsMainThread(),
	    @"%@", NSInternalInconsistencyException);

  int fd = _dispatch_get_main_queue_port_4GS();
  if ((self = [super initWithType:ET_RDESC
                         receiver:self
                             data:(void*)(intptr_t)fd]))
    {
      _receivedEventLastTime = YES;
      _mainQueueSafe = YES;
    }
  return self;
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  NSAssert1(GSIsMainThread(),
	    @"%@", NSInternalInconsistencyException);

  if (!_mainQueueSafe)
    {
      *trigger = NO;
      return NO;
    }
  else if (!_receivedEventLastTime)
    {
#ifdef	HAVE_POLL_F
      struct pollfd pfd =
	{
          .fd = (int)(intptr_t)self->data,
	  .events = POLLIN,
	  .revents = 0
	};
      int rc = poll(&pfd, 1, 0);
      if (0 < rc)
	{
          *trigger = YES;
          return NO;
        }
#else /* HAVE_POLL_F */
      int fd = (int)(intptr_t)self->data;
      struct timeval timeout =
	{
	  .tv_sec = 0,
	  .tv_usec = 0
	};
      fd_set fds;
      FD_ZERO(&fds);
      FD_SET(fd, &fds);
      int rc = select(fd+1, &fds, NULL, NULL, &timeout);
      if (0 < rc)
	{
          *trigger = YES;
          return NO;
        }
#endif /* HAVE_POLL_F */
    }

  _receivedEventLastTime = NO;
  *trigger = NO;
  return YES;
}

- (void)receivedEvent: (void*) __attribute__((unused)) data
                 type: (RunLoopEventType) __attribute__((unused)) type
                extra: (void*) __attribute__((unused)) extra
              forMode: (NSString*) __attribute__((unused)) mode
{
  NSAssert1(GSIsMainThread(),
	    @"%@", NSInternalInconsistencyException);

  /* We don't care how much we read. Dispatch callback will pump all
   * the jobs pushed on the main queue.
   * The descriptor is non-blocking ... so it's safe to ask for more
   * bytes than are available.
   */
  char buf[BUFSIZ];
  int inputFd = (int)(intptr_t)self->data;
  while (read(inputFd, buf, sizeof(buf)) > 0) {}

  _mainQueueSafe = NO;
  _dispatch_main_queue_callback_4GS();
  _mainQueueSafe = YES;
  _receivedEventLastTime = YES;
}
@end
#endif /* GS_HAVE_LIBDISPATCH_COMPAT */
