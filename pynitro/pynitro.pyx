ctypedef unsigned char uint8_t
ctypedef int int32_t
ctypedef long long int64_t
ctypedef unsigned int uint32_t
ctypedef unsigned long long uint64_t

cdef extern from "nitro.h":
    ctypedef struct nitro_frame_t:
        pass
    ctypedef struct nitro_socket_t:
        pass
    ctypedef struct nitro_sockopt_t:
        pass

    void nitro_runtime_start()

    nitro_frame_t *nitro_frame_new_copy(char *d,
        uint32_t size)
    uint8_t *nitro_frame_data(nitro_frame_t *f)
    uint32_t nitro_frame_size(nitro_frame_t *f)
    void nitro_frame_destroy(nitro_frame_t *f)
    void nitro_frame_clear(nitro_frame_t *f)

    nitro_socket_t * nitro_socket_bind(char *location, nitro_sockopt_t *opt)
    nitro_socket_t * nitro_socket_connect(char *location, nitro_sockopt_t *opt)
    void nitro_socket_close(nitro_socket_t *s)

    nitro_frame_t * nitro_recv(nitro_socket_t *s, int flags) nogil
    int nitro_send(nitro_frame_t **fr, nitro_socket_t *s, int flags) nogil
    int nitro_reply(nitro_frame_t *snd, nitro_frame_t **fr, nitro_socket_t *s, int flags) nogil
    int nitro_relay_fw(nitro_frame_t *snd, nitro_frame_t **fr, nitro_socket_t *s, int flags) nogil
    int nitro_relay_bk(nitro_frame_t *snd, nitro_frame_t **fr, nitro_socket_t *s, int flags) nogil
    int nitro_sub(nitro_socket_t *s, uint8_t *d, size_t l)
    int nitro_unsub(nitro_socket_t *s, uint8_t *d, size_t l)
    int nitro_pub(nitro_frame_t **fr,
        uint8_t *k, size_t l, nitro_socket_t *s, int flags) nogil

    int nitro_eventfd(nitro_socket_t *s)

    int nitro_error()
    char *nitro_errmsg(int err_code)

    nitro_sockopt_t *nitro_sockopt_new()
    void nitro_sockopt_set_hwm(nitro_sockopt_t *opt, int hwm)
    void nitro_sockopt_set_want_eventfd(nitro_sockopt_t *opt, int want_eventfd)

nitro_runtime_start()

class NitroError(Exception):
    pass

class NitroEmpty(Exception):
    pass

class NitroFull(Exception):
    pass

cdef class NitroFrame(object):
    _REUSE = 1
    cdef nitro_frame_t *frame
    def __init__(self, data, use_data=True):
        self.frame = NULL
        if use_data:
            assert type(data) is str, ("Expected NitroFrame argument to be str, was %s" % (type(data),))
            self.frame = nitro_frame_new_copy(
                data, len(data))

    cdef set_frame(self, nitro_frame_t *f):
        self.frame = f

    @property
    def data(self):
        cdef uint8_t *cd
        cdef size_t cdl
        cd = nitro_frame_data(self.frame)
        cdl = nitro_frame_size(self.frame)
        return cd[:cdl]

    def clear_data(self):
        nitro_frame_clear(self.frame)

    def __dealloc__(self):
        if self.frame:
            nitro_frame_destroy(self.frame)

    def __str__(self):
        return ('<<%s>> with %d bytes' %
            (self.__class__.__name__, 
            len(self.data)))

    cdef sendto(self, nitro_socket_t *s, int flags, int *res):
        cdef nitro_frame_t *f = self.frame
        cdef int e
        flags |= self._REUSE
        with nogil:
            e = nitro_send(&f, s, flags)
            res[0] = e

    cdef replyto(self, nitro_frame_t *snd, nitro_socket_t *s, int flags, int *res):
        cdef nitro_frame_t *f = self.frame
        cdef int e
        flags |= self._REUSE
        with nogil:
            e = nitro_reply(snd, &f, s, flags)
            res[0] = e

    cdef relayfwto(self, nitro_frame_t *snd, nitro_socket_t *s, int flags, int *res):
        cdef nitro_frame_t *f = self.frame
        cdef int e
        flags |= self._REUSE
        with nogil:
            e = nitro_relay_fw(snd, &f, s, flags)
            res[0] = e

    cdef relaybkto(self, nitro_frame_t *snd, nitro_socket_t *s, int flags, int *res):
        cdef nitro_frame_t *f = self.frame
        cdef int e
        flags |= self._REUSE
        with nogil:
            e = nitro_relay_bk(snd, &f, s, flags)
            res[0] = e

    cdef pubto(self, uint8_t *k, size_t l, nitro_socket_t *s, int flags, int *res):
        cdef nitro_frame_t *f = self.frame
        cdef int e
        flags |= self._REUSE
        with nogil:
            e = nitro_pub(&f, k, l, s, flags)
            res[0] = e

