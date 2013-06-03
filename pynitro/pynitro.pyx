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

    nitro_socket_t * nitro_socket_bind(char *location, nitro_sockopt_t *opt)
    nitro_socket_t * nitro_socket_connect(char *location, nitro_sockopt_t *opt)
    nitro_frame_t * nitro_recv(nitro_socket_t *s, int flags)
    int nitro_send(nitro_frame_t **fr, nitro_socket_t *s, int flags)
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

cdef class NitroFrame(object):
    _REUSE = 1
    cdef nitro_frame_t *frame
    def __init__(self, data, use_data=True):
        if use_data:
            assert type(data) is str
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

    def __dealloc__(self):
        nitro_frame_destroy(self.frame)

    def __str__(self):
        return ('<<%s>> with %d bytes' %
            (self.__class__.__name__, 
            len(self.data)))

    cdef sendto(self, nitro_socket_t *s, int flags, int *res):
        cdef int e = nitro_send(&self.frame, s, flags | self._REUSE)
        res[0] = e

_NITRO_EAGAIN = 7

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

        fr = nitro_recv(self.socket, cflags)

        if fr == NULL:
            e = nitro_error()
            if e == _NITRO_EAGAIN:
                raise NitroEmpty()

            raise NitroError(nitro_errmsg(e))

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
            if e == _NITRO_EAGAIN:
                raise NitroEmpty()

            raise NitroError(nitro_errmsg(e))

    def __dealloc__(self):
        pass
        # XXX destroy socket.. and what about
        # sockopt?
