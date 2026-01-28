#!/usr/bin/env python3
"""Test for the installation of necessary modules."""

def test_imports():
    """Run the import statements and print messages about them not being correct."""
    mod_problems = False
    try:
        import dadi
        dadi_exists = True
    except ImportError:
        dadi_exists = False

    try:
        import matplotlib
        matplotlib.use('agg')
        import matplotlib.pylab as plt
        matplotlib_exists = True
    except ImportError:
        matplotlib_exists = False

    try:
        import scipy
        from packaging import version
        scipy_exists = True
        scipy_version = version.parse(scipy.__version__) >= version.parse("1.11.4")
    except ImportError:
        scipy_exists = False
        scipy_version = False
    except Exception:
        scipy_exists = True
        scipy_version = False

    if not all([dadi_exists, matplotlib_exists, scipy_exists, scipy_version]):
        print('Some module errors were found on your system:\n')
        mod_problems = True
    if not dadi_exists:
        print('You do not have dadi installed. Please download it from')
        print('https://bitbucket.org/gutenkunstlab/dadi and install it.\n')
    if not matplotlib_exists:
        print('You do not have matplotlib installed. Please install it with')
        print('"pip install matplotlib".\n')
    if not scipy_exists and not scipy_version:
        print('You do not have SciPy version 1.11.4 or newer installed. Please install')
        print('it with "pip install \"scipy>=1.11.4\"".\n')
    if scipy_exists and not scipy_version:
        import scipy
        print(f'Your scipy version ({scipy.__version__}) is incompatible')
        print('with this script. Please install version 1.11.4 or newer by running')
        print('"pip install \"scipy>=1.11.4\""\n')
    return mod_problems
