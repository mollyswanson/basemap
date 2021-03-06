# Make changes to this file, not the c-wrappers that Pyrex generates.

include "_pyproj.pxi"

cdef class Geod:
    cdef GEODESIC_T geodesic_t
    cdef public object geodstring
    cdef public object proj_version
    cdef char *geodinitstring

    def __cinit__(self, geodstring):
        cdef GEODESIC_T GEOD_T
        # setup geod initialization string.
        self.geodstring = geodstring
        bytestr = _strencode(geodstring)
        self.geodinitstring = bytestr
        # initialize projection
        self.geodesic_t = GEOD_init_plus(self.geodinitstring, &GEOD_T)[0]
        if pj_errno != 0:
            raise RuntimeError(pj_strerrno(pj_errno))
        self.proj_version = PJ_VERSION/100.

    def __reduce__(self):
        """special method that allows pyproj.Geod instance to be pickled"""
        return (self.__class__,(self.geodstring,))

    def _fwd(self, object lons, object lats, object az, object dist, radians=False):
        """
 forward transformation - determine longitude, latitude and back azimuth 
 of a terminus point given an initial point longitude and latitude, plus
 forward azimuth and distance.
 if radians=True, lons/lats are radians instead of degrees.
        """
        cdef Py_ssize_t buflenlons, buflenlats, buflenaz, buflend, ndim, i
        cdef double *lonsdata, *latsdata, *azdata, *distdata
        cdef void *londata, *latdata, *azdat, *distdat
        # if buffer api is supported, get pointer to data buffers.
        if PyObject_AsWriteBuffer(lons, &londata, &buflenlons) <> 0:
            raise RuntimeError
        if PyObject_AsWriteBuffer(lats, &latdata, &buflenlats) <> 0:
            raise RuntimeError
        if PyObject_AsWriteBuffer(az, &azdat, &buflenaz) <> 0:
            raise RuntimeError
        if PyObject_AsWriteBuffer(dist, &distdat, &buflend) <> 0:
            raise RuntimeError
        # process data in buffer
        if not buflenlons == buflenlats == buflenaz == buflend:
            raise RuntimeError("Buffer lengths not the same")
        ndim = buflenlons//_doublesize
        lonsdata = <double *>londata
        latsdata = <double *>latdata
        azdata = <double *>azdat
        distdata = <double *>distdat
        for i from 0 <= i < ndim:
            if radians:
                self.geodesic_t.p1.v = lonsdata[i]
                self.geodesic_t.p1.u = latsdata[i]
                self.geodesic_t.ALPHA12 = azdata[i]
                self.geodesic_t.DIST = distdata[i]
            else:
                self.geodesic_t.p1.v = _dg2rad*lonsdata[i]
                self.geodesic_t.p1.u = _dg2rad*latsdata[i]
                self.geodesic_t.ALPHA12 = _dg2rad*azdata[i]
                self.geodesic_t.DIST = distdata[i]
            geod_pre(&self.geodesic_t)
            if pj_errno != 0:
                raise RuntimeError(pj_strerrno(pj_errno))
            geod_for(&self.geodesic_t)
            if pj_errno != 0:
                raise RuntimeError(pj_strerrno(pj_errno))
            # check for NaN.
            if self.geodesic_t.ALPHA21 != self.geodesic_t.ALPHA21:
                raise ValueError('undefined inverse geodesic (may be an antipodal point)')
            if radians:
                lonsdata[i] = self.geodesic_t.p2.v
                latsdata[i] = self.geodesic_t.p2.u
                azdata[i] = self.geodesic_t.ALPHA21
            else:
                lonsdata[i] = _rad2dg*self.geodesic_t.p2.v
                latsdata[i] = _rad2dg*self.geodesic_t.p2.u
                azdata[i] = _rad2dg*self.geodesic_t.ALPHA21

    def _inv(self, object lons1, object lats1, object lons2, object lats2, radians=False):
        """
 inverse transformation - return forward and back azimuths, plus distance
 between an initial and terminus lat/lon pair.
 if radians=True, lons/lats are radians instead of degrees.
        """
        cdef Py_ssize_t buflenlons, buflenlats, buflenaz, buflend, ndim, i
        cdef double *lonsdata, *latsdata, *azdata, *distdata
        cdef void *londata, *latdata, *azdat, *distdat
        # if buffer api is supported, get pointer to data buffers.
        if PyObject_AsWriteBuffer(lons1, &londata, &buflenlons) <> 0:
            raise RuntimeError
        if PyObject_AsWriteBuffer(lats1, &latdata, &buflenlats) <> 0:
            raise RuntimeError
        if PyObject_AsWriteBuffer(lons2, &azdat, &buflenaz) <> 0:
            raise RuntimeError
        if PyObject_AsWriteBuffer(lats2, &distdat, &buflend) <> 0:
            raise RuntimeError
        # process data in buffer
        if not buflenlons == buflenlats == buflenaz == buflend:
            raise RuntimeError("Buffer lengths not the same")
        ndim = buflenlons//_doublesize
        lonsdata = <double *>londata
        latsdata = <double *>latdata
        azdata = <double *>azdat
        distdata = <double *>distdat
        errmsg = 'undefined inverse geodesic (may be an antipodal point)'
        for i from 0 <= i < ndim:
            if radians:
                self.geodesic_t.p1.v = lonsdata[i]
                self.geodesic_t.p1.u = latsdata[i]
                self.geodesic_t.p2.v = azdata[i]
                self.geodesic_t.p2.u = distdata[i]
            else:
                self.geodesic_t.p1.v = _dg2rad*lonsdata[i]
                self.geodesic_t.p1.u = _dg2rad*latsdata[i]
                self.geodesic_t.p2.v = _dg2rad*azdata[i]
                self.geodesic_t.p2.u = _dg2rad*distdata[i]
            geod_inv(&self.geodesic_t)
            if self.geodesic_t.DIST != self.geodesic_t.DIST: # check for NaN
                raise ValueError('undefined inverse geodesic (may be an antipodal point)')
            if pj_errno != 0:
                raise RuntimeError(pj_strerrno(pj_errno))
            if radians:
                lonsdata[i] = self.geodesic_t.ALPHA12
                latsdata[i] = self.geodesic_t.ALPHA21
            else:
                lonsdata[i] = _rad2dg*self.geodesic_t.ALPHA12
                latsdata[i] = _rad2dg*self.geodesic_t.ALPHA21
            azdata[i] = self.geodesic_t.DIST

    def _npts(self, double lon1, double lat1, double lon2, double lat2, int npts, radians=False):
        """
 given initial and terminus lat/lon, find npts intermediate points."""
        cdef int i
        cdef double del_s
        if radians:
            self.geodesic_t.p1.v = lon1
            self.geodesic_t.p1.u = lat1
            self.geodesic_t.p2.v = lon2
            self.geodesic_t.p2.u = lat2
        else:
            self.geodesic_t.p1.v = _dg2rad*lon1
            self.geodesic_t.p1.u = _dg2rad*lat1
            self.geodesic_t.p2.v = _dg2rad*lon2
            self.geodesic_t.p2.u = _dg2rad*lat2
        # do inverse computation to set azimuths, distance.
        geod_inv(&self.geodesic_t)
        # set up some constants needed for forward computation.
        geod_pre(&self.geodesic_t)
        # distance increment.
        del_s = self.geodesic_t.DIST/(npts+1)
        # initialize output tuples.
        lats = ()
        lons = ()
        # loop over intermediate points, compute lat/lons.
        for i from 1 <= i < npts+1:
            self.geodesic_t.DIST = i*del_s
            geod_for(&self.geodesic_t)
            if radians:
                lats = lats + (self.geodesic_t.p2.u,)
                lons = lons + (self.geodesic_t.p2.v,)
            else:
                lats = lats + (_rad2dg*self.geodesic_t.p2.u,)
                lons = lons + (_rad2dg*self.geodesic_t.p2.v,)
        return lons, lats   

cdef _strencode(pystr,encoding='ascii'):
    # encode a string into bytes.  If already bytes, do nothing.
    try:
        return pystr.encode(encoding)
    except AttributeError:
        return pystr # already bytes?
