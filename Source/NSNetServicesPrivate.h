/* NSNetServicesPrivate
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by:  Jean-Charles BERTIN <jc.bertin@axinoe.com>
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02111 USA.
*/ 

#ifndef __NSNetServicestPrivate_h_
#define __NSNetServicestPrivate_h_

/*
 * NSNetService delegate methods:
 */
@interface      NSNetService (Delegate)
- (void) netServiceWillResolve: (NSNetService*)service;
- (void) netService: (NSNetService*)service
      didNotResolve: (NSDictionary*)errorDict;
- (void) netServiceDidResolveAddress: service;
- (void) netServiceDidStop: (NSNetService*)service;
- (void) netServiceWillPublish: (NSNetService*)service;
- (void) netService: (NSNetService*)service
      didNotPublish: (NSDictionary*)errorDict;
- (void) netServiceDidPublish: (NSNetService*)service;
@end

/*
 * NSNetServiceBrowser delegate methods:
 */
@interface      NSNetServiceBrowser (Delegate)
- (void)netServiceBrowserWillSearch: (NSNetServiceBrowser*)aBrowser;
- (void)netServiceBrowserDidStopSearch: (NSNetServiceBrowser*)aBrowser;
- (void)netServiceBrowser: (NSNetServiceBrowser*)aBrowser
             didNotSearch: (NSDictionary*)errorDict;
- (void)netServiceBrowser: (NSNetServiceBrowser*)aBrowser
            didFindDomain: (NSString*)theDomain
               moreComing: (BOOL)moreComing;
- (void)netServiceBrowser: (NSNetServiceBrowser*)aBrowser
          didRemoveDomain: (NSString*)theDomain
			   moreComing: (BOOL)moreComing;
- (void)netServiceBrowser: (NSNetServiceBrowser*)aBrowser
           didFindService: (NSNetService*)theService
			   moreComing: (BOOL)moreComing;
- (void)netServiceBrowser: (NSNetServiceBrowser*)aBrowser
         didRemoveService: (NSNetService*)theService
			   moreComing: (BOOL)moreComing;
@end

#endif

