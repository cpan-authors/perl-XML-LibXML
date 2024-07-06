/* $Id: Devel.xs 20 2011-10-11 02:05:01Z jo $
 *
 * This is free software, you may use it and distribute it under the same terms as
 * Perl itself.
 *
 * Copyright 2011 Joachim Zobel
 *
 * This module gives external access to the functions needed to create
 * and use XML::LibXML::Nodes from C functions. These functions are made
 * accessible from Perl to have cleaner dependencies.
 * The idea is to pass xmlNode * pointers (as typemapped void *) to and
 * from Perl and call the functions that turns them to and from
 * XML::LibXML::Nodes there.
 *
 * Be aware that using this module gives you the ability to easily create
 * segfaults and memory leaks.
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


#include <stdlib.h>

/* XML::LibXML stuff */
#include <libxml/xmlmemory.h>
#include "perl-libxml-mm.h"

#undef NDEBUG
#include <assert.h>

/* libxml2's custom memory-allocator and tracking API was removed in 2.14.
 * Apple SDKs (macOS 15.4 / iOS 18.4 / etc.) pre-flag it as deprecated even
 * while shipping libxml2 < 2.14. Only expose debug_memory() and mem_used()
 * when the API is genuinely supported by the installed libxml2. */
#if LIBXML_VERSION < 21400 && !defined(LIBXML_HAS_DEPRECATED_MEMORY_ALLOCATION_FUNCTIONS)
#define HAVE_LIBXML_MEMORY_DEBUG 1
#endif

#ifdef HAVE_LIBXML_MEMORY_DEBUG
static int debug_memory()
{
    return xmlMemSetup(xmlMemFree,
                       xmlMemMalloc,
                       xmlMemRealloc,
                       xmlMemStrdup);
}
#endif

MODULE = XML::LibXML::Devel		PACKAGE = XML::LibXML::Devel

PROTOTYPES: DISABLE

BOOT:
#ifdef HAVE_LIBXML_MEMORY_DEBUG
    if (getenv("DEBUG_MEMORY")) {
        debug_memory();
    }
#endif



SV*
node_to_perl( n, o = NULL )
        void * n
        void * o
    PREINIT:
        xmlNode *node = n;
        xmlNode *owner = o;
    CODE:
        RETVAL = PmmNodeToSv(node , owner?owner->_private:NULL );
    OUTPUT:
        RETVAL

void *
node_from_perl( sv )
        SV *sv
    PREINIT:
        xmlNode *n = PmmSvNodeExt(sv, 0);
    CODE:
        RETVAL = n;
    OUTPUT:
        RETVAL

void
refcnt_inc( n )
        void *n
    PREINIT:
        xmlNode *node = n;
    CODE:
        PmmREFCNT_inc(((ProxyNode *)(node->_private)));

int
refcnt_dec( n )
        void *n
    PREINIT:
        xmlNode *node = n;
    CODE:
        RETVAL = PmmREFCNT_dec(((ProxyNode *)(node->_private)));
    OUTPUT:
        RETVAL

int
refcnt( n )
        void *n
    PREINIT:
        xmlNode *node = n;
    CODE:
        RETVAL = PmmREFCNT(((ProxyNode *)(node->_private)));
    OUTPUT:
        RETVAL

int
fix_owner( n, p )
        void * n
        void * p
    PREINIT:
        xmlNode *node = n;
        xmlNode *parent = p;
    CODE:
        RETVAL = PmmFixOwner(node->_private , parent->_private);
    OUTPUT:
        RETVAL

#ifdef HAVE_LIBXML_MEMORY_DEBUG

int
mem_used()
    CODE:
        RETVAL = xmlMemUsed();
    OUTPUT:
        RETVAL

#endif