_NITRO_EAGAIN = 8

cdef class NitroSocket(object):
    NOWAIT = 2
    cdef nitro_socket_t *socket
    cdef nitro_sockopt_t *opt
    cdef int want_eventfd
    cdef int eventfd
    def __init__(self, hwm=None, linger=None,
        reconnect_interval=None, max_message_size=None,
        want_eventfd=None):
        self.socket = NULL

        self.opt = nitro_sockopt_new()

        self.want_eventfd = int(want_eventfd == True)

        if hwm is not None:
            nitro_sockopt_set_hwm(self.opt, hwm)
        if want_eventfd is not None:
            nitro_sockopt_set_want_eventfd(self.opt, want_eventfd)

        # XXX more

    def fileno(self):
        return self.eventfd

    def bind(self, location):
        cdef char *error
        self.socket = nitro_socket_bind(location, self.opt)
        if self.socket == NULL:
            error = nitro_errmsg(nitro_error())
            raise NitroError(error)

        if self.want_eventfd:
            self.eventfd = nitro_eventfd(self.socket)

    def connect(self, location):
        cdef char *error
        self.socket = nitro_socket_connect(location, self.opt)
        if self.socket == NULL:
            error = nitro_errmsg(nitro_error())
            raise NitroError(error)

        if self.want_eventfd:
            self.eventfd = nitro_eventfd(self.socket)

    def recv(self, flags=None):
        cdef int cflags
        cdef int e
        cdef nitro_frame_t *fr

        if flags:
            cflags = flags
        else:
            cflags = 0

        cdef nitro_socket_t *s = self.socket
        with nogil:
            fr = nitro_recv(s, cflags)

        if fr == NULL:
            e = nitro_error()
            if e == _NITRO_EAGAIN:
                raise NitroEmpty()

            error = nitro_errmsg(e)
            raise NitroError(error)

        ofr = NitroFrame(None, False)
        ofr.set_frame(fr)

        return ofr

    def send(self, NitroFrame o, flags=None):
        cdef int cflags
        cdef int e

        if flags:
            cflags = flags
        else:
            cflags = 0

        o.sendto(self.socket, cflags, &e)

        if e < 0:
            e = nitro_error()
            if e == _NITRO_EAGAIN:
                raise NitroFull()

            error = nitro_errmsg(e)
            raise NitroError(error)

    def reply(self, NitroFrame snd, NitroFrame o, flags=None):
        cdef int cflags
        cdef int e

        if flags:
            cflags = flags
        else:
            cflags = 0

        o.replyto(snd.frame, self.socket, cflags, &e)

        if e < 0:
            e = nitro_error()
            if e == _NITRO_EAGAIN:
                raise NitroFull()

            error = nitro_errmsg(e)
            raise NitroError(error)

    def relay_fw(self, NitroFrame snd, NitroFrame o, flags=None):
        cdef int cflags
        cdef int e

        if flags:
            cflags = flags
        else:
            cflags = 0

        o.relayfwto(snd.frame, self.socket, cflags, &e)

        if e < 0:
            e = nitro_error()
            if e == _NITRO_EAGAIN:
                raise NitroFull()

            error = nitro_errmsg(e)
            raise NitroError(error)

    def relay_bk(self, NitroFrame snd, NitroFrame o, flags=None):
        cdef int cflags
        cdef int e

        if flags:
            cflags = flags
        else:
            cflags = 0

        o.relaybkto(snd.frame, self.socket, cflags, &e)

        if e < 0:
            e = nitro_error()
            if e == _NITRO_EAGAIN:
                raise NitroFull()

            error = nitro_errmsg(e)
            raise NitroError(error)

    def sub(self, prefix):
        cdef int r
        assert type(prefix) is str
        r = nitro_sub(self.socket, prefix, len(prefix))
        if r < 0:
            error = nitro_errmsg(nitro_error())
            raise NitroError(error)

    def unsub(self, prefix):
        cdef int r
        assert type(prefix) is str
        r = nitro_unsub(self.socket, prefix, len(prefix))
        if r < 0:
            error = nitro_errmsg(nitro_error())
            raise NitroError(error)

    def pub(self, k, NitroFrame o, flags=None):
        cdef int cflags
        cdef int e

        if flags:
            cflags = flags
        else:
            cflags = 0

        o.pubto(k, len(k), self.socket, cflags, &e)

        if e < 0:
            error = nitro_errmsg(nitro_error())
            raise NitroError(error)
        return e

    def __dealloc__(self):
        if self.socket:
            nitro_socket_close(self.socket)
