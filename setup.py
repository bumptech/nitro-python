from setuptools import setup, Extension
import os

cflags = os.popen("pkg-config --cflags nitro").read().strip()
ldflags = os.popen("pkg-config --libs nitro").read().strip()
assert (cflags and ldflags), "install nitro!"

sourcefiles = ["pynitro/pynitro.c"]

setup(
        name="pynitro",
        version="0.2",
        packages=["pynitro"],
        ext_modules=[Extension("pynitro.pynitro", sources=sourcefiles,
        extra_compile_args=cflags.split(), extra_link_args=ldflags.split())],
        zip_safe=False,
        url="https://github.com/bumptech/palm",
        description="Python bindings for the nitro project",
        )
