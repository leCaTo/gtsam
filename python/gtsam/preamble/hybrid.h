/* Please refer to:
 * https://pybind11.readthedocs.io/en/stable/advanced/cast/stl.html
 * These are required to save one copy operation on Python calls.
 *
 * NOTES
 * =================
 *
 * `PYBIND11_MAKE_OPAQUE` will mark the type as "opaque" for the pybind11
 * automatic STL binding, such that the raw objects can be accessed in Python.
 * Without this they will be automatically converted to a Python object, and all
 * mutations on Python side will not be reflected on C++.
 */
#include <pybind11/stl.h>

#ifdef GTSAM_ALLOCATOR_TBB
PYBIND11_MAKE_OPAQUE(std::vector<gtsam::Key, tbb::tbb_allocator<gtsam::Key>>);
#else
PYBIND11_MAKE_OPAQUE(std::vector<gtsam::Key>);
#endif

PYBIND11_MAKE_OPAQUE(std::vector<gtsam::GaussianFactor::shared_ptr>);
