#!/usr/bin/env python                                 #pylint: disable-msg=C0103
"""
    Setup script for sync_status - uses standard distutils
"""

from distutils.core import setup

setup(name='Badger Utils',
      version='0.9',
      description='Utilities for running BadgerNet',
      author='Badger',
      author_email='badger@badgers-house.me.uk',
      url='http://badgers-house.me.uk/code',
      scripts=['tarsnap_prune.py',
               ],
     )
