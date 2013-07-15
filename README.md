Python bindings for nitro
=========================

[Nitro](http://gonitro.io/) is a library for painlessly writing scalable, fast,
and secure message-passing network applications.

This library provides a Python interface to the Nitro framework.

Installation
------------

If you don't have [Nitro](http://gonitro.io/) installed already, you'll need to
install it. The website links to the latest release. Alternatively, you can get
the source [from Github](https://github.com/bumptech/nitro).

Once you have the Nitro source, follow the installation instructions in the
`README`.

After Nitro is installed, simply run

    python setup.py install

and you're on your way.

Misc
----

If you want to do development on python-nitro, you'll need
[Cython](http://cython.org/) `>= 0.19.1` in order to generate C code from the
`.pyx` file.
