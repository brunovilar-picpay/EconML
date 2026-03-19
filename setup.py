from setuptools import setup
from setuptools.extension import Extension
import os
import re
from glob import glob

# Versão do pacote
version = '0.16.0+gdaiha.1'

def get_numpy_include():
    """Get numpy include dir, handling the case where numpy isn't yet installed."""
    try:
        import numpy as np
        return np.get_include()
    except ImportError:
        # Fallback: numpy will be installed by build-system.requires
        # and this function will be called again
        return ""

def get_extensions():
    """Build list of C/Cython extensions."""
    numpy_include = get_numpy_include()
    
    pyx_files = glob("econml/**/*.pyx", recursive=True)
    c_files = glob("econml/**/*.c", recursive=True)

    # If both a .pyx and a .c file exist, we assume the .c file is up to date
    pyx_files = [f for f in pyx_files if (os.path.splitext(f)[0] + ".c") not in c_files]

    include_dirs = [numpy_include] if numpy_include else []

    c_extensions = [
        Extension(
            os.path.splitext(f)[0].replace(os.sep, '.'),
            [f],
            include_dirs=include_dirs,
            define_macros=[("NPY_NO_DEPRECATED_API", "NPY_1_7_API_VERSION")]
        )
        for f in c_files
    ]

    if pyx_files:
        try:
            from Cython.Build import cythonize
            pyx_extensions = cythonize(
                [Extension("*", pyx_files, include_dirs=include_dirs)],
                language_level="3"
            )
        except ImportError:
            # Cython not available — skip .pyx files, rely on .c files only
            pyx_extensions = []
    else:
        pyx_extensions = []

    return c_extensions + pyx_extensions

setup(
    ext_modules=get_extensions(),
    zip_safe=False,
    version=version,
)
