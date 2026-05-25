/**
 * perl-libxml-sax.h
 * $Id$
 */

#ifndef __PERL_LIBXML_SAX_H__
#define __PERL_LIBXML_SAX_H__

#ifdef __cplusplus
extern "C" {
#endif

#include <libxml/tree.h>

#ifdef __cplusplus
}
#endif


/*
 * auxiliary macro to serve as an croak(NULL)
 * unlike croak(NULL), this version does not produce
 * a warning (see the perlapi for the meaning of croak(NULL))
 *
 */

#define croak_obj Perl_croak(aTHX_ NULL)

/* Exception deferred from a libxml2 callback (GH #258).
 *
 * Callbacks registered with libxml2 (entity loaders, error handlers,
 * SAX handlers, I/O callbacks) must never croak(). croak() performs a
 * longjmp which skips over libxml2 cleanup code, causing memory leaks
 * or worse. Instead, callbacks store the exception here and signal an
 * error to libxml2 (xmlStopParser, error return value). The exception
 * is re-thrown after the parser operation completes and cleanup runs. */
extern SV *LibXML_pending_exception;

void LibXML_defer_exception(void);
void LibXML_defer_error(const char *msg);
void LibXML_rethrow_deferred(void);

/* has to be called in BOOT sequence */
void
PmmSAXInitialize(pTHX);

void
PmmSAXInitContext( xmlParserCtxtPtr ctxt, SV * parser, SV * saved_error );

void
PmmSAXCloseContext( xmlParserCtxtPtr ctxt );

xmlSAXHandlerPtr
PSaxGetHandler();

#endif   /* __PERL_LIBXML_SAX_H__ */
