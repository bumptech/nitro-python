all:
	cython pynitro/pynitro.pyx
	python setup.py develop
